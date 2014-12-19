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
use Data::Dumper;

use MetamodWeb::Utils::UI::Search;
use MetamodWeb::Utils::UI::WMS;
use MetamodWeb::Utils::SearchUtils;
use MetamodWeb::Utils::Exception qw(error_from_exception);
use Metamod::WMS;
use Try::Tiny;

BEGIN {extends 'MetamodWeb::BaseController::Base'; }

=head1 NAME

MetamodWeb::Controller::Search - Catalyst controller for the search interface.

=head1 DESCRIPTION

Catalyst controller for the search interface.

=head1 METHODS

=cut

=head2 auto

Controller specific initialisation for each request.

=cut

sub auto :Private {
    my ( $self, $c ) = @_;

    my $mm_config = $c->stash->{ mm_config };
    my $ui_utils  = MetamodWeb::Utils::UI::Search->new( { config => $mm_config, c => $c } );
    my $wms_utils = MetamodWeb::Utils::UI::WMS->new(    { config => $mm_config, c => $c } );
    my $collection_basket = MetamodWeb::Utils::CollectionBasket->new( c => $c );
    $c->stash( search_ui_utils   => $ui_utils,
               wms_utils         => $wms_utils,
               in_search_app     => 1, #used to control which header to show
               section           => 'search',
               collection_basket => $collection_basket,
               ext_ts            => $mm_config->get("TIMESERIES_URL"), # remove FIXME
    );
    $c->stash( debug => $self->logger->is_debug() || $c->req->params->{ debug } );
    push @{ $c->stash->{ css_files } }, $c->uri_for( '/static/css/search.css' );

    #if ($c->req->user_agent =~ /Googlebot/) {
    #    $self->logger->debug($c->req->user_agent . " is spidering me");
    #    $c->detach( 'Root', 'error', [503, 'Closed for maintenance'] );
    #}

}

=head2 index

Action for displaying the search front page.

=cut

sub index : Path("/search") :Args(0) {
    my ( $self, $c ) = @_;

    $c->stash( template => 'search/search.tt');

}

=head2 search_criteria

# formerly display_search_criteria

Action for displaying one of the search criteria forms.

=cut

sub search_criteria : Path('/search') : Args(1) {
    my ( $self, $c, $active_criteria ) = @_;

    my $cats = $c->stash->{search_ui_utils}->search_categories();
    #print STDERR Dumper $cats;
    $c->detach('Root', 'default') unless grep { $_->{sc_idname} eq $active_criteria } @$cats;

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
    # NOTE: This only applies for SRID 93995 and 93031 - all others are handled by OpenLayers
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
    } elsif( $x_coord && $y_coord && $x1 && $y2 && $x2 && $y2 ){
        $x1 = $x_coord;
        $y1 = $y_coord;

        # overwrite the old coordinates
        $c->req->params->{ $ui_utils->html_id_for_map( 'x1' ) } = $x1;
        $c->req->params->{ $ui_utils->html_id_for_map( 'y1' ) } = $y1;

        #clear the second set of parameters
        $c->req->params->{ $ui_utils->html_id_for_map( 'x2' ) } = '';
        $c->req->params->{ $ui_utils->html_id_for_map( 'y2' ) } = '';
    }

    my @srid_cols = split ' ', $c->stash->{'mm_config'}->get("SRID_ID_COLUMNS");
    my @srid_names = split ' ', $c->stash->{'mm_config'}->get("SRID_ID_NAMES");
    #print STDERR Dumper \@srid_cols;

    my %searchmaps;
    foreach (@srid_cols) {
        my $crs = "EPSG:$_";
        my $name = shift @srid_names;
        my $url = getMapURL($crs) or next;
        $searchmaps{$_} = {
            url => $url,
            name => $name || getProjName($crs) || $crs,
        };
    }
    #print STDERR Dumper \%searchmaps;

    $c->stash( #template => 'search/search_criteria.tt',
               active_criteria => $active_criteria,
               searchmaps =>\%searchmaps,
    );
}

=head2 search_result

# formerly display_result

Chained action for displaying the search result.

=cut

sub search_result : Chained("perform_search") : PathPart('result') : Args(0) {
    my ( $self, $c ) = @_;

    #$c->stash( template => 'search/search_result.tt' );

}

=head2 search_options

Action for displaying the search options form.

=cut

sub search_options : Path('/search/options') : Args(0) {
    my ($self, $c) = @_;

    #$c->stash( template => 'search/search_options.tt' );
}

=head2 perform_search

The root of the chained actions performing searches. This action will perform the actual search.

=cut

sub perform_search : Chained("/") :PathPart( 'search/page' ) :CaptureArgs(1) {
    my ( $self, $c ) = @_;

    my $dataset = $c->model('Metabase::Dataset');

    my $curr_page = $c->req->args->[0];
    $c->detach('Root', 'error', [400, 'Page number must be a positive integer']) unless $curr_page > 0;

    my $datasets_per_page = $c->req->params->{ datasets_per_page } || 10;

    my $search_utils = MetamodWeb::Utils::SearchUtils->new( { c => $c, config => $c->stash->{ mm_config } } );
    my $search_criteria = $search_utils->selected_criteria( $c->req->params() );
    my $ownertags = $search_utils->get_ownertags();
    my $search_params = {
            curr_page => $curr_page,
            ownertags => $ownertags,
            rows_per_page => $datasets_per_page,
            search_criteria => $search_criteria,
    };
    my $datasets = try {
        $dataset->metadata_search($search_params);
    } catch {
        $c->detach( 'Root', 'error', [400, $@] ); # maybe something less drastic - FIXME
    };

    my $num_search_cols = $c->req->param('num_mt_columns') || $c->stash->{ search_ui_utils }->num_search_cols();
    my @md_cols = ();
    foreach my $col_num ( 2 .. $num_search_cols ){
        my $mt_name = $c->req->param( 'shown_mt_name_' . $col_num );
        if( !$mt_name ){
            $mt_name = $c->stash->{ search_ui_utils }->default_mt_name($col_num);
            #$self->logger->debug( "Ups! no mt name set for that column: $col_num, so using default" );
        }
        push @md_cols, $mt_name;

    }

    try {
        $c->stash( datasets => [ $datasets->all() ] );
        $c->stash( metadata_columns => \@md_cols );
        $c->stash( datasets_pager => $datasets->pager() );
        $c->stash( dataset_count => $datasets->count() );
    } catch {
        $self->logger->debug("*** SEARCH ERROR: $_");
        $self->add_error_msgs( $c, "Invalid search parameters: $_" );
        my $para = $c->request->params;
        my $path = "/" . $c->req->match;
        $c->response->redirect( $c->uri_for($path, $para ) );
        #$c->detach( 'Root', 'error', [400, $_] );
    }
}

=head2 two_way_table

Action for displaying a two way table of the search result.

=cut

sub two_way_table : Path( "/search/two_way_table" ) : Args(0) {
    my ( $self, $c ) = @_;

    my $dataset = $c->model('Metabase::Dataset');

    my $search_utils = MetamodWeb::Utils::SearchUtils->new( { c => $c, config => $c->stash->{ mm_config } } );
    my $search_criteria = $search_utils->selected_criteria( $c->req->params() );
    my $owner_tags = $search_utils->get_ownertags();
    my $vertical_mt_name = $c->req->param('vertical_mt_name') || $c->stash->{ search_ui_utils }->default_vertical_mt_name();
    my $horisontal_mt_name = $c->req->param('horisontal_mt_name') || $c->stash->{ search_ui_utils }->default_horisontal_mt_name();;
    my $two_way_table = $dataset->two_way_table($search_criteria, $owner_tags, $vertical_mt_name, $horisontal_mt_name );

    $c->stash( two_way_table => $two_way_table );
    $c->stash( template => 'search/two_way_table.tt' );

}

=head2 expand_level2

Action for expanding the view a level 1 dataset so that level 2 datasets are
also displayed.

B<IMPLEMENATION REMARK:> It can be discussed if this should be a controller
action or we should just manipulate the CGI parameters in the template.
Manipulating the CGI parameters gives one less place to worry about the name of
the CGI parameter, but gives some ugly TT code. For that reason we have kept it
here.


=cut

sub expand_level2 : Chained('perform_search') : PathPart('expand') :Args(1) {
    my ($self, $c, $dataset_id ) = @_;

    $c->req->params->{ "show_level2_$dataset_id" } = 1;

    $c->stash( template => 'search/search_result.tt' );
}

=head2 deflate_level2

Action for hiding the view of level 2 datasets for specific level 1 dataset.

B<IMPLEMENATION REMARK:> It can be discussed if this should be a controller
action or we should just manipulate the CGI parameters in the template.
Manipulating the CGI parameters gives one less place to worry about the name of
the CGI parameter, but gives some ugly TT code. For that reason we have kept it
here.


=cut

sub deflate_level2 : Chained('perform_search') : PathPart('deflate') :Args(1) {
    my ($self, $c, $dataset_id ) = @_;

    delete $c->req->params->{ "show_level2_$dataset_id" };

    $c->stash( template => 'search/search_result.tt' );

}

=head2 set_level2_page

Action for changing the display page of level 2 datasets displayed under a
specific level 1 dataset.

B<IMPLEMENATION REMARK:> It can be discussed if this should be a controller
action or we should just manipulate the CGI parameters in the template.
Manipulating the CGI parameters gives one less place to worry about the name of
the CGI parameter, but gives some ugly TT code. For that reason we have kept it
here.

=cut

sub set_level2_page : Chained('perform_search') : PathPart('level2page') :Args(2) {
    my ($self, $c, $dataset_id, $page_num ) = @_;

    $c->req->params->{"level2_page_${dataset_id}"} = $page_num;

    $c->stash( template => 'search/search_result.tt' );
}

=head2 wms

Action for displaying the WMS map

=cut

sub wms :Path('/search/wms') :Args {
    my ($self, $c) = @_;

    $c->stash( template => 'search/wms.tt', 'current_view' => 'Raw' );
    #$c->stash( debug => $self->logger->is_debug() );

    my $dslist = [];
    my $para = $c->req->params->{ ds_id };
    #print STDERR Dumper \$para;
    if ( ref $para ) { # more than one ds_id
        foreach ( @$para ) {
            my $ds = $c->model('Metabase::Dataset')->find($_);
            #printf STDERR " -- %d %s\n", $ds->ds_id, $ds->ds_name;
            push @$dslist, $ds;
        }
    } elsif (defined $para) {
        my $ds = $c->model('Metabase::Dataset')->find($para);
        push @$dslist, $ds;
    } # further processing handled by multiwmc if undefined

    #print STDERR Dumper \$dslist;
    $c->stash(
        datasets => $dslist,
        projections => Metamod::WMS::projList()
    );
}

=head2 wms

Action for displaying list of WMS layers from datasets

=cut

sub wmslist :Path('/search/wmslist') :Args {
    my ($self, $c) = @_;

    $c->stash( template => 'search/wmslist.tt', 'current_view' => 'Raw' );
    #$c->stash( 'current_view' => 'Raw' ) if $c->req->params->{ raw };
    $c->stash( debug => $self->logger->is_debug() );

    my $dslist = [];
    my $para = $c->req->params->{ ds_id };
    if ( ref $para ) {
        foreach ( @$para ) {
            my $ds = $c->model('Metabase::Dataset')->find($_);
            #printf STDERR " -- %d %s\n", $ds->ds_id, $ds->ds_name;
            push @$dslist, $ds;
        }
    } else {
        my $ds = $c->model('Metabase::Dataset')->find($para);
        push @$dslist, $ds;
    }
    #print STDERR Dumper \$dslist;
    $c->stash(
        datasets    => $dslist,
        projections => Metamod::WMS::projList(),
        bgmaps      => Metamod::WMS::bgmapURLs(),
    );
}

=head2 timeseries

Action for displaying time series graphs rendered in browser

=cut

sub timeseries :Path('/search/ts') :Args {
    my ($self, $c) = @_;
    #print STDERR Dumper $c->req->params;
    $c->stash( template => 'search/ts_graph.tt', 'current_view' => 'Raw' );

    my $ds_id = $c->req->params->{ ds_id };
    if ( ref $ds_id ) { # more than one ds_id... TODO?
        $self->logger->debug("Only one ds_id currently allowed");
        $c->detach( 'Root', 'error', [ 400, "Only one ds_id currently allowed"] );
    }

    my $dims = $c->req->params->{ dims };
    #print STDERR "DIMS = ", Dumper \$dims;
    $dims = @$dims[0] if ref $dims; # only take first dimension if several

    my $vars = $c->req->params->{ vars };
    $vars = join ',', @$vars if ref $vars; # accept list of params
    $vars = "$dims,$vars" if $dims; # prepend dimension
    $self->logger->debug("Timeseries for $vars");
    $c->detach( 'Root', 'error', [ 400, "No variables specified in request"] ) unless $vars;

    my $ds = $c->model('Metabase::Dataset')->find($ds_id) or $c->detach('Root', 'default');
    my $metadata = $ds->metadata( ['dataref_OPENDAP', 'title'] );
    my $opendap = $metadata->{'dataref_OPENDAP'}->[0] or die "Missing dataref_OPENDAP in dataset";

    if ( $c->req->params->{ts_ascii} ) {
        $c->res->redirect($c->uri_for('/ts', $ds_id, $vars, 'ascii') );
    } elsif ( $c->req->params->{ts_csv} ) {
        $c->res->redirect($c->uri_for('/ts', $ds_id, $vars, 'csv') );
    } elsif ( $c->req->params->{ts_json} ) {
        $c->res->redirect($c->uri_for('/ts', $ds_id, $vars, 'json') );
    } else { # implicitly ts_graph (not always set)

        my $ext_ts = $c->stash->{mm_config}->external_ts_plot($opendap, $vars);
        if ($ext_ts) {
            $self->logger->debug("External TS_URL = $ext_ts");
            $c->res->redirect($ext_ts);
        } else {
            $c->stash( dataset => $ds, title => $metadata->{'title'}->[0], timeseries => $vars );
        }

    }

}

=head2 display_help

Action for displaying the help message to the user.

=cut

sub display_help : Path('/search/help') : Args(0) {
    my ($self, $c) = @_;

    $c->stash( template => 'search/help.tt' );

}

=head2 error

This always genereates an error (only for debugging)

=cut

sub error : Path('/search/error') : Args(0) {
    my ($self, $c) = @_;

    die "You want errors? You got errors!";
}



#sub wmsThumb :Path('/search/wmsthumb') :Args {
#    my ($self, $c) = @_;
#
#    $c->stash( template => 'search/wmsthumb.tt', 'current_view' => 'Raw' );
#
#}

__PACKAGE__->meta->make_immutable;

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
