package MetamodWeb::Schema::Resultset;

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

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use Metamod::Config;

=head1 NAME

MetamodWeb::Schema::Resultset - Base class for results sets.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 FUNCTIONS/METHODS

=cut

sub fulltext_search {
    my $self = shift;

    my ($search_text) = @_;

    my @search_words = split /\s+/, $search_text;
    $search_text = join ' & ', @search_words;

    my $quoted_text = $self->quote_sql_value($search_text);

    return \"@@ to_tsquery( 'english', $quoted_text )";

}

sub dataset_location_search {
    my $self = shift;

    my ( $srid, $x1, $y1, $x2, $y2 ) = @_;

    my $config = Metamod::Config->new();

    my $scale_factor_x = $config->get("SRID_MAP_SCALE_FACTOR_X_$srid");
    my $scale_factor_y = $config->get("SRID_MAP_SCALE_FACTOR_Y_$srid");
    my $offset_x = $config->get("SRID_MAP_OFFSET_X_$srid");
    my $offset_y = $config->get("SRID_MAP_OFFSET_Y_$srid");

    if( !$scale_factor_x || !$scale_factor_y || !$offset_x || !$offset_y ){
        die "Need all SRID map params in config for '$srid'. Got ($scale_factor_x,$scale_factor_y,$offset_x,$offset_y)";
    }


    my $x1m = ($x1 - $offset_x)*$scale_factor_x;
    my $x2m = ($x2 - $offset_x)*$scale_factor_x;
    my $y1m = ($y1 - $offset_y)*$scale_factor_y;
    my $y2m = ($y2 - $offset_y)*$scale_factor_y;

    $x1m = $self->quote_sql_value( $x1m );
    $x2m = $self->quote_sql_value( $x2m );
    $y1m = $self->quote_sql_value( $y1m );
    $y2m = $self->quote_sql_value( $y2m );

    my $selected_box = "ST_MakeBox2D(ST_Point($x1m, $y1m),ST_Point($x2m,$y2m))";
    my $bounding_box = "ST_SetSRID($selected_box,$srid)";
    my $geom_column  = "geom_$srid";

    my $search_cond = {
        IN => \"( SELECT DISTINCT ds_id FROM dataset_location WHERE ST_DWITHIN( $bounding_box, $geom_column, 0.1))",
    };
    return $search_cond;

#
#        $scaleFactorX = $mmConfig->getVar("SRID_MAP_SCALE_FACTOR_X_$srid");
#         $scaleFactorY = $mmConfig->getVar("SRID_MAP_SCALE_FACTOR_Y_$srid");
#         $offsetX = $mmConfig->getVar("SRID_MAP_OFFSET_X_$srid");
#         $offsetY = $mmConfig->getVar("SRID_MAP_OFFSET_Y_$srid");
#         $x1m = ($x1 - $offsetX)*$scaleFactorX;
#         $x2m = ($x2 - $offsetX)*$scaleFactorX;
#         $y1m = ($y1 - $offsetY)*$scaleFactorY;
#         $y2m = ($y2 - $offsetY)*$scaleFactorY;
#         $polygon = "ST_MakeBox2D(ST_Point($x1m, $y1m),ST_Point($x2m,$y2m))";
#         $sql_gapart .= '    DS_id IN (' .
#                        '       SELECT DISTINCT Dataset_Location.DS_id FROM Dataset_Location '.
#                        "         WHERE ST_DWITHIN(ST_SetSRID($polygon,$srid), geom_$srid, 0.1)".
#                        "    )\n";



}

sub quote_sql_value {
    my $self = shift;

    my ( $value ) = @_;

    my $dbh         = $self->result_source->schema->storage->dbh;
    my $quoted_value = $dbh->quote($value);

    return $quoted_value;

}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;