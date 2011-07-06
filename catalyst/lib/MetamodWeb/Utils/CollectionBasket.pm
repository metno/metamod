package MetamodWeb::Utils::CollectionBasket;

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

use Data::Dump qw(dump);
use Log::Log4perl qw(get_logger);
use Moose;
use namespace::autoclean;

use warnings;

use Metamod::Config;
use Metamod::Utils;
use MetamodWeb::Utils::SearchUtils;

#
# A Metamod::Config object containing the configuration for the application
#
has 'config' => ( is => 'ro', isa => 'Metamod::Config', default => sub { Metamod::Config->instance() } );

#
# A Catalyst context object.
#
has 'c' => (
    is       => 'ro',
    required => 1,
    handles  => {
        meta_db => [ model => 'Metabase' ],
        user_db => [ model => 'Userbase' ],
    }
);

#
# The Log::Log4perl logger to use in the this class
#
has 'logger' => ( is => 'ro', isa => 'Log::Log4perl::Logger', default => sub { get_logger('metamodweb') } );

#
# The current list of dataset ids in the collection basket
#
has 'dataset_ids' => ( is => 'rw', isa => 'ArrayRef', lazy => 1, builder => '_build_dataset_ids' );

#
# A list of messages to the user
#
has 'user_msgs' => ( is => 'rw', isa => 'ArrayRef', default => sub { [] } );

#
# Flag used to indicate if the basket is only tempory. That is if it should be
# stored in the database or cookie or not stored at all.
#
has 'temp_basket' => ( is => 'ro', default => 0 );

=head1 NAME

MetamodWeb::Utils::CollectionBasket - The class responsible for implementing the collection basket.

=head1 DESCRIPTION

This class implements the actual collection basket. That is it implements a
basket of datasets that the user can later download.

This class is responsible for handling all the interaction with the underlying
storage mechanism, whether it is in a cookie or on the server.

=head1 FUNCTIONS/METHODS

=cut

=head2 $self->add_dataste($ds_id)

Add a new level 1 or level 2 dataset to the collection basket. In the case of
adding a level 1 dataset it will add level 2 datasets that match the current
search criteria AND have C<data_file_location> set. In addition it will only try to
added (max basket size - current basket size) files to the basket for
efficiency reason.

=over

=item $ds_id

The ds_id of the dataset to add.

=item return

Return the number of datasets to that was added to the collection basket.
Returns undef if for some reason the dataset could not be added.

=back

=cut

sub add_dataset {
    my $self = shift;

    my ($ds_id) = @_;

    my @ds_ids = @{ $self->dataset_ids };
    my %ds_ids = map { $_ => 1 } @ds_ids;

    my $dataset = $self->meta_db->resultset('Dataset')->find($ds_id);

    my $max_files = 100;
    my $max_additional = $max_files - scalar @ds_ids;

    # default to 500 MB as max size
    my $max_size = $self->max_size();
    my $current_size = $self->calculate_size();

    my $new_datasets = 0;
    if( defined $dataset ){

        if ( $dataset->is_level1_dataset() ) {

            # We must take into account the search parameters that was used in
            # the search when adding level 2 dataset.

            my ($search_conds, $search_attrs) = $self->_metadata_search_params();
            $search_attrs->{ rows } = $max_additional;
            my $child_datasets = $dataset->child_datasets($search_conds, $search_attrs);

            while ( my $child_ds = $child_datasets->next() ) {

                my $file_info = $self->file_info($child_ds);
                if ( defined $file_info ) {

                    # when we reach the maximum we stop even if there might smaller files later.
                    # This probably will seem like less random behaviour.
                    if( $file_info->{data_file_size} + $current_size > $max_size ){
                        my $msg = 'Could not add all files to the basket since the basket would then exceed the ';
                        $msg .= 'allowed maximum size.';
                        $self->add_user_msg($msg);
                        $self->logger->debug("Could not add file to collection basket as it exceeds the max size");

                        last;
                    }

                    $current_size += $file_info->{data_file_size};
                    $ds_ids{$child_ds->ds_id()} = 1;
                    $new_datasets++;
                }
            }
        } else {

            my $file_info = $self->file_info($dataset);
            if( defined $file_info ){

                if( $file_info->{data_file_size} + $current_size < $max_size ){
                    $ds_ids{$dataset->ds_id()} = 1;
                    $new_datasets++;
                } else {
                    my $msg = 'Could not add the file to the basket since the basket would then exceed the ';
                    $msg .= 'allowed maximum size.';
                    $self->add_user_msg($msg);
                    $self->logger->debug("Could not add file to collection basket as it exceeds the max size");
                }
            } else {
                $self->logger->debug("Tried to add level 2 dataset without data_file_location to basket. Error in UI");
                return;
            }
        }
    } else {
        $self->logger->error("Tried to add non-existant dataset to the collection basket: $ds_id");
        return;
    }

    $self->dataset_ids( [ keys %ds_ids ] );

    $self->add_user_msg("$new_datasets file(s) has been added to the basket.");
    return $new_datasets;

}

sub _metadata_search_params {
    my $self = shift;

    my $search_utils = MetamodWeb::Utils::SearchUtils->new( { c => $self->c, config => $self->config } );
    my $search_criteria = $search_utils->selected_criteria( $self->c->req->params() );
    my $ownertags = $search_utils->get_ownertags();
    my $dataset_rs = $self->meta_db->resultset('Dataset');
    my ($conds, $attrs ) = $dataset_rs->metadata_search_params( { ownertags => $ownertags,
                                                                  search_criteria => $search_criteria } );

    return ($conds, $attrs);

}

=head2 $self->empty_basket()

Make the basket empty, i.e. remove all datasets from the basket.

=over

=item return

Returns 1;

=back

=cut

sub empty_basket {
    my $self = shift;

    $self->dataset_ids([]);

    return 1;

}

=head2 remove_datasets(@remove_ids)

Remove a list of dataset ids from the basket.

=over

=item @remove_ids

A list of ds_ids that should be removed from the collection basket.

=item return

Returns 1.

=back

=cut

sub remove_datasets {
    my $self = shift;

    my @remove_ids = @_;

    my @current_ids = @{ $self->dataset_ids };

    # ensure that ds_ids are unique
    my %current_ids = map { $_ => 1 } @current_ids;

    foreach my $ds_id (@remove_ids) {
        delete $current_ids{$ds_id};
    }

    $self->dataset_ids([ keys %current_ids ]);

    return 1;
}

=head2 $self->calculate_size()

=over

=item return

The size of all the files in the collection basket in bytes.

=back

=cut

sub calculate_size {
    my $self = shift;

    my $files = $self->files();

    my $total_size = 0;
    for my $file (@$files) {
        $total_size += $file->{data_file_size};
    }

    return $total_size;
}

=head2 $self->num_files()

=over

=item return

Returns the number of files in the basket currently.

=back

=cut

sub num_files {
    my $self = shift;

    return scalar @{ $self->dataset_ids };

}

=head2 $self->files()

=over

=item return

Returns an array reference with information about all the files in the
collection basket. Each element in the array is a hash reference with the
following keys 'data_file_location', 'data_file_size', 'ds_name' and 'ds_id'.

=back

=cut

sub files {
    my $self = shift;

    my @files       = ();
    my @dataset_ids = @{ $self->dataset_ids() };

    return [] if 0 == @dataset_ids;

    my $datasets = $self->meta_db()->resultset('Dataset')->search( { ds_id => { -IN => \@dataset_ids } } );

    while ( my $dataset = $datasets->next() ) {
        my $file_info = $self->file_info($dataset);

        if ( defined $file_info ) {
            push @files, $file_info;
        } else {
            $self->logger->debug('Level 2 dataset without data_file_location added to basket. Error in UI.');
        }
    }

    return \@files;

}

=head2 $self->file_info($dataset)

Get the file information from a dataset object.

=over

=item $dataset

A C<DBIx::Class> row object for a dataset.

=item return

A hash reference with file information for the dataset. The hash reference has
the following keys: 'data_file_location', 'data_file_size', 'ds_name' and 'ds_id'.

Returns false if the dataset does not have a 'data_file_location' as part of the
metadata.

=back

=cut

sub file_info {
    my $self = shift;

    my ($dataset) = @_;

    my $metadata = $dataset->metadata( [qw(data_file_location data_file_size)] );

    return if !exists $metadata->{data_file_location} || !defined $metadata->{data_file_location}->[0];

    my $file_info = {
        ds_id              => $dataset->ds_id(),
        data_file_location => $metadata->{data_file_location}->[0],
        data_file_size     => $metadata->{data_file_size}->[0],
        name               => $dataset->ds_name()
    };

    return $file_info;

}

=head2 $self->update_basket()

Update the basket in the current storage format. This will either be setting a
cookie or it means updating the collection basket in the database.

=over

=item return

Returns 1

=back

=cut

sub update_basket {
    my $self = shift;

    if( $self->c->user ){

        my $user_basket = $self->c->user->infou->search( { i_type => 'BASKET' } )->first();
        if( !defined $user_basket ){
            my $infou_rs = $self->user_db->resultset('Infou');
            $user_basket = $infou_rs->create( { u_id => $self->c->user->u_id, i_type => 'BASKET', i_content => '' } );
        }

        $user_basket->update( { i_content => join(',', @{ $self->dataset_ids } ) } );
        $self->remove_basket_cookie()

    } else {
        $self->c->res->cookies->{metamod_basket} = { value => $self->dataset_ids };
    }

    return 1;
}

sub remove_basket_cookie {
    my $self = shift;

    $self->c->res->cookies->{metamod_basket} = { value => [], expires => time - 864000 };

}

=head2 $self->_build_dataset_ids()

Initialise the C<dataset_ids> attribute on object construction.

=cut

sub _build_dataset_ids {
    my $self = shift;

    my %dataset_ids = ();
    if( $self->c->user() ){

        my $user_basket = $self->c->user->infou->search( { i_type => 'BASKET' } )->first();
        if( $user_basket ){
            my $ds_ids = $user_basket->i_content();
            my @dataset_ids = split ',', $ds_ids;
            %dataset_ids = map { $_ => 1 } @dataset_ids;
        }
    }

    my $cookie = $self->c->req->cookies->{metamod_basket};
    if( defined $cookie ){
        my @cookie_ids = $cookie->value();

        foreach my $ds_id (@cookie_ids){
            $dataset_ids{$ds_id} = 1;
        }
    }

    return [ keys %dataset_ids ];

}

=head2 $self->human_readable_size($size)

Wrapper for C<Metamod::Utils::human_readable_size()>. Only exists to make that
function easily available in templates.

=cut

sub human_readable_size {
    my ( $self, $size ) = @_;

    return Metamod::Utils::human_readable_size($size);

}

=head2 $self->max_size()

=over

=item return

The maximum total size of the basket in bytes.

=back

=cut

sub max_size {
    my $self = shift;

    return $self->config->get('COLLECTION_BASKET_MAX_SIZE') || 524288000;

}

sub add_user_msg {
    my ($self, $msg) = @_;

    push @{ $self->user_msgs }, $msg;

}

sub DESTROY {
    my $self = shift;

    # temporary basket should not be updated
    if( !$self->temp_basket() ){
        $self->update_basket();
    }
}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
