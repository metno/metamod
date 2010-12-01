package MetamodWeb::Controller::Search;

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

use Moose;
use namespace::autoclean;

use Data::Dump qw( dump );

use MetamodWeb::Utils::UI::Search;
use MetamodWeb::Utils::SearchUtils;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

MetamodWeb::Controller::Search - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub auto :Private {
    my ( $self, $c ) = @_;

    my $mm_config = $c->stash->{ mm_config };
    my $ui_utils = MetamodWeb::Utils::UI::Search->new( { config => $mm_config, c => $c } );
    $c->stash( search_ui_utils => $ui_utils,
               in_search_app => 1, #used to control header to show
     );

    push @{ $c->stash->{ css_files } }, $c->uri_for( '/static/css/search.css' );

}


sub index : Path("/search") {
    my ( $self, $c ) = @_;

    # Check for information from the map search
    my $x_coord = $c->req->params->{ 'map_coord.x' };
    my $y_coord = $c->req->params->{ 'map_coord.y' };

    my $ui_utils = $c->stash->{ search_ui_utils };
    my $x1 = $c->req->params->{ $ui_utils->html_id_for_map( 'x1' ) };
    my $x2 = $c->req->params->{ $ui_utils->html_id_for_map( 'x2' ) };
    my $y1 = $c->req->params->{ $ui_utils->html_id_for_map( 'y1' ) };
    my $y2 = $c->req->params->{ $ui_utils->html_id_for_map( 'y2' ) };

    # update the x,y coordinates. x1,y1 are set for the first request. x2, y2 for the second
    # later updates are ignored. The coordinates should be cleared first
    if( $x_coord && $y_coord && !( $x1 || $y1 ) ){
        $x1 = $x_coord;
        $y1 = $y_coord;
        $c->req->params->{ $ui_utils->html_id_for_map( 'x1' ) } = $x1;
        $c->req->params->{ $ui_utils->html_id_for_map( 'y1' ) } = $y1;
    } elsif( $x_coord && $y_coord && !( $x2 || $y2 ) ) {
        $x2 = $x_coord;
        $y2 = $y_coord;
        $c->req->params->{ $ui_utils->html_id_for_map( 'x2' ) } = $x2;
        $c->req->params->{ $ui_utils->html_id_for_map( 'y2' ) } = $y2;
    }

    $c->stash( template => 'search/search.tt' );

}

sub display_result : Chained("perform_search") : PathPart('result') : Args(0) {
    my ( $self, $c ) = @_;

    $c->stash( template => 'search/search_result.tt' );

}

sub perform_search : Chained("/") :PathPart( 'search/page' ) :CaptureArgs(1) {
    my ( $self, $c ) = @_;

    my $dataset = $c->model('Metabase::Dataset');

    my $curr_page = $c->req->args->[0];
    my $datasets_per_page = $c->req->params->{ datasets_per_page } || 10;

    my $search_utils = MetamodWeb::Utils::SearchUtils->new( { c => $c, config => $c->stash->{ mm_config } } );
    my $search_criteria = $search_utils->selected_criteria( $c->req->params() );
    my $owner_tags = $search_utils->get_ownertags();
    my $datasets = $dataset->metadata_search_with_children( {
        curr_page => $curr_page,
        ownertags => $owner_tags,
        rows_per_page => $datasets_per_page,
        search_criteria => $search_criteria,
    } );

    my $vertical_mt_name = $c->req->param('vertical_mt_name');
    my $horisontal_mt_name = $c->req->param('horisontal_mt_name');
    my $two_way_table = $dataset->two_way_table($search_criteria, $owner_tags, $vertical_mt_name, $horisontal_mt_name );

    my $num_search_cols = $c->stash->{ search_ui_utils }->num_search_cols();
    my @md_cols = ();
    foreach my $col_num ( 1 .. $num_search_cols ){
        my $mt_name = $c->req->param( 'shown_mt_name_' . $col_num );
        if( !$mt_name ){
            $c->log->debug( "Ups! no mt name set for that column: $col_num" );
        } else {
            push @md_cols, $mt_name;
        }

    }

    $c->stash( metadata_columns => \@md_cols );
    $c->stash( datasets => [ $datasets->all() ] );
    $c->stash( datasets_pager => $datasets->pager() );
    $c->stash( two_way_table => $two_way_table );
    $c->stash( dataset_count => $datasets->count() );

}

sub expand_level2 : Chained('perform_search') : PathPart('expand') :Args(1) {
    my ($self, $c, $dataset_id ) = @_;

    $c->req->params->{ "show_level2_$dataset_id" } = 1;

    $c->stash( template => 'search/search_result.tt' );
}

sub deflate_level2 : Chained('perform_search') : PathPart('deflate') :Args(1) {
    my ($self, $c, $dataset_id ) = @_;

    delete $c->req->params->{ "show_level2_$dataset_id" };

    $c->stash( template => 'search/search_result.tt' );

}

sub set_level2_page : Chained('perform_search') : PathPart('level2page') :Args(2) {
    my ($self, $c, $dataset_id, $page_num ) = @_;

    $c->req->params->{"level2_page_${dataset_id}"} = $page_num;

    $c->stash( template => 'search/search_result.tt' );
}

sub wms :Path('/search/wms') :Args {
    my ($self, $c) = @_;

    #print STDERR $c->req->args->[0];

    $c->stash( template => 'search/wms.tt', 'current_view' => 'Raw' );

}

sub wmsThumb :Path('/search/wmsthumb') :Args {
    my ($self, $c) = @_;

    $c->stash( template => 'search/wmsthumb.tt', 'current_view' => 'Raw' );

}

__PACKAGE__->meta->make_immutable;

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
