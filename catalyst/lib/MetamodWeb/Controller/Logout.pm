package MetamodWeb::Controller::Logout;

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

BEGIN {extends 'MetamodWeb::BaseController::Base'; }

=head1 NAME

MetamodWeb::Controller::Logout - Catalyst Controller for logging out a user.

=head1 METHODS

=cut

=head2 index

Clear the user state and send the user to the start page.

=cut

sub index :Path :Args(0) {
    my ($self, $c) = @_;

    # Clear the user's state
    $c->logout;

    my $request_params = $c->req->params();
    my $return_path = $request_params->{return_path} || '/';
    my $return_params = $request_params->{return_params} || '';

    $c->response->redirect($c->uri_for( $return_path) . '?' . $return_params);
}

__PACKAGE__->meta->make_immutable;

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
