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
use TheSchwartz; # can this be removed? FIXME
use namespace::autoclean;
use Data::Dumper;

use Metamod::Queue;
use MetamodWeb::Utils::CollectionBasket;

BEGIN { extends 'MetamodWeb::BaseController::Base'; }

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

}

=head2 view()

Action for displaying the collection basket.

=cut

sub view : Path('/search/collectionbasket') : Args(0) {
    my ( $self, $c ) = @_;

    $c->stash( template => 'search/collectionbasket/view_basket.tt' );

}

=head2 add_to_basket()

Action for adding a dataset to the collection basket.

=cut

sub add_to_basket : Path("/search/add_to_basket/") : Args(1) { # FIXME: should be a POST request
    my ($self, $c, $ds_id) = @_;

    my $basket = $c->stash->{ collection_basket };
    $basket->add_dataset($ds_id);

    $self->add_info_msgs($c, $basket->user_msgs() );

    my $params = $c->req->params;
    my $return_path = delete $params->{return_path};

    $c->res->redirect($c->uri_for($return_path, $params) );

}

=head2 empty_basket()

Action for completely emptying the collection basket.

=cut

sub empty_basket : Path('/search/collectionbasket/empty_basket') :ActionClass('REST') : Args(0) {
    my ( $self, $c ) = @_;
}

sub empty_basket_GET {
    my ( $self, $c ) = @_;

    $c->stash( template => 'search/collectionbasket/delete_basket.tt' );
}

sub empty_basket_POST {
    my ( $self, $c ) = @_;

    my $basket = $c->stash->{collection_basket};

    if ($c->req->params->{'empty_basket'} ne 'Cancel') {
        $basket->empty_basket();
        $self->add_info_msgs( $c, 'The collection basket has been emptied' );
    }
    $c->res->redirect($c->uri_for('/search/collectionbasket'));
}

=head2 remove_selected()

Remove a list of selected datasets from the current collection basket.

=cut

sub remove_dataset : Path('/search/collectionbasket/remove_dataset') : Args(0) {
    my ( $self, $c ) = @_;

    if ($c->request->method ne 'POST') {
        $c->response->status(400); # bad request
        $c->response->body("Only POST requests allowed here");
        $c->response->content_type("text/plain");
        $self->logger->error("Non-POST request used for removing basket file");
        return;
    }

    my $dataset_id = $c->req->params->{'remove_file'} || [];

    if( ref( $dataset_id ) eq 'ARRAY' ){
        die "ARRAY sent to remove_dataset should never happen";
    }

    my $basket = $c->stash->{collection_basket};
    $self->add_info_msgs( $c, "Dataset #$dataset_id has been removed from the collection basket" );
    $basket->remove_datasets( $dataset_id );

    $c->res->redirect($c->uri_for('/search/collectionbasket'));
}

=head2 remove_selected()

Remove a list of selected datasets from the current collection basket.
B<DEPRECATED:> Re-implemented template to use a separate POST per dataset

=cut

sub remove_selected : Path('/search/collectionbasket/remove_selected') : Args(0) { # FIXME: should be a POST request
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

    $c->res->redirect($c->uri_for('/search/collectionbasket'));
}

=head2 link_basket()

Makes a basket containing the datasets listed as params

=cut

sub link_basket : Path('/search/collectionbasket/link_basket' ) : Args(0) { # FIXME: should be a POST request?
    my ($self, $c) = @_;

    my $dataset_ids = $c->req->params->{'ds_id'} || [];
    if( ref( $dataset_ids ) ne 'ARRAY' ){
        $dataset_ids = [ $dataset_ids ];
    }

    #print STDERR "dataset_ids: ", Dumper $dataset_ids;

    my $link_basket = MetamodWeb::Utils::CollectionBasket->new( c => $c, temp_basket => 1, dataset_ids => $dataset_ids );

    $c->stash( template => 'search/collectionbasket/link_basket.tt',
               link_basket => $link_basket,
    );

}

=head2 replace_basket()

Does what? FIXME

=cut

sub replace_basket : Path('/search/collectionbasket/replace_basket' ) : Args(0) { # FIXME: should be a POST request
    my ($self, $c) = @_;

    my $basket = $c->stash->{ collection_basket };
    $basket->empty_basket();
    $self->_add_list_to_basket($c);

    $self->add_info_msgs($c, 'Collection basket replaced with file collection' );
    $c->res->redirect($c->uri_for('/search/collectionbasket'));

}

=head2 merge_basket()

Does what? FIXME

=cut

sub merge_basket : Path('/search/collectionbasket/merge_basket' ) : Args(0) { # FIXME: should be a POST request
    my ($self, $c) = @_;

    $self->_add_list_to_basket($c);
    $self->add_info_msgs($c, 'Collection basket merged with file collection' );
    $c->res->redirect($c->uri_for('/search/collectionbasket'));

}

sub _add_list_to_basket : Private { # FIXME: should be a POST request
    my ($self, $c ) = @_;

    my $dataset_ids = $c->req->params->{'ds_id'} || [];
    if( ref( $dataset_ids ) ne 'ARRAY' ){
        $dataset_ids = [ $dataset_ids ];
    }

    my $basket = $c->stash->{ collection_basket };
    foreach my $ds_id (@$dataset_ids){
        $basket->add_dataset($ds_id);
    }

}

=head2 request_download()

Action for requesting the download of the collection basket. This action will
insert a job into a work queue that will create a zip file of all the files in
the collection basket and send a link to the zip file to the email address
requested by the user.

TODO: require login FIXME

=cut

sub request_download : Path('/search/collectionbasket/request_download') {
    # should be rewritten to only accept POST - FIXME
    my ( $self, $c ) = @_;

    my $email_address = $c->req->params->{email_address};
    if ( !$email_address || !Email::Valid->address($email_address) ) {
        $self->add_error_msgs($c, 'You must supply a valid email address before requesting a download');
        $c->res->redirect($c->uri_for('/search/collectionbasket'));
        return;
    }

    my $basket = $c->stash->{collection_basket};

    my $dataset_locations = $basket->find_data_locations();

    #print STDERR "+++++++++++++++++" . Dumper \$dataset_locations;

    if ( 0 == @$dataset_locations ) {
        $self->add_info_msgs($c, 'There are no files in the collection basket to download');
        $c->res->redirect($c->uri_for('/search/collectionbasket'));
        return;
    }

    my $queue = Metamod::Queue->new();
    my $job_parameters = {
            locations => $dataset_locations,
            email     => $email_address,
    };

    my $success = $queue->insert_job( job_type => 'Metamod::Queue::Worker::PrepareDownload',
                                      job_parameters => $job_parameters );

    if( $success ){
        $self->add_info_msgs( $c, 'The download is being prepared for you. Please wait for an email' );
    } else {
        $self->add_error_msgs( $c, 'An error occured and your download could not be prepared' );
    }

    $c->res->redirect($c->uri_for('/search/collectionbasket'));

}

__PACKAGE__->meta->make_immutable;

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
