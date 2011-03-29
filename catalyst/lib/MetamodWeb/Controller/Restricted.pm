package MetamodWeb::Controller::Restricted;

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

MetamodWeb::Controller::Restricted - Catalyst Controller used to create restricted pages.

=head1 DESCRIPTION

This Catalyst controller is used to add login requirements to controllers. All
controllers that are put in the MetamodWeb::Restricted::<module name> namespace
will automatically have a login requirement that will be verified by this
module's C<auto> method.

=head1 METHODS

=cut

=head2 auto

Check if we have a user object, i.e. that the user is logged in. If the user is
not logged in we forward the user to the login page.

=cut

sub auto :Private {
    my ($self, $c) = @_;
    return $self->chk_logged_in($c);
}

__PACKAGE__->meta->make_immutable;

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
