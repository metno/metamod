package MetamodWeb::Schema::Userbase::ResultSet::Usertable;

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

use base 'MetamodWeb::Schema::Resultset';

use strict;
use warnings;

use Log::Log4perl qw( get_logger );
use Try::Tiny;
use XML::LibXML;

my $logger = get_logger('metamod.userbase');

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

=head2 $self->new_user($values, $roles)

Create a new user with the specified values and roles.

=over

=item $values

A hash reference with the column values for the new user.

=item $roles

A reference to a possibly empty list of role names that the user should have.

=item return

Returns the new user as a C<DBIx::Class> row object.

=back

=cut

sub new_user {
    my $self = shift;

    my ($values, $roles) = @_;

    my $new_user = $self->create($values);

    foreach my $role (@$roles) {
        $new_user->create_related('roles', { role => $role });
    }

    return $new_user;
}

1;
