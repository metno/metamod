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

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

MetamodWeb::Controller::Login - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ($self, $c) = @_;

    # Get the username and password from form
    my $username = $c->request->params->{username};
    my $password = $c->request->params->{password};

    $c->stash( username => $username,
               'return' => $c->request->param('return'),
               return_params => $c->request->param('return_params'),
               template => 'login.tt' );

}

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
            # If successful, then let them use the application
            my $return = $c->request->param( 'return' ) || '/';
            $c->log->debug( "Return:" . $return );
            my $return_params = $c->request->param('return_params');

            $c->response->redirect($c->uri_for($return) . "?$return_params" );
            return;
        } else {
            # Set an error message
            $c->stash(error_msg => "Invalid username or password.");
        }
    } else {
        # Set an error message
        $c->stash(error_msg => "Empty username or password.");
    }

    $c->forward('index');

}

__PACKAGE__->meta->make_immutable;

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut
1;
