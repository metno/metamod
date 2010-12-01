package MetamodWeb::BaseController::Restricted;

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

MetamodWeb::Controller::Restricted - Catalyst Controller used to create restricted pages.

=head1 DESCRIPTION

This Catalyst controll is used to add a login requirement to pages in an easy
way. All pages that have a path like /restricted/<path> will require the user
to authenticate themselves.

=head1 METHODS

=cut

=head2 auto

Check if there is a user and, if not, forward to login page

=cut

sub auto :Private {
    my ($self, $c) = @_;


    if (!$c->user_exists) {

        # Dump a log message to the development server debug output
        $c->log->debug('***Restricted::auto User not found, forwarding to /login');

        my $wanted_path = '/' . $c->request->path();
        my $wanted_params = $c->request->params();
        my $wanted_string = '';
        while( my ( $key, $value ) = each %$wanted_params ){
            $wanted_string = "&$key=$value";
        }

        # Redirect the user to the login page
        $c->response->redirect($c->uri_for('/login', { return => $wanted_path, return_params => $wanted_string } ) );

        # Return 0 to cancel 'post-auto' processing and prevent use of application
        return 0;
    }

    # User found, so return 1 to continue with processing after this 'auto'
    return 1;
}

__PACKAGE__->meta->make_immutable;

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
