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

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

MetamodWeb::Controller::Dataset - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub auto :Private {
    my ( $self, $c ) = @_;

    push @{ $c->stash->{ css_files } }, $c->uri_for( '/static/css/dataset.css' );

}

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    my @level1_datasets = $c->model('Metabase::Dataset')->level1_datasets()->all();
    $c->stash( template => 'dataset/level1_datasets.tt', datasets => \@level1_datasets );
}

sub ds_id :Chained("") :PathPart("dataset") :CaptureArgs(1) {
    my ( $self, $c ) = @_;

    my $ds_id = $c->req->args->[0];
    my $ds = $c->model('Metabase::Dataset')->find($ds_id);

    if( !defined $ds ){
        $c->log->warn("Could not find dataset for ds_id '$ds_id'");
        $c->detach('Root', 'default' );
    }

    $c->stash( ds_id => $ds_id, ds => $ds );

}

sub xml :Chained("ds_id") :PathPart("xml") :Args(0) {
    my ( $self, $c ) = @_;

    eval {
        my $ds_id = $c->stash->{ ds_id };
        my $meta_db = $c->model('Metabase');
        my $ds = $meta_db->resultset('Dataset')->find( $ds_id );
        my $mmDs = Metamod::Dataset->newFromFile( $ds->ds_filepath() );

        $c->response->content_type('text/xml');
        $c->response->body( $mmDs->getMETA_XML() );
    };

    if( $@ ){
        $c->log->error("Error in dataset xml output: $@");
        print STDERR ("Error in dataset xml output: $@\n");
        $c->detach( 'Root', 'default' );
    }

}

sub view :Chained("ds_id") :PathPart("view") :Args(0) {
    my ($self, $c) = @_;

    $c->stash( template => 'dataset/view.tt' );

}

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
        $c->log->error("Error in dataset (missing wmsinfo?): $@");
        print STDERR "Error in dataset (missing wmsinfo?): $@\n";
        $c->detach( 'Root', 'default' );
    }

}
sub rss :Chained("ds_id") :PathPart("rss") : Args(0) {
    my ( $self, $c ) = @_;

    my $mm_config = $c->stash->{ mm_config };
    my $ds_id = $c->stash->{ ds_id };
    my $ds = $c->stash->{ ds };

    my $ds_name          = $ds->unqualified_ds_name();

    my $config = Metamod::Config->new();
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

    my @level2_datasets = $c->model('Metabase::Dataset')->level2_datasets( { ds_id => $ds_id } );

    # generate a RSS item for each of the level2 datasets that belongs to the level1 dataset.
    my @level2_ids = map { $_->ds_id } @level2_datasets;
    if (@level2_ids) {
        foreach my $ds (@level2_datasets){
            my $md       = $ds->metadata( [qw( title abstract dataref )] );
            my $title    = join " ", @{ $md->{title} };
            my $abstract = join " ", @{ $md->{abstract} };
            my $link     = $md->{dataref}->[0];               #assume one dataref. Concating links does not make sense.

            $rss->add_item(
                title       => $title,
                link        => $link,
                description => $abstract,
            );
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
