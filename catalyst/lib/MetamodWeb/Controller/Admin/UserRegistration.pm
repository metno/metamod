package MetamodWeb::Controller::Admin::UserRegistration;

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

use Metamod::Email;
use Metamod::Utils qw(random_string);

BEGIN { extends 'MetamodWeb::BaseController::Base'; }

=head1 NAME

MetamodWeb::Controller::Admin::UserRegistration - Controller for approving user registrations.

=head1 DESCRIPTION

=head1 FUNCTIONS/METHODS

=cut

sub confirm_user : Path('/admin/confirm_user') : Args(1) : ActionClass('REST') {
    my ( $self, $c, $u_id ) = @_;

    my $userbase_user = $c->model('Userbase::Usertable')->find($u_id);

    if ( !defined $userbase_user ) {
        die "'$u_id' does not refer to a valid user";
    }

    $c->stash( userbase_user => $userbase_user );
    $c->stash( current_view  => 'Raw' );
}

sub confirm_user_GET {
    my ( $self, $c, $u_id ) = @_;

    $c->stash( template => 'admin/confirm_user.tt' );
}

sub confirm_user_POST {
    my ( $self, $c, $u_id ) = @_;

    my $userbase_user = $c->stash->{userbase_user};
    my $random_pass = $userbase_user->reset_password();


    my $mm_config        = $c->stash->{mm_config};
    my $operator_email   = $mm_config->get('OPERATOR_EMAIL');
    my $application_name = $mm_config->get('APPLICATION_NAME');
    my $signature        = $mm_config->get('EMAIL_SIGNATURE') || '';
    my $name             = $userbase_user->u_name();
    my $username         = $userbase_user->u_loginname();

    my $email_body = <<"END_BODY";
Dear $name,

you have been granted access to $application_name.
Username: $username
Password: $random_pass

$signature
END_BODY

    Metamod::Email::send_simple_email(
        to      => [ $userbase_user->u_email ],
        from    => $operator_email,
        subject => "Access to $application_name approved",
        body    => $email_body,
    );

    $self->add_info_msgs( $c, 'User has been approved' );
    return $c->res->redirect( $c->uri_for( '/admin/confirm_user', $u_id ) );

}

sub confirm_role : Path('/admin/confirm_role') : Args(2) : ActionClass('REST') {
    my ( $self, $c, $role, $username ) = @_;


    $c->stash( current_view  => 'Raw' );
}

sub confirm_role_GET : Private {
    my ( $self, $c, $role, $username ) = @_;

    my %user_info = ();
    my $has_role = 0;
    my $user = $c->model('Userbase::Usertable')->search( { u_loginname => $username } )->first();
    if ( !defined $user ) {
        $self->add_error_msgs( $c, 'The user could not be found' );
    } else {

        my $roles = $user->roles();
        my @role_names = ();
        while( my $r = $roles->next() ){
            if( $r->role eq $role ) {
                $has_role = 1;
            }
            push @role_names, $r->role();
        }

        %user_info = (
            name        => $user->u_name(),
            email       => $user->u_email(),
            username    => $user->u_loginname(),
            institution => $user->u_institution(),
            telephone   => $user->u_telephone(),
            roles       => \@role_names,
        );
    }

    $c->stash( template => 'admin/confirm_role.tt', role => $role, user_info => \%user_info, has_role => $has_role );

}

sub confirm_role_POST : Private {
    my ( $self, $c, $role, $username ) = @_;

    my $user = $c->model('Userbase::Usertable')->search( { u_loginname => $username } )->first();
    if ( !defined $user ) {
        $self->add_error_msgs( $c, 'The user could not be found' );
        return $c->res->redirect($c->uri_for('/admin/confirm_role/', $role, $username ) );
    } else {
        $user->create_related('roles', { role => $role } );
        $self->add_info_msgs($c, "The user has been approved for role '$role'" );
    }

    my $user_email = $user->u_email();
    my $name = $user->u_name();
    my $mm_config = $c->stash->{mm_config};
    my $application_name = $mm_config->get('APPLICATION_NAME');
    my $operator_email = $mm_config->get('OPERATOR_EMAIL');
    my $signature = $mm_config->get('EMAIL_SIGNATURE');

    my $email_body = <<"END_BODY";
Dear $name,

your request for $role in $application_name has now been approved and is effective immediatly.

$signature
END_BODY

    Metamod::Email::send_simple_email(
        to => [$user_email],
        from => $operator_email,
        subject => "Role '$role' approved for $application_name",
        body => $email_body,
    );

    $c->res->redirect($c->uri_for('/admin/confirm_role', $role, $username ) );
}


=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

__PACKAGE__->meta->make_immutable;

1;
