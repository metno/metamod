package Metamod::DBIxSchema::Metabase::Result::Numberitem;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("InflateColumn::DateTime", "Core");
__PACKAGE__->table("numberitem");
__PACKAGE__->add_columns(
  "sc_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "ni_from",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "ni_to",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "ds_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
);
__PACKAGE__->set_primary_key("sc_id", "ni_from", "ni_to", "ds_id");
__PACKAGE__->add_unique_constraint("numberitem_pkey", ["sc_id", "ni_from", "ni_to", "ds_id"]);
__PACKAGE__->belongs_to(
  "sc_id",
  "Metamod::DBIxSchema::Metabase::Result::Searchcategory",
  { sc_id => "sc_id" },
);
__PACKAGE__->belongs_to(
  "ds_id",
  "Metamod::DBIxSchema::Metabase::Result::Dataset",
  { ds_id => "ds_id" },
);


# Created by DBIx::Class::Schema::Metabase::Loader v0.04006 @ 2010-09-15 13:43:08
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:W/0oNgNoTrqgsdw8lEyRyw

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

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

# You can replace this text with custom content, and it will be preserved on regeneration
1;
