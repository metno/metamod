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

=head1 NAME

MetamodWeb::Utils::CollectionBasket - The class responsible for implementing the collection basket.

=head1 DESCRIPTION

This class implements the actual collection basket. That is it implements a
basket of datasets that the user can later download.

This class is responsible for handling all the interaction with the underlying
storage mechanism, whether it is in a cookie or on the server.

=head1 FUNCTIONS/METHODS

=cut

use Data::Dump qw(dump);
use Data::Dumper;
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

=head2 $self->add_dataste($ds_id)

Add a new level 1 or level 2 dataset to the collection basket. In the case of
adding a level 1 dataset it will add level 2 datasets that match the current
search criteria AND have C<data_file_location> set. In addition it will only try to
added (max basket size - current basket size) files to the basket for
efficiency reason.

If the level 1 dataset has no children but has wmsinfo, the parent dataset will be
added instead. (work in progress)

=over

=item $ds_id

The ds_id of the dataset to add.

=item return

Return the number of datasets to that was added to the collection basket.
Returns undef if for some reason no dataset could not be added, or number of files added if successful.

=back

=cut

sub add_dataset {
    my $self = shift;

    my ($ds_id) = @_;

    my @ds_ids = @{ $self->dataset_ids };
    my %ds_ids = map { $_ => 1 } @ds_ids;
    my $user   = eval { $self->c->user->u_loginname } || $self->c->req->address || '(none)';

    my $dataset = $self->meta_db->resultset('Dataset')->find($ds_id);
    $self->logger->debug("User $user added dataset $ds_id to basket");

    # default to 100 as max number of files
    my $max_files = $self->max_files();
    my $max_additional = $max_files - scalar @ds_ids;
    $self->logger->debug("Space for $max_additional more files in the basket (max $max_files)");

    # default to 500 MB as max size
    my $max_size = $self->max_size();
    my $current_size = $self->calculate_size();

    my $new_datasets = 0;
    if ( ! defined $dataset ) {
        $self->logger->warn("Tried to add non-existant dataset to the collection basket: $ds_id");
        return;
    }

    if ( $max_additional <= 0 ) {
        # basket is full, go away
        my $msg = "Could not add the file to the basket since the basket would then exceed the allowed number of files ($max_files).";
        $self->add_user_msg($msg);
        $self->logger->info("Could not add file $ds_id to collection basket for $user as it exceeds the max count of $max_files");
        return;
    }

    if ( $dataset->is_level1_dataset() ) {

        if ( $dataset->num_children() ) {

            # We must take into account the search parameters that was used in
            # the search when adding level 2 dataset.

            my ($search_conds, $search_attrs) = $self->_metadata_search_params();
            $search_attrs->{ rows } = $max_additional;
            my $child_datasets = $dataset->child_datasets($search_conds, $search_attrs);

            if ($child_datasets->count() > $max_additional) {
                my $msg = "Could not add all files to the basket since the basket would then exceed the allowed number of files ($max_files).";
                $self->add_user_msg($msg);
                $self->logger->info("Could not add files under $ds_id to collection basket for $user as it exceeds the max count of $max_files");
                return;

            } else {

                while ( my $child_ds = $child_datasets->next() ) {

                    my $file_info = $self->file_info($child_ds);
                    if ( defined $file_info ) {

                        # when we reach the maximum we stop even if there might smaller files later.
                        # This probably will seem like less random behaviour.
                        if( $file_info->{data_file_size}||0 + $current_size > $max_size ){
                            my $msg = 'Could not add all files to the basket since the basket would then exceed the ';
                            $msg .= "allowed maximum size ($max_size bytes).";
                            $self->add_user_msg($msg);
                            $self->logger->info("Could not add file $ds_id to collection basket for $user as it exceeds the max size of $max_size");
                            #last;
                            return; # better not to add any files at all if size is too big
                        }

                        $current_size += $file_info->{data_file_size}||0;
                        $ds_ids{$child_ds->ds_id()} = 1;
                        $new_datasets++;
                    }
                }

            }

        } elsif ( $dataset->wmsinfo() ) {

            # this is only used for visualization
            $ds_ids{$dataset->ds_id()} = 1;
            $new_datasets++; # why not working? FIXME (still an issue? TODO)

        }

    } else { # level 2 dataset

        my $file_info = $self->file_info($dataset);
        if( defined $file_info ){

            if( ($file_info->{data_file_size} || 0) + $current_size < $max_size ){
                $ds_ids{$dataset->ds_id()} = 1;
                $new_datasets++;
            } else {
                my $msg = 'Could not add the file to the basket since the basket would then exceed the allowed maximum byte size.';
                $self->add_user_msg($msg);
                $self->logger->info("Could not add file $ds_id to collection basket for $user as it exceeds the max byte size");
                return;
            }
        } else {
            $self->logger->warn("$user tried to add level 2 dataset without data_file_location to basket. Error in UI");
            return;
        }
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

=head2 $self->find_data_locations()

Returns ref to list of file locations (may be fewer than # of items in basket, possibly none)

=over

=item Parameters

Collection basket ref

=back

=cut

sub find_data_locations {
    my $self = shift;

    my $files = $self->files();

    #print STDERR "*********" . Dumper \$files;
    my @dataset_locations;
    my $search_utils = MetamodWeb::Utils::SearchUtils->new( { c => $self->c, config => $self->config } );

    for (@$files) {
        my $loc = $_->{data_file_location};
        my $free = $search_utils->freely_available($_);
        push @dataset_locations, $loc if $loc && $free;
    }
    return \@dataset_locations;

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
        my $size = $file->{data_file_size};
        $total_size += $size if $size;
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
    #print STDERR Dumper \@dataset_ids;

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

    #print STDERR Dumper \@files;
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

    my $metadata = $dataset->metadata( [qw( data_file_location data_file_size distribution_statement dataref_HTTP)] );

    # now allowing for datasets w/o file info
    #return if !exists $metadata->{data_file_location} || !defined $metadata->{data_file_location}->[0];

    my $wmsurl = $dataset->wmsurl();
    #print STDERR Dumper $wmsurl;

    my $file_info = {
        ds_id              => $dataset->ds_id(),
        name               => $dataset->ds_name(),
        wms_url            => $wmsurl, #$dataset->wmsurl(), # gives odd number of elements in anon hash if used directly - FIXME
        data_file_location => $metadata->{data_file_location}->[0],
        data_file_size     => $metadata->{data_file_size}->[0],
        distribution       => $metadata->{distribution_statement}->[0],
        dataref_HTTP       => $metadata->{dataref_HTTP}->[0],
        OPENDAP            => $dataset->opendap_url(),
    };

    #print STDERR "CollectionBasket file_info: " . Dumper $file_info;
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

    if ($self->config->has('COLLECTION_BASKET_MAX_SIZE')) {
        return $self->config->get('COLLECTION_BASKET_MAX_SIZE');
    } else {
        return 524288000;
    }
}

=head2 $self->max_files()

=over

=item return

The maximum number of files allowed in the basket.

=back

=cut

sub max_files {
    my $self = shift;

    my $default = 100;

    my $maxfiles = $self->config->get('COLLECTION_BASKET_MAX_FILES') || $default;
    if ($self->c->user) {
        return $maxfiles;
    } else {
        return ($maxfiles < $default) ? $maxfiles : $default;
    }

}

=head2 $self->list_download_scripts()

Get list of download scripts from config

=cut

sub list_download_scripts {
    my $self = shift;
    my $scripts = $self->config->split('COLLECTION_BASKET_DOWNLOAD_SCRIPTS');
}

=head2 $self->add_user_msg()

Blah blah blah

=cut

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
