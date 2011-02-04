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

use MetamodWeb::Utils::UI::CollectionBasket;

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

    my $mm_config = $c->stash->{mm_config};

    my $cb_ui_utils = MetamodWeb::Utils::UI::CollectionBasket->new( { config => $mm_config, c => $c } );
    $c->stash( collection_basket_ui_utils => $cb_ui_utils, );

    push @{ $c->stash->{css_files} }, $c->uri_for('/static/css/search.css');

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

    my $cookie = $c->req->cookies->{metamod_basket};
    if ( !defined $cookie ) {
        $c->stash( info_msgs => ['There are no files in the collection basket to download'] );
        $c->detach('view');
    }

    my @dataset_ids = $cookie->value();

    if ( 0 == @dataset_ids ) {
        $c->stash( info_msgs => ['There are no files in the collection basket to download'] );
        $c->detach('view');
    }

    my @dataset_locations = ();
    foreach my $ds_id (@dataset_ids) {

        my $ds = $c->model('Metabase::Dataset')->find($ds_id);

        if ( !defined $ds ) {
            $c->log->error('Attempted to download dataset the does not exist');
            next;
        }

        my $file_location = $ds->file_location();

        if ( !defined $file_location ) {
            $c->log->warn("Could not find the file location for '$ds_id'");
            next;
        }

        push @dataset_locations, $file_location;
    }

    #my $db_path = $c->path_to('jobqueue.db');
    #my $job_client = TheSchwartz->new( databases => [ { dsn => "dbi:SQLite:dbname=$db_path" } ] );

    my $mm_config  = $c->stash->{mm_config};
    my $job_client = TheSchwartz->new(
        databases => [
            {
                dsn  => $mm_config->getDSN_Userbase(),
                user => $mm_config->get('PG_WEB_USER'),
                pass => $mm_config->get('PG_WEB_USER_PASSWORD')
            }
        ]
    );

    $job_client->insert(
        'Metamod::Worker::PrepareDownload',
        {
            locations => \@dataset_locations,
            email     => $email_address
        }
    );

    $c->stash( info_msg => ['The download is being prepared for you. Please wait for an email'] );
    $c->detach('view');

}

=head2 add_to_basket()

Action for adding a dataset to the collection basket.

=cut

sub add_to_basket : Chained("/search/perform_search") : PathPart('add_to_basket') : Args(1) {
    my ( $self, $c, $ds_id ) = @_;

    my $cookie = $c->req->cookies->{metamod_basket};

    my %ds_ids = ();
    if ( defined $cookie ) {

        my @ds_ids = $cookie->value();

        # ensure that ds_ids are unique
        %ds_ids = map { $_ => 1 } @ds_ids;
    }

    my $dataset = $c->model('Metabase::Dataset')->find($ds_id);

    if ( defined $dataset ) {

        if ( $dataset->is_level1_dataset() ) {

            my @child_ds_ids = $dataset->child_datasets->get_column('ds_id')->all();
            foreach my $child_ds_id (@child_ds_ids) {
                $ds_ids{$child_ds_id} = 1;
            }
        } else {
            $ds_ids{$ds_id} = 1;
        }
    } else {
        $c->log->error("Tried to add non-existant dataset to the collection basket: $ds_id");
    }

    $c->response->cookies->{metamod_basket} = { value => [ keys %ds_ids ] };

    my $mm_config = $c->stash->{mm_config};
    my $s_ui_utils = MetamodWeb::Utils::UI::Search->new( { config => $mm_config, c => $c } );

    $c->stash(
        template        => 'search/search_result.tt',
        search_ui_utils => $s_ui_utils,
        in_search_app   => 1,
    );

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

    my $cookie = $c->req->cookies->{metamod_basket};

    if ( defined $cookie ) {

        # manipulate the cookie here so that it will be empty when reaching view()
        $cookie->value( [] );
        $c->response->cookies->{metamod_basket} = $cookie;
    }

    $c->stash( info_msgs => ['The collection basket has been emptied'] );
    $c->detach('view');
}

=head2 remove_selected()

Remove a list of selected datasets from the current collection basket.

=cut

sub remove_selected : Path('/search/collectionbasket/remove_selected') : Args(0) {
    my ( $self, $c ) = @_;

    my $dataset_ids = $c->req->params->{'remove_file'} || [];

    if ( 0 != @$dataset_ids ) {

        my $cookie = $c->req->cookies->{metamod_basket};
        if ( defined $cookie ) {

            my @ds_ids = $cookie->value();

            # ensure that ds_ids are unique
            my %ds_ids = map { $_ => 1 } @ds_ids;

            foreach my $ds_id (@$dataset_ids) {
                delete $ds_ids{$ds_id};
            }

            # manipulate the cookie here so that it will be empty when reaching view()
            $cookie->value( [ keys %ds_ids ] );
            $c->response->cookies->{metamod_basket} = $cookie;
        }

    }

    $c->forward('view');
}

__PACKAGE__->meta->make_immutable;

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
