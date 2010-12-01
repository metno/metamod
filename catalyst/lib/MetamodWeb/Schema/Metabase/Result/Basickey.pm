package MetamodWeb::Schema::Metabase::Result::Basickey;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("InflateColumn::DateTime", "Core");
__PACKAGE__->table("basickey");
__PACKAGE__->add_columns(
  "bk_id",
  {
    data_type => "serial",
    #default_value => "nextval('basickey_bk_id_seq'::regclass)",
    is_auto_increment => 1,
    is_nullable => 0,
    size => 4,
  },
  "sc_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "bk_name",
  {
    data_type => "character varying",
    default_value => undef,
    is_nullable => 0,
    size => 9999,
  },
);
__PACKAGE__->set_primary_key("bk_id");
__PACKAGE__->add_unique_constraint("basickey_sc_id_key", ["sc_id", "bk_name"]);
__PACKAGE__->add_unique_constraint("basickey_pkey", ["bk_id"]);
__PACKAGE__->belongs_to(
  "sc_id",
  "MetamodWeb::Schema::Metabase::Result::Searchcategory",
  { sc_id => "sc_id" },
);
__PACKAGE__->has_many(
  "bk_describes_ds",
  "MetamodWeb::Schema::Metabase::Result::BkDescribesDs",
  { "foreign.bk_id" => "self.bk_id" },
);
__PACKAGE__->has_many(
  "hk_represents_bks",
  "MetamodWeb::Schema::Metabase::Result::HkRepresentsBk",
  { "foreign.bk_id" => "self.bk_id" },
);


# Created by DBIx::Class::Schema::Metabase::Loader v0.04006 @ 2010-09-15 13:43:08
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:kdstHPUzWiTeE4662x/kjQ

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

__PACKAGE__->has_many(
  "hk_represents_bks_inner",
  "MetamodWeb::Schema::Metabase::Result::HkRepresentsBk",
  { "foreign.bk_id" => "self.bk_id" },
  { join_type => 'INNER' },
);

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut
1;
