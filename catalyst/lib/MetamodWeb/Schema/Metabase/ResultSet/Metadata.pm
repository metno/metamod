package MetamodWeb::Schema::Metabase::ResultSet::Metadata;

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

use Data::Dump qw( dump );
use Log::Log4perl qw( get_logger );
use Params::Validate qw( :all );

=head2 $self->available_metadata()

=over

=item return

A reference to a list of available mt_names.

=back

=cut

sub available_metadata {
	my $self = shift;

	my @mt_names = $self->search( {}, { distinct => 1 } )->get_column('mt_name')->all();
	return \@mt_names;

}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
