package MetamodWeb::Schema::Metabase::Result::Metadatatype;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("InflateColumn::DateTime", "Core");
__PACKAGE__->table("metadatatype");
__PACKAGE__->add_columns(
  "mt_name",
  {
    data_type => "character varying",
    default_value => undef,
    is_nullable => 0,
    size => 99,
  },
  "mt_share",
  { data_type => "boolean", default_value => undef, is_nullable => 0, size => 1 },
  "mt_def",
  {
    data_type => "character varying",
    default_value => undef,
    is_nullable => 0,
    size => 9999,
  },
);
__PACKAGE__->set_primary_key("mt_name");
__PACKAGE__->add_unique_constraint("metadatatype_pkey", ["mt_name"]);
__PACKAGE__->has_many(
  "metadatas",
  "MetamodWeb::Schema::Metabase::Result::Metadata",
  { "foreign.mt_name" => "self.mt_name" },
);


# Created by DBIx::Class::Schema::Metabase::Loader v0.04006 @ 2010-09-15 13:43:08
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:NWrNH4djLk/Kn4TZNn2hEA

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
