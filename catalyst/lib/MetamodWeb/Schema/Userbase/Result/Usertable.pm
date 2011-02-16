package MetamodWeb::Schema::Userbase::Result::Usertable;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("InflateColumn::DateTime", "Core");
__PACKAGE__->table("usertable");
__PACKAGE__->add_columns(
  "u_id",
  {
    data_type => "integer",
    default_value => "nextval('usertable_u_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "a_id",
  {
    data_type => "character varying",
    default_value => undef,
    is_nullable => 0,
    size => 9999,
  },
  "u_name",
  {
    data_type => "character varying",
    default_value => undef,
    is_nullable => 1,
    size => 9999,
  },
  "u_email",
  {
    data_type => "character varying",
    default_value => undef,
    is_nullable => 0,
    size => 9999,
  },
  "u_password",
  {
    data_type => "character varying",
    default_value => undef,
    is_nullable => 1,
    size => 9999,
  },
  "u_institution",
  {
    data_type => "character varying",
    default_value => undef,
    is_nullable => 1,
    size => 9999,
  },
  "u_telephone",
  {
    data_type => "character varying",
    default_value => undef,
    is_nullable => 1,
    size => 9999,
  },
  "u_session",
  {
    data_type => "character varying",
    default_value => undef,
    is_nullable => 1,
    size => 9999,
  },
  "u_loginname",
  {
    data_type => "character varying",
    default_value => undef,
    is_nullable => 1,
    size => 9999,
  },
);
__PACKAGE__->set_primary_key("u_id");
__PACKAGE__->add_unique_constraint("usertable_pkey", ["u_id"]);
__PACKAGE__->has_many(
  "datasets",
  "MetamodWeb::Schema::Userbase::Result::Dataset",
  { "foreign.u_id" => "self.u_id" },
);
__PACKAGE__->has_many(
  "infouds",
  "MetamodWeb::Schema::Userbase::Result::Infouds",
  { "foreign.u_id" => "self.u_id" },
);


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-09-15 14:15:48
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Ol3eBbTy1PkS1D/vtd0DCg

__PACKAGE__->has_many(
  "infou",
  "MetamodWeb::Schema::Userbase::Result::Infou",
  { "foreign.u_id" => "self.u_id" },
);

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
