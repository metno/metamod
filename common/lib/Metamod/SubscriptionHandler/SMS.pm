#!/usr/bin/env perl

package Metamod::SubscriptionHandler::SMS;

use base 'Metamod::SubscriptionHandler';

use strict;
use warnings;

use Config::Tiny;
use Cwd qw( abs_path );
use File::Spec;
use Params::Validate qw( :all );

use Metamod::mmUserbase;
use Metamod::SubscriptionUtils qw( split_parent_name get_basename );

=head1 NAME

Metamod::SubscriptionHandler::SMS - Subscription handler for email.

=head1 DESCRIPTION

This module implements a subscription handler that sends transfers files to 
subscribers via Met.no SMS system. This module is responsible for notifying SMS
that a new transfer is needed and then the SMS system is responsible actually
transfering the file to subscriber.

The module tells SMS that a new file should be transferred by first writing a
transfer configuration file to a specified directory and then touching a
last_changed that SMS monitors for changes. SMS then initiates the transfer.

=head1 FUNCTIONS/METHODS

=cut

=head2 $self->push_to_subscribers( $ds, $subscribers )

See documentation in base class.

=cut

sub push_to_subscribers {
    my $self = shift;

    my ( $ds, $subscribers ) = validate_pos( @_, { isa => 'Metamod::Dataset' }, { type => ARRAYREF } );

    # create a hash of hash references. The key is used to create unique sections in the
    # .ini file. The value is the transfer parameters as a hash reference.
    my $transfer_id     = 1;
    my @transfer_ids    = ();
    my $transfer_config = Config::Tiny->new();
    foreach my $subscription (@$subscribers) {

        my $valid = $self->_validate_transfer_params(%$subscription);
        next if !$valid;

        $transfer_config->{ 'transfer_' . $transfer_id } = $subscription;
        push @transfer_ids, ( 'transfer_' . $transfer_id );
        $transfer_id++;
    }

    if ( !@transfer_ids ) {
        $self->{_logger}->debug('None of the subscriptions had valid parameters. No transfer initiated');
        return;
    }

    $transfer_config->{transfer}->{transfers} = join ',', @transfer_ids;
    $transfer_config->{transfer}->{filepath} = $self->_get_file_location($ds);
    if ( !defined $transfer_config->{transfer}->{filepath} ) {
        $self->{_logger}->error('Failed to find the file path for the dataset');
        return;
    }

    # write the transfer configuration to a INI file
    my %ds_info       = $ds->getInfo();
    my $transfer_file = $self->_ds_file_name( $ds_info{name} ) . '.ini';
    my $transfer_dir  = $self->{_config}->get('SUBSCRIPTION_SMS_DIRECTORY');
    $transfer_file = File::Spec->catfile( $transfer_dir, $transfer_file );
    my $success = $transfer_config->write($transfer_file);
    if ( !$success ) {
        $self->{_logger}->error("Failed to write the transfer file");
        return;
    }

    my $notify_success = $self->_notify_sms();

    return $notify_success;

}

=head2 $self->_notify_sms()

Notify the SMS system that a new transfer is ready by 'touching' a last changed file.

=over

=item return

Returns 1 on success. False on error.

=back

=cut 

sub _notify_sms {
    my $self = shift;

    my $transfer_dir = $self->{_config}->get('SUBSCRIPTION_SMS_DIRECTORY');
    my $last_changed_file = File::Spec->catfile( $transfer_dir, 'last_changed' );
    if ( !( -e $last_changed_file ) ) {
        my $success = open my $TEMP, '>', $last_changed_file;
        if ( !$success ) {
            $self->{_logger}->error("Failed to created last_changed file: $!");
            return;
        }
    }

    my $mod_time = time;
    my $files_changed = utime $mod_time, $mod_time, $last_changed_file;
    if ( 1 != $files_changed ) {
        $self->{_logger}->error("Failed to 'touch' last_changed file");
        return;
    }

    return 1;

}

=head2 $self->_validate_transfer_params( $params )

Validate that the transfer parameters have the correct format neccessary for transfer.

=over

=item $params

The subscription parameters that should be validated.

=item return

Returns 1 on success. False on error.

=back

=cut

sub _validate_transfer_params {
    my $self = shift;

    eval {
        validate(
            @_,
            {
                transfer_type => { regex    => qr/^ftp$/ },
                server        => { regex    => qr/.+/ },
                username      => { required => 1 },
                password      => { required => 1 },
                directory     => { required => 1 },
                ftp_type      => { regex    => qr/^active|passive$/ },
                U_email       => { required => 1 },
            }
        );
    };

    if ($@) {
        $self->{_logger}->warn("Invalid SMS subscription parameters: $@");
        return;
    }

    return 1;

}

=head2 $self->_get_file_location( $ds )

Get the absolute location of the file on disk where it can be accessed by SMS.

=over

=item return

=back

=cut

sub _get_file_location {
    my $self = shift;

    my ($ds) = @_;

    my ( $applic_id, $ds_name ) = split_parent_name( $ds->getParentName() );

    my $userbase = $self->_get_userbase();
    if ( !defined $userbase ) {
        return;
    }
    my $dataset_found = $userbase->dset_find( $applic_id, $ds_name );

    if ( !$dataset_found ) {
        $self->{_logger}->error("No dataset for '$applic_id' and '$ds_name' in the user database");
        return;
    }

    my $location = $userbase->infoDS_get('LOCATION');

    if ( !$location ) {
        $self->{_logger}->warn("No location information found for dataset ('$applic_id','$ds_name')");
        return;
    }

    # if the location attribute is relative make it absolute. This probably only occurs during testing
    # $location = abs_path( $location );

    my %info = $ds->getInfo();
    if ( !exists $info{name} || !$info{name} ) {
        $self->{_logger}->error("Dataset has no name");
        return;
    }

    my $basename = get_basename( $info{name} );

    my $fullpath = File::Spec->catfile( $location, $basename . '.nc' );
    if ( -e $fullpath ) {
        return $fullpath;
    } else {
        $self->{_logger}->debug("Dataset file not found at '$fullpath'");
    }

    # If the file does not exists there are two possibilities, either it does not
    # exist or it is located in a sub directory. We try the sub directory
    # approach before giving up.
    my %metadata = $ds->getMetadata();
    if ( !exists $metadata{dataref} ) {
        $self->{_logger}->debug("Dataset file did not have a dataref");
        return;
    }

    # assume only one dataref for each file.
    my $dataset_path = $self->_parse_dataref( $metadata{dataref}->[0] );
    if ( !defined $dataset_path ) {
        $self->{_logger}->debug("Dataref did not contain a dataset name");
        return;
    }

    $fullpath = $self->_join_location_dataset_path( $location, $dataset_path );

    if ( -e $fullpath ) {
        return $fullpath;
    } else {
        $self->{_logger}->debug("Dataset file not found at '$fullpath'");
    }

    return;

}

sub _parse_dataref {
    my $self = shift;

    my ($dataref) = @_;

    my $dataset;
    if ( $dataref =~ /dataset=([\w \. \/ ]+)/x ) {
        $dataset = $1;
    } else {
        $self->{_logger}->debug("'$dataref' did not contain a dataset name");
        return;
    }

    return $dataset;

}

=head2 $self->_join_location_dataset_path( $location, $dataset_path )

Joins a location path string with a dataset_path string as returned by
_parse_dataref. The paths are joined so that the entire location path is joined
with the part of the dataset path that comes after the common path string.

For instance if we have the $location '/some/absolute/dataset/path' and the
$dataset_path 'met.no/category/dataset/path/2010/02/dataset.nc this function
will produce the path '/some/absolute/dataset/path/2010/02/dataset.nc'

=over

=item $location

The LOCATION string for the dataset as found in the user database.

=item $dataset_path

A dataset path as returned by C<_parse_dataref()>.

=item return

Returns a joined path. If the two strings have no common substring the paths
cannot be joined and false is returned.

=back

=cut

sub _join_location_dataset_path {
    my $self = shift;

    my ( $location, $dataset_path ) = @_;

    # We want to get the part of $dataset_path that comes after the common part with
    # $location. We do so by trying to match a short and shorter version of $location
    # against $dataset_path and when we get match we retrieve the part after the match.
    my $index = 0;
    my $dataset_end;
    while ( $index < length($location) ) {
        my $location_part = substr( $location, $index );

        my $match_position = index( $dataset_path, $location_part );
        if ( -1 != $match_position ) {
            $dataset_end = substr( $dataset_path, ( $match_position + length($location_part) ) );
            last;
        }
        $index++;

    }

    if ( !defined $dataset_end ) {
        return;
    }

    return $location . $dataset_end;

}

=head2 $self->_ds_file_name( $ds_name )

Get the file name part of a dataset name.
    
=over

=item $ds_name

The full name of the dataset.

=item return

The last part of the dataset name on success. If the format of C<$ds_name> is
not correct it returns false

=back

=cut

sub _ds_file_name {
    my $self = shift;

    my ($ds_name) = @_;

    my $filename;
    if ( $ds_name =~ /^.+\/(.+)$/ ) {
        $filename = $1;
    } else {
        $self->{_logger}->error("Dataset name $ds_name does not have correct format");
        return;
    }

    return $filename;

}

1;
