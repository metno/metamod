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

    # If the username and password values were found in form
    if ($username && $password) {
        # Attempt to log the user in
        if ($c->authenticate({ u_loginname => $username,
                               u_password => $password  } )) {

            # If the user was redirected from a different page, e.g. subscription/,
            # then we want to send them back to where they wanted in the first place.
            # For that we use the CGI param 'return_path' if set.
            my $return_path = $c->request->param( 'return_path' ) || '/';
            $c->log->debug( "Return:" . $return_path );
            my $return_params = $c->request->param('return_params');

            $c->response->redirect($c->uri_for($return_path) . "?$return_params" );
            return;
        } else {
            $self->add_error_msgs($c, 'Invalid username or password.' );
        }
    } else {
        $self->add_error_msgs($c, 'Empty username or password.' );
    }

    $c->forward('index');

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

    my $new_user = $c->model('Userbase::Usertable')->new_user($user_values, \@roles);

    $self->send_user_receipt($c, $user_values);

    $self->send_operator_email($c, $new_user);

    $self->add_info_msgs($c, 'New user has been request. A receipt has been sent to your email');
    $c->res->redirect($c->uri_for('/login', $c->req->params ));

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
        },
        labels => {
            register_username => 'Username',
            email => 'Email',
            access_right => 'Access rights',
            institution => 'Institution name',
            institution_other => 'Institution name (other)',
            telephone => 'Telephone',
            realname => 'Name',
        },
        msgs => sub {
            email => 'Invalid email address',
            username_constraint => "Invalid username. Only user letters, '_' and numbers, or same as email",
        }
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

Name: $user_info->{u_name}
Email: $user_info->{u_email}
Username: $user_info->{u_loginname}
Institution: $user_info->{u_institution}
Telephone: $user_info->{u_telephone}

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
    my ($self, $c, $new_user) = @_;

    my $mm_config = $c->stash->{mm_config};
    my $base_url = $mm_config->get('BASE_PART_OF_EXTERNAL_URL');
    my $local_url = $mm_config->get('LOCAL_URL');
    my $approve_url = "${base_url}${local_url}admin/confirm_user/" . $new_user->u_id();

    my $email_body = <<"END_BODY";
A new user has been registred. Please check the information
and approve the user if the information is ok.

$approve_url
END_BODY

    my $operator_email = $mm_config->get('OPERATOR_EMAIL');
    my $application_name = $mm_config->get('APPLICATION_NAME');

    Metamod::Email::send_simple_email(
        to => [ $operator_email ],
        from => 'dummy@example.com',
        subject => "$application_name new user registred",
        body => $email_body,
    );

    return;

}

__PACKAGE__->meta->make_immutable;

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut
1;
