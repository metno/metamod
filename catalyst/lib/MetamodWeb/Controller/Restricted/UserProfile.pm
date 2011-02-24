package MetamodWeb::Controller::Restricted::UserProfile;

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

use strict;
use warnings;

use Moose;
use namespace::autoclean;

use Data::FormValidator::Constraints qw(:closures);
use Digest;

use Metamod::Email;
use MetamodWeb::Utils::UI::Login;
use MetamodWeb::Utils::FormValidator;

BEGIN { extends 'MetamodWeb::BaseController::Base'; }

=head1 NAME

MetamodWeb::Controller::Restricted::UserProfile - Controller for working with the user profile.

=head1 DESCRIPTION

=head1 FUNCTIONS/METHODS

=cut

sub auto : Private {
    my ( $self, $c ) = @_;

    $c->stash( section => 'userprofile' );

}

sub user_profile : Path('/userprofile') : Args(0) : ActionClass('REST') {
    my ( $self, $c ) = @_;

    my $login_ui_utils = MetamodWeb::Utils::UI::Login->new( c => $c );
    $c->stash( login_ui_utils => $login_ui_utils );

}

sub user_profile_GET : Private {
    my ( $self, $c ) = @_;

    my $user = $c->user();

    # This code is currently specific for a database user store. Need
    # to be modified when LDAP users are introduced.
    my %user_info = (
        name        => $user->get('u_name'),
        email       => $user->get('u_email'),
        username    => $user->get('u_loginname'),
        institution => $user->get('u_institution'),
        telephone   => $user->get('u_telephone'),
        roles       => [ $user->roles() ],
    );

    # merge the database information with the request params in case of redirect on error
    my %req_params = %{ $c->req->params };
    %user_info = ( %user_info, %req_params );

    $c->stash( user_info => \%user_info );

    # if the validation failed in the previous request we validate again to get the error
    # messages.
    if ( $c->flash->{validation_failure} ) {
        $self->validate_user_profile($c);
    }

    $c->stash( template => 'userprofile/profile.tt' );
}

sub user_profile_POST : Private {
    my ( $self, $c ) = @_;

    my $result = $self->validate_user_profile($c);
    if ( !$result->success() ) {
        $c->flash( validation_failure => 1 );
        return $c->res->redirect( $c->uri_for( '/userprofile', $c->req->params ) );
    }

    # assume a database user for now. Need to change this when LDAP is implemented.
    my $user_row = $c->model('Userbase::Usertable')->find( $c->user->id() );
    if ( !defined $user_row ) {
        die 'Could not find the database user';
    }

    my $institution = '';
    if ( $c->req->param('institution_name') eq 'other' ) {
        $institution = $c->req->param('institution_other');
    } else {
        $institution = $c->req->param('institution_name');
    }

    my $new_info = {
        u_name        => $c->req->param('name'),
        u_email       => $c->req->param('email'),
        u_institution => $institution,
        u_telephone   => $c->req->param('telephone'),
    };
    $user_row->update($new_info);

    $self->add_info_msgs( $c, 'User profile has been updated' );

    $c->res->redirect( $c->uri_for('/userprofile') );

}

sub validate_user_profile {
    my ( $self, $c ) = @_;

    my %form_profile = (
        required           => [qw( email name )],
        optional           => [qw( institution_name institution_other telephone )],
        constraint_methods => { email => email(), },
        labels             => {
            email             => 'Email',
            institution       => 'Institution name',
            institution_other => 'Institution name (other)',
            telephone         => 'Telephone',
            name              => 'Name',
        },
        msgs => sub {
            email => 'Invalid email address',
                ;
        }
    );
    my $validator = MetamodWeb::Utils::FormValidator->new( validation_profile => \%form_profile );
    my $result = $validator->validate( $c->req->params );
    $c->stash( validator => $validator );

    return $result;

}

sub password : Path('/userprofile/password') : Args(0) : ActionClass('REST') {
    my ( $self, $c ) = @_;

}

sub password_GET : Private {
    my ( $self, $c ) = @_;

    $c->stash( template => 'userprofile/change_password.tt' );
}

sub password_POST : Private {
    my ( $self, $c ) = @_;

    my $username        = $c->user->get('u_loginname');
    my $old_password    = $c->req->params->{old_password};
    my $password        = $c->req->params->{password};
    my $password_repeat = $c->req->params->{password_repeat};

    if ( !$old_password ) {
        $self->add_error_msgs( $c, 'You must supply your old password' );
        return $c->res->redirect( $c->uri_for('/userprofile/password') );
    }

    if ( $password ne $password_repeat ) {
        $self->add_error_msgs( $c, 'The new password and repeated new password are not identical' );
        return $c->res->redirect( $c->uri_for('/userprofile/password') );
    }

    if ( $password eq '' ) {
        $self->add_error_msgs( $c, 'Empty passwords are not allowed' );
        return $c->res->redirect( $c->uri_for('/userprofile/password') );
    }

    if ( !$c->authenticate( { u_loginname => $username, u_password => $old_password } ) ) {
        $self->add_error_msgs( $c, 'Your old password was not correct' );
        return $c->res->redirect( $c->uri_for('/userprofile/password') );
    }

    # assume a database user for now. Need to change this when LDAP is implemented.
    my $user_row = $c->model('Userbase::Usertable')->find( $c->user->id() );
    if ( !defined $user_row ) {
        die 'Could not find the database user';
    }

    my $pass_digest = Digest->new('SHA-1')->add($password)->hexdigest();
    $user_row->update( { u_password => $pass_digest } );

    $self->add_info_msgs( $c, 'Password has been changed' );

    $c->res->redirect( $c->uri_for('/userprofile/password') );

}

sub role : Path('/userprofile/role') : Args(1) : ActionClass('REST') {
    my ( $self, $c, $role ) = @_;

}

sub role_GET : Private {
    my ( $self, $c, $role ) = @_;

    $c->stash(
        template => 'userprofile/role.tt',
        role     => $role,
    );
}

sub role_POST : Private {
    my ( $self, $c, $role ) = @_;

    my $username = $c->user->get('u_loginname');

    my $mm_config = $c->stash->{mm_config};
    my $operator_email = $mm_config->get('OPERATOR_EMAIL');
    my $application_name = $mm_config->get('APPLICATION_NAME');
    my $base_url = $mm_config->get('BASE_PART_OF_EXTERNAL_URL');
    my $local_url = $mm_config->get('LOCAL_URL');
    my $approve_url = "${base_url}${local_url}admin/confirm_role/${role}/${username}";

    my $email_body = <<"END_BODY";
A user has requested a new role in the application $application_name.

Please click the link below to confirm the request.

$approve_url
END_BODY


    Metamod::Email::send_simple_email(
        to => [ $operator_email ],
        from => 'nobody@example.com',
        subject => "New role requested for $application_name",
        body => $email_body,
    );

    $self->add_info_msgs($c, 'The request for the role has been sent to the administrator.');

    $c->res->redirect($c->uri_for('/userprofile/role', $role ) );

}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

__PACKAGE__->meta->make_immutable;
