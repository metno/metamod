package MetamodWeb::Controller::Login;

=begin LICENSE

METAMOD is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

METAMOD is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with METAMOD; if not, write to the Free Software
Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

=end LICENSE

=cut

use Moose;
use namespace::autoclean;

use Data::FormValidator::Constraints qw(:closures);

use Metamod::Email;
use MetamodWeb::Utils::UI::Login;
use MetamodWeb::Utils::FormValidator;

BEGIN {extends 'MetamodWeb::BaseController::Base'; }

=head1 NAME

MetamodWeb::Controller::Login - Controller for handling user login.

=head1 DESCRIPTION

Controller for handling user login and registration.

=head1 METHODS

=cut

=head2 auto

Controller specific initialisation.

=cut

sub auto :Private {
    my ( $self, $c ) = @_;

    my $mm_config = $c->stash->{ mm_config };
    my $ui_utils = MetamodWeb::Utils::UI::Login->new( { config => $mm_config, c => $c } );
    $c->stash( login_ui_utils => $ui_utils, );

    return 1;

}

=head2 index

Action for display the login form.

=cut

sub index :Path('/login') :Args(0) {
    my ($self, $c) = @_;

    $c->stash( template => 'login.tt' );

}

=head2 authenticate

Attempt to authenticate the user. If the authentication fails,
send the user back to the login page with a message. Otherwise
send the user to the page where they wanted to go in the
first place or to main page if they where not redirected to the
login page.

=cut

sub authenticate :Path('authenticate') :Args(0) {
    my ( $self, $c ) = @_;

    # Get the username and password from form
    my $username = $c->request->params->{username};
    my $password = $c->request->params->{password};
    my $method = $c->request->method;

    # If the user was redirected from a different page, e.g. subscription/,
    # then we want to send them back to where they wanted in the first place.
    # For that we use the CGI param 'return_path' if set.
    my $return_path = $c->request->param( 'return_path' ) || '/';
    $self->logger->debug( "Return:" . $return_path );
    my $return_params = $c->request->param('return_params') || '';

    # If the username and password values were found in form
    if ($username && $password) {
        # Attempt to log the user in
        if ($c->authenticate({ u_loginname => $username,
                               u_password => $password  } )) {

            $c->response->redirect($c->uri_for($return_path) . "?$return_params" );
            return;
        } else {
            $self->add_error_msgs($c, 'Invalid username or password.' );
        }
    } else {
        $self->add_error_msgs($c, 'Empty username or password.' );
    }

    # strip away username/passwd from redirect url
    $c->res->redirect( $c->uri_for('/login', {
                                                return_params => $return_params,
                                                return_path => $return_path,
                                              } ) );

}

=head2 register

Action for registering a new user in the system.

=cut

sub register : Path('register') :Args(0) {
    my ($self, $c) = @_;

    my $result = $self->validate_new_user($c);
    if( !$result->success() ){
        $self->add_form_errors($c, $c->stash->{validator});
        return $c->res->redirect($c->uri_for('/login', $c->req->params ) );
    }

    my $mm_config = $c->stash->{mm_config};
    my $valid_fields = $result->valid();

    my $institution = '';
    if( exists $valid_fields->{institution_name} && $valid_fields->{institution_name} eq 'other' ){
        $institution = $valid_fields->{institution_other};
    } else {
        $institution = $valid_fields->{institution_name};
    }

    my $users = $c->model('Userbase::Usertable')->search( { u_loginname => $valid_fields->{register_username} } );
    if( $users->count() != 0 ){
        $self->add_error_msgs($c, "The username has already been taken. Please choose another" );
        return $c->res->redirect($c->uri_for('/login', $c->req->params ));
    }

    my $user_values = {
        a_id => $mm_config->get('APPLICATION_ID'),
        u_name => $valid_fields->{realname},
        u_email => $valid_fields->{email},
        u_loginname => $valid_fields->{register_username},
        u_institution => $institution,
        u_telephone => $valid_fields->{telephone},
    };

    my @roles = ();
    if( $valid_fields->{access_rights } eq 'subscription' ){
        @roles = qw(subscription);
    } elsif( $valid_fields->{access_rights } eq 'upload' ){
        @roles = qw(subscription upload);
    }

    $self->logger->info( "User registration attempt:" . $valid_fields->{realname} . ' ' .
                         $valid_fields->{register_username} );

    if ($mm_config->get('JUNK_REGISTRATION') ne 'name_eq_loginname' or
        $valid_fields->{realname} ne $valid_fields->{register_username}) {

        my $new_user = $c->model('Userbase::Usertable')->new_user($user_values, \@roles);

    # This feature has been temporary removed since we have problems with junk regirations.
    # This might be turned on if we figure out a better way to prevent the junk registrations
    # See bug 129
    #$self->send_user_receipt($c, $user_values);

        $self->send_operator_email($c, $new_user, $user_values, \@roles);
        $self->logger->info( "User registration: Email sent to operator for approval" );

    }
    $self->add_info_msgs($c, 'Your request will be processed. If accepted, you will receive an E-mail within a few days.');
    $c->res->redirect($c->uri_for('/login' ));

}

sub validate_new_user : Private {
    my ($self, $c) = @_;

    my %form_profile = (
        required => [qw( register_username email access_rights realname )],
        optional => [qw( institution_name institution_other telephone ) ],
        constraint_methods => {
            email => email(),
            register_username => sub { # use a sub so we can set the constraint name and a message
                my ($dfv, $val) = @_;
                my $email = $dfv->get_filtered_data->{email};
                $dfv->set_current_constraint_name('username_constraint');
                return $val =~ /^(\w{3,20})|$email$/;
            },
            access_rights => sub {
                my ($dfv, $priv) = @_;
                my $inst = $dfv->get_filtered_data->{institution_name};
                $dfv->set_current_constraint_name('access_rights');
                my $illegal = ($priv ne 'subscription') && ($inst eq 'other');
                return not $illegal;
            }

        },
        labels => { # shouldn't these be equal to labels in template? FIXME
            register_username => 'Username',
            email => 'Email',
            access_rights => 'Access rights',
            institution => 'Institution name',
            institution_other => 'Institution name (other)',
            telephone => 'Telephone',
            realname => 'Name',
        },
        msgs => {
            constraints => {
                email => 'Invalid email address',
                username_constraint => "Invalid username. Only user letters, '_' and numbers, or same as email",
                access_rights => 'Only subscription privileges allowed for other institutions',
            }
        },
        debug => 1,
    );
    my $validator = MetamodWeb::Utils::FormValidator->new( validation_profile => \%form_profile );
    my $result = $validator->validate($c->req->params);
    $c->stash( validator => $validator );

    return $result;

}

sub send_user_receipt {
    my ($self, $c, $user_info) = @_;

    my $mm_config = $c->stash->{mm_config};
    my $operator_email = $mm_config->get('OPERATOR_EMAIL');
    my $application_name = $mm_config->get('APPLICATION_NAME');
    my $signature = $mm_config->get('EMAIL_SIGNATURE') || '';

    my $email_body = <<"END_BODY";
Dear $user_info->{u_name},

we have received your request for a new user with the following information.

Name:        $user_info->{u_name}
Email:       $user_info->{u_email}
Username:    $user_info->{u_loginname}
Institution: $user_info->{u_institution}
Telephone:   $user_info->{u_telephone}

You will receive an email with your password as soon as your request has been manually reviewed.

$signature
END_BODY

    Metamod::Email::send_simple_email(
        to => [ $user_info->{u_email} ],
        from => $operator_email,
        subject => "$application_name new user request",
        body => $email_body,
    );

    return;

}

sub send_operator_email {
    my ($self, $c, $new_user, $user_info, $refroles) = @_;

    my $mm_config = $c->stash->{mm_config};
    my $local_url = $mm_config->get('BASE_PART_OF_EXTERNAL_URL') . $mm_config->get('LOCAL_URL');
    my $roles = join(" ",@$refroles);

    # Normally uri_for will return relative URI's when Plugin::SmartURI is loaded,
    # so we must explicitly ask for the absolute URI.
    my $approve_url = "$local_url/admin/confirm_user/" . $new_user->u_id(); # can't use uri_for in email

    my $operator_email = $mm_config->get('OPERATOR_EMAIL');
    my $email_approve_user = $mm_config->get('EMAIL_APPROVE_USER');
    my $introductory_text;
    if ($email_approve_user) {
       $introductory_text = <<"EOF";
A new user has requested access with rights: $roles. Please forward this E-mail to $operator_email
if you approve the new user. Otherwise ignore.
EOF
    } else {
       $email_approve_user = $operator_email;
       $introductory_text = <<"EOF";
A new user has requested access with rights: $roles. Please check the information
and approve the user if the information is ok, or reject if not.
EOF
    }
    my $email_body = <<"END_BODY";
$introductory_text

Name:        $user_info->{u_name}
Email:       $user_info->{u_email}
Username:    $user_info->{u_loginname}
Institution: $user_info->{u_institution}
Telephone:   $user_info->{u_telephone}

$approve_url
END_BODY

    my $application_name = $mm_config->get('APPLICATION_NAME');

    Metamod::Email::send_simple_email(
        to => [ $email_approve_user ],
        from => 'metamod@' . $mm_config->get('SERVER'),
        subject => "$application_name new user registred",
        body => $email_body,
    );

    return;

}

=head2 /login/reset_password_form

Display a password reset form.

=cut

sub reset_password_form : Path('/login/reset_password_form') : Args(0) {
    my ($self, $c) = @_;

    $c->stash( template => 'reset_password.tt' );

}

=head2 /login/reset_password

Reset the users password with a new random password and send the new password
to the users email.

=cut

sub reset_password : Path('/login/reset_password') : Args(0) {
    my ($self, $c) = @_;

    my $username = $c->req->param('username');

    if( !$username ){
        $self->add_error_msgs($c, 'You must supply a username to reset the password');
        $c->res->redirect($c->uri_for('/login/reset_password_form' ) );
        return
    }

    my $user = $c->model('Userbase::Usertable')->search( { u_loginname => $username } )->first();
    if( defined $user ){

        # this should really never happen due to database constraints, but it often pays to be
        # carefull.
        if( !$user->u_email() ){
            my $msg = 'User does not have an email address so the password cannot be reset. ';
            $msg .= 'Please contact ' . $c->stash->{ mm_config }->get('OPERATOR_EMAIL') . ' for assistance.';
            $self->add_error_msgs($c, $msg );
            $c->res->redirect($c->uri_for('/login/reset_password_form', { username => $username } ) );
            return;
        }

        my $new_pass = $user->reset_password();
        $self->send_reset_email( $c, $user, $new_pass );

    }

    $self->add_info_msgs($c, 'A new password has been sent to your email address');
    $c->res->redirect($c->uri_for('/login/reset_password_form', { username => $username } ) );

}

sub send_reset_email {
    my ($self, $c, $user, $new_password) = @_;

    my $mm_config = $c->stash->{mm_config};
    my $signature = $mm_config->get('EMAIL_SIGNATURE') || '';

    my $email_body = <<"END_BODY";
Your password has been reset. Your new password is $new_password

$signature
END_BODY

    my $operator_email = $mm_config->get('OPERATOR_EMAIL');
    my $application_name = $mm_config->get('APPLICATION_NAME');

    Metamod::Email::send_simple_email(
        to => [ $user->u_email() ],
        from => $operator_email,
        subject => "$application_name password reset",
        body => $email_body,
    );

    return;
}

=head2 /login/request_role

Request a new role for the current user. The request will send an email to the
site operator and a receipt to the user.

=cut

sub request_role : Path('/login/request_role') : Args(0) {
    my ($self, $c ) = @_;

    return if !$self->chk_logged_in($c);

    my $role = $c->req->param('role');

    $self->send_role_request($c, $role);

    $self->send_role_request_receipt($c, $role);

    my $msg = 'Role has been requested. Please wait for an email that informs you if the role has been approved';
    $self->add_info_msgs( $c, $msg );

    $c->stash( role_requested => 1, template => 'unauthorized.tt' );
}

sub send_role_request {
    my $self = shift;

    my ( $c, $role ) = @_;

    my $mm_config = $c->stash->{mm_config};
    my $local_url = $mm_config->get('BASE_PART_OF_EXTERNAL_URL') . $mm_config->get('LOCAL_URL');

    # Normally uri_for will return relative URI's when Plugin::SmartURI is loaded,
    # so we must explicitly ask for the absolute URI.
    my $approve_url = "$local_url/admin/confirm_role/$role/" . $c->user()->u_loginname(); # can't use uri_for in email

    my $email_body = <<"END_BODY";
A user has requested a new role. Please check the information
and approve the user if the information is ok.

$approve_url
END_BODY

    my $operator_email = $mm_config->get('OPERATOR_EMAIL');
    my $application_name = $mm_config->get('APPLICATION_NAME');

    Metamod::Email::send_simple_email(
        to => [ $operator_email ],
        from => $operator_email,
        subject => "$application_name new role requested",
        body => $email_body,
    );

    return;
}

sub send_role_request_receipt {
    my ($self, $c, $role) = @_;

    my $user_name = $c->user()->u_name();

    my $mm_config = $c->stash->{mm_config};
    my $operator_email = $mm_config->get('OPERATOR_EMAIL');
    my $application_name = $mm_config->get('APPLICATION_NAME');
    my $signature = $mm_config->get('EMAIL_SIGNATURE') || '';

    my $email_body = <<"END_BODY";
Dear $user_name,

we have received your request for the role '$role'. The request will be manually reviewed
before and you will receive an email once it has been reviewed.

$signature
END_BODY

    Metamod::Email::send_simple_email(
        to => [ $c->user()->u_email() ],
        from => $operator_email,
        subject => "$application_name new role requested",
        body => $email_body,
    );

    return;

}

__PACKAGE__->meta->make_immutable;

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
