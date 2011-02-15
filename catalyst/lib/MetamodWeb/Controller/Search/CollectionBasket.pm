package MetamodWeb::Controller::Search::CollectionBasket;

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

use Email::Valid;
use Moose;
use TheSchwartz;
use namespace::autoclean;

use Metamod::Queue;
use MetamodWeb::Utils::CollectionBasket;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

MetamodWeb::Controller::CollectionBasket - Controller for handling the collection basket

=head1 DESCRIPTION

=head1 METHODS

=cut

=head2 auto

Controller specific initisialisation for each request.

=cut

sub auto : Private {
    my ( $self, $c ) = @_;

    my $collection_basket = MetamodWeb::Utils::CollectionBasket->new( c => $c );
    $c->stash( collection_basket => $collection_basket );

}

=head2 request_download()

Action for requesting the download of the collection basket. This action will
insert a job into a work queue that will create a zip file of all the files in
the collection basket and send a link to the zip file to the email address
requested by the user.

=cut

sub request_download : Path('/search/collectionbasket/request_download') {
    my ( $self, $c ) = @_;

    my $email_address = $c->req->params->{email_address};
    if ( !$email_address || !Email::Valid->address($email_address) ) {
        $c->stash( error_msgs => ['You must supply a valid email address before requesting a download'] );
        $c->detach('view');
    }

    my $basket = $c->stash->{collection_basket};
    my $files = $basket->files();

    if ( 0 == @$files ) {
        $c->stash( info_msgs => ['There are no files in the collection basket to download'] );
        $c->detach('view');
    }

    my @dataset_locations = map { $_->{data_file_location} } @$files;

    my $queue = Metamod::Queue->new();
    my $job_parameters = {
            locations => \@dataset_locations,
            email     => $email_address
    };

    my $success = $queue->insert_job( job_type => 'Metamod::Queue::Worker::PrepareDownload',
                                      job_parameters => $job_parameters );

    if( $success ){
        $c->stash( info_msgs => ['The download is being prepared for you. Please wait for an email'] );
    } else {
        $c->stash( error_msgs => ['An error occured and your download could not be prepared'] );
    }

    $c->detach('view');

}

=head2 add_to_basket()

Action for adding a dataset to the collection basket.

=cut

sub add_to_basket : Chained("/search/perform_search") : PathPart('add_to_basket') : Args(1) {
    my ( $self, $c, $ds_id ) = @_;

    my $basket = $c->stash->{ collection_basket };
    $basket->add_dataset($ds_id);
    $basket->update_basket();

    $c->stash( template => 'search/search_result.tt', );

}

=head2 view()

Action for displaying the collection basket.

=cut

sub view : Path('/search/collectionbasket') : Args(0) {
    my ( $self, $c ) = @_;

    $c->stash( template => 'search/collectionbasket/view_basket.tt' );

}

=head2 empty_basket()

Action for completely emptying the collection basket.

=cut

sub empty_basket : Path('/search/collectionbasket/empty_basket') : Args(0) {
    my ( $self, $c ) = @_;

    my $basket = $c->stash->{collection_basket};
    $basket->empty_basket();
    $basket->update_basket();

    $c->stash( info_msgs => ['The collection basket has been emptied'] );
    $c->detach('view');
}

=head2 remove_selected()

Remove a list of selected datasets from the current collection basket.

=cut

sub remove_selected : Path('/search/collectionbasket/remove_selected') : Args(0) {
    my ( $self, $c ) = @_;

    my $dataset_ids = $c->req->params->{'remove_file'} || [];

    # dataset_ids can be either an array ref or just a single scalar if just
    # one is selected for removal. If it is a scalar we convert it to array
    # here.
    if( ref( $dataset_ids ) ne 'ARRAY' ){
        $dataset_ids = [ $dataset_ids ];
    }

    my $basket = $c->stash->{collection_basket};
    $basket->remove_datasets(@$dataset_ids);

    $basket->update_basket();

    $c->forward('view');
}

__PACKAGE__->meta->make_immutable;

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
