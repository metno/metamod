package Metamod::DBIxSchema::Userbase::Result::Infouds;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("InflateColumn::DateTime", "Core");
__PACKAGE__->table("infouds");
__PACKAGE__->add_columns(
  "i_id",
  {
    data_type => "integer",
    default_value => "nextval('infouds_i_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "u_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "ds_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "i_type",
  {
    data_type => "character varying",
    default_value => undef,
    is_nullable => 0,
    size => 9999,
  },
  "i_content",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("i_id");
__PACKAGE__->add_unique_constraint("infouds_pkey", ["i_id"]);
__PACKAGE__->belongs_to(
  "usertable",
  "Metamod::DBIxSchema::Userbase::Result::Usertable",
  { u_id => "u_id" },
);
__PACKAGE__->belongs_to(
  "dataset",
  "Metamod::DBIxSchema::Userbase::Result::Dataset",
  { ds_id => "ds_id" },
);


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-09-15 14:15:48
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:0MPs8asNXe2SnqGP2Y5r/g

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
