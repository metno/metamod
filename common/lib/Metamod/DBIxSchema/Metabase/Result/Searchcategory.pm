package Metamod::DBIxSchema::Metabase::Result::Searchcategory;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("InflateColumn::DateTime", "Core");
__PACKAGE__->table("searchcategory");
__PACKAGE__->add_columns(
  "sc_id",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "sc_type",
  { data_type => "varchar", default_value => undef, is_nullable => 0, size => 32 },
  "sc_fnc",
  {
    data_type => "character varying",
    default_value => undef,
    is_nullable => 0,
    size => 9999,
  },
  "sc_idname",
  { data_type => "varchar", is_nullable => 0, size => 32 },
);
__PACKAGE__->set_primary_key("sc_id");
__PACKAGE__->add_unique_constraint("searchcategory_pkey", ["sc_id"]);
__PACKAGE__->add_unique_constraint(["sc_idname"]);
__PACKAGE__->has_many(
  "basickeys",
  "Metamod::DBIxSchema::Metabase::Result::Basickey",
  { "foreign.sc_id" => "self.sc_id" },
);
__PACKAGE__->has_many(
  "hierarchicalkeys",
  "Metamod::DBIxSchema::Metabase::Result::Hierarchicalkey",
  { "foreign.sc_id" => "self.sc_id" },
);
__PACKAGE__->has_many(
  "numberitems",
  "Metamod::DBIxSchema::Metabase::Result::Numberitem",
  { "foreign.sc_id" => "self.sc_id" },
);


# Created by DBIx::Class::Schema::Metabase::Loader v0.04006 @ 2010-09-15 13:43:08
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:C+3mbAMCOmGSKQNrgjBeeg

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

=head2 $self->sc_fnc_parsed()

=over

=item return

The contents of the C<sc_fnc> is parsed returned as a hash reference.

=back

=cut

sub sc_fnc_parsed {
    my $self = shift;

    my $fnc = $self->sc_fnc();

    if( !$fnc ) {
        return $fnc;
    }

    my @kv_pairs = split ';', $fnc;
    my %fnc = ();
    foreach my $kv (@kv_pairs){

        my ($key,$value) = split ':', $kv;
        $key =~ s/^\s+//;
        $key =~ s/\s+$//;
        $value =~ s/^\s+//;
        $value =~ s/\s+$//;

        $fnc{$key} = $value;
    }

    return \%fnc;
}
1;
