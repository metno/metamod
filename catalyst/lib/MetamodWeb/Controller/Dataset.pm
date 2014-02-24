package MetamodWeb::Controller::Dataset;

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

use Metamod::Dataset;

use XML::RSS::LibXML;

BEGIN {extends 'MetamodWeb::BaseController::Base'; }

=head1 NAME

MetamodWeb::Controller::Dataset - Controller for viewing information about a single dataset.

=head1 DESCRIPTION

This controller implements action for retrieving information about a single dataset.

=head1 METHODS

=cut



sub auto :Private {
    my ( $self, $c ) = @_;

    push @{ $c->stash->{ css_files } }, $c->uri_for( '/static/css/dataset.css' );
    $c->stash( section => 'dataset' );
}

=head2 index

Action for viewing all datasets that are available in the catalog. This page is
primarily intended for search engines.

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    my $search_utils = MetamodWeb::Utils::SearchUtils->new( { c => $c, config => $c->stash->{ mm_config } } );
    my $ownertags = $search_utils->get_ownertags();
    my @level1_datasets = $c->model('Metabase::Dataset')->level1_datasets( $ownertags )->all();
    $c->stash( template => 'dataset/level1_datasets.tt', datasets => \@level1_datasets );
}

=head2 ds_id

Root for chained actions. Used to get the ds_id from the URL and check that it
actually matches a dataset in the catalog.

If the dataset cannot be found the request is detached to the 'default' action
in the Root controller.

=cut

sub ds_id :Chained("") :PathPart("dataset") :CaptureArgs(1) {
    my ( $self, $c ) = @_;

    my $ds_id = $c->req->args->[0];
    my $ds = $c->model('Metabase::Dataset')->find($ds_id);

    if( !defined $ds ){
        $self->logger->warn("Could not find dataset for ds_id '$ds_id'");
        $c->detach('Root', 'default' );
    }

    $c->stash( ds_id => $ds_id, ds => $ds );

}

=head2 xml

A chained action for displaying the metadata XML for a dataset.

=cut

sub xml :Chained("ds_id") :PathPart("xml") :Args(0) {
    my ( $self, $c ) = @_;

    eval {
        my $ds_id = $c->stash->{ ds_id };
        my $meta_db = $c->model('Metabase');
        my $ds = $meta_db->resultset('Dataset')->find( $ds_id ) or die "Dataset $ds_id not found";
        my $path =  $ds->xmlfile() or die "XML file not found for dataset $ds_id";
        my $mmDs = Metamod::ForeignDataset->newFromFile( $path );
        $c->response->content_type('text/xml');
        # return the document in utf encoding
        $c->response->body( '<?xml version="1.0" encoding="UTF-8"?>'."\n"
                           #. '<?xml-stylesheet type="text/css" href="../../static/css/'. $ds->ds_metadataformat .'.css"?>'."\n"
                           . $mmDs->getMETA_DOC()->documentElement()->toString(1)
                          );
    };

    if( $@ ){
        $self->logger->warn("Error in dataset xml output: $@");
        #print STDERR ("Error in dataset xml output: $@\n");
        $c->detach( 'Root', 'error', [404, $@] );
    }

}

=head2 wmsinfo

A chained action for displaying the wmsinfo XML for a dataset.

=cut

sub wmsinfo :Chained("ds_id") :PathPart("wmsinfo") :Args(0) {
    my ( $self, $c ) = @_;

    eval {
        my $ds_id = $c->stash->{ ds_id };
        my $meta_db = $c->model('Metabase');
        my $ds = $meta_db->resultset('Dataset')->find( $ds_id ) or die "Dataset $ds_id not found";
        my $wmsinfo =  $ds->wmsinfo() or die "No wmsinfo not found for dataset $ds_id";
        $c->response->content_type('text/xml');
        $c->response->body( $wmsinfo->toString(1) );
    };

    if( $@ ){
        $self->logger->warn("Error in dataset wmsinfo output: $@");
        #print STDERR ("Error in dataset xml output: $@\n");
        $c->detach( 'Root', 'error', [404, $@] );
    }

}

=head2 view

A chained action for viewing the metadata for a dataset in HTML.

=cut

sub view :Chained("ds_id") :PathPart("view") :Args(0) {
    my ($self, $c) = @_;

    $c->stash( template => 'dataset/view.tt' );

}

=head2 wmssetup

A chained action for getting the WMS setup info for a dataset. The WMS setup
info is returned as a XML document.

=cut

sub wmssetup :Chained("ds_id") :PathPart("wmssetup") :Args(0) {
    my ( $self, $c ) = @_;

    eval {
        my $ds_id = $c->stash->{ ds_id };
        my $meta_db = $c->model('Metabase');
        my $ds = $meta_db->resultset('Dataset')->find( $ds_id );

        $c->response->content_type('text/xml');
        $c->response->body( $ds->wmsinfo->toString );
    };

    if( $@ ){
        $self->logger->error("Error in dataset (missing wmsinfo?): $@");
        #print STDERR "Error in dataset (missing wmsinfo?): $@\n";
        $c->detach( 'Root', 'default' );
    }

}

=head2 rss

A chained action for generating a RSS feed for a level 1 dataset.

=cut

sub rss :Chained("ds_id") :PathPart("rss") : Args(0) {
    my ( $self, $c ) = @_;

    my $mm_config = $c->stash->{ mm_config };
    my $ds_id = $c->stash->{ ds_id };
    my $ds = $c->stash->{ ds };

    my $ds_name          = $ds->unqualified_ds_name();

    my $config = Metamod::Config->instance();
    my $application_name = $mm_config->get('APPLICATION_NAME');
    my $base_url = $mm_config->get('BASE_PART_OF_EXTERNAL_URL');
    my $local_url = $mm_config->get('LOCAL_URL');

    my $rss = XML::RSS::LibXML->new( version => '2.0' );
    $rss->channel(
        title => "$application_name Dataset feed for $ds_name",
        description =>
            "$application_name dataset feed for $ds_name. Provides updates when new files are available in the dataset.",
        link      => $base_url . $local_url,
        generator => 'METAMOD',
    );

     $rss->add_module(prefix => 'georss', uri => 'http://www.georss.org/georss');

    my @level2_datasets = $c->model('Metabase::Dataset')->level2_datasets( { ds_id => $ds_id } );

    # generate a RSS item for each of the level2 datasets that belongs to the level1 dataset.
    my @level2_ids = map { $_->ds_id } @level2_datasets;
    if (@level2_ids) {
        foreach my $ds (@level2_datasets){
            my $md       = $ds->metadata( [qw( title abstract dataref bounding_box )] );
            my $title    = join " ", @{ $md->{title} };
            my $abstract = join " ", @{ $md->{abstract} };
            my $link     = $md->{dataref}->[0];         # assume one dataref. Concating links does not make sense.

            my %item = (
                title       => $title,
                link        => $link,
                description => $abstract,
            );

            if( my $bbox = $md->{bounding_box}->[0] ) {
                # convert bounding box from ESWN to SWNE
                my ($e, $s, $w, $n) = split(',', $bbox);
                $item{'georss'} = { box  => "$s $w $n $e" };
            }

            $rss->add_item(%item);

        }
    }

    $c->response->content_type( 'application/rss+xml' );
    $c->response->body( $rss->as_string() );

}

__PACKAGE__->meta->make_immutable;

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
