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

use MetamodWeb::Utils::UI::Login;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

MetamodWeb::Controller::Login - Controller for handling user login.

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


sub auto :Private {
    my ( $self, $c ) = @_;

    my $mm_config = $c->stash->{ mm_config }; my $ui_utils =
    MetamodWeb::Utils::UI::Login->new( { config => $mm_config, c => $c } );
    $c->stash( login_ui_utils => $ui_utils, );

}

=head2 index

Action for display the login form.

=cut

sub index :Path :Args(0) {
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
            $c->stash(error_msg => "Invalid username or password.");
        }
    } else {
        $c->stash(error_msg => "Empty username or password.");
    }

    $c->forward('index');

}

=head2 register

Action for registering a new user in the system.

=cut
sub register : Path('register') :Args(0) {
    my ($self, $c) = @_;

    # not yet implemented to just send back to login
    $c->forward('index');

}

__PACKAGE__->meta->make_immutable;

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut
1;
