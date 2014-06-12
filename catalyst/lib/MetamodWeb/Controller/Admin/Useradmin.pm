package MetamodWeb::Controller::Admin::Useradmin;

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
#use MetamodWeb::Utils::AdminUtils;
use MetamodWeb::Utils::FormValidator;
use Data::Dumper;
use Try::Tiny;

BEGIN { extends 'MetamodWeb::BaseController::Base'; }

=head1 NAME

MetamodWeb::Controller::Admin::Useradmin

=head1 DESCRIPTION

Catalyst Controller for user administration

=head1 METHODS

=cut

sub auto : Private {
    my ( $self, $c ) = @_;

    my $mm_config = $c->stash->{mm_config};
    my $xmldir = $mm_config->get('WEBRUN_DIRECTORY') ."/XML/" . $mm_config->get('APPLICATION_ID');

    $c->stash(
        current_view => 'None',
        #admin_utils => MetamodWeb::Utils::AdminUtils->new(),
    );
}

=head2 /admin/useradmin

Use for listing users

=cut

sub useradmin :Path('/admin/useradmin') :Args(0) {
    # if no args, show list of registered users
    my ( $self, $c ) = @_;

    $c->stash(
        template => 'admin/showusers.tt',
        users => [ $c->model('Userbase::Usertable')->all ],
    );

}

=head2 /admin/useradmin/delete

Use for deleting users

=cut

sub deleteuser :Path('/admin/useradmin/delete') :Args(1) { # delete user

    my ( $self, $c ) = @_;

    if ( $c->req->method() eq 'POST' ) {
        try {
            my $user = $c->model('Userbase::Usertable')->find( $c->req->args->[0] );
            $user->delete if defined $user;
        } catch {
            $c->stash( error => $_ );
        }
    } # ignore GET requests

    $c->res->redirect( $c->uri_for('/admin/useradmin') );

}

=head2 /admin/useradmin/xxx

Edit user data and roles

=cut

sub edituser :Path('/admin/useradmin') :ActionClass('REST') :Args(1) {
    my ( $self, $c ) = @_;
    my $user = $c->model('Userbase::Usertable')->find( $c->req->args->[0] );
    $c->stash(
        template => 'admin/edituser.tt',
        u => $user,
    );
}

sub edituser_GET { # show editor for a user
    my ( $self, $c ) = @_;
    $c->stash(
        roles => $c->stash->{u}->get_roles, # we want this separate to deal with illegal POST
    );
}

sub edituser_POST  { # update existing user
    my ( $self, $c ) = @_;
    my (%roles, %cols);
    my $p = $c->req->params;

    foreach (keys %$p) {
        if (/^role_(.+)/) { # extract role args
            $roles{$1} = $$p{$_}; # strip "role_" prefix
        } elsif (/^u_(.+)/) { # regular usertable col (starts with "u_")
            $cols{$_} = $$p{$_};
        }
    }
    #print STDERR Dumper \%roles, \%cols;
    $c->stash->{u}->merge_roles(\%roles);

    try {
        $c->stash->{u}->update(\%cols);
        $c->stash->{u}->set_roles(\%roles);
        $c->res->redirect( $c->uri_for('/admin/useradmin', $c->req->args->[0]) );
    } catch {
        $c->stash(
            roles => \%roles,
            error => $_,
        );
    }


}

=head1 AUTHOR

geira@met.no

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

__PACKAGE__->meta->make_immutable;
