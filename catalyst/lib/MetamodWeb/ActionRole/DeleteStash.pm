package MetamodWeb::ActionRole::DeleteStash;

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

use Moose::Role;
use namespace::autoclean;

=head1 NAME

MetamodWeb::ActionRole::DeleteStash - Moose/Catalyst action role for expliticly deleting/freeing the objects in the stash

=head1 DESCRIPTION

This module implements a Moose/Catalyst action role that when applied to an
action with C<:Does('DeleteStash')> will call C<delete> on all elements in the
C<stash>. This role is needed to prevent memory leaks in the application due
to circular references. Perl uses reference counting for garbage collection and
without this role circular references will never be garbage collected.

This module should only be applied to C<end()> actions and never anything else.

=head1 METHODS

=cut

after 'execute' => sub {
    my ( $self, $controller, $c, $test ) = @_;

    my @stash_keys = keys %{ $c->stash };
    foreach my $key (@stash_keys){
        delete $c->stash->{$key};
    }


};

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;