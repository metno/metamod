#!/usr/bin/env perl

package Metamod::SubscriptionHandler::SMS;

use base 'Metamod::SubscriptionHandler';

use strict;
use warnings;

use Config::Tiny;
use Params::Validate qw( :all );

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
    my $transfer_id = 1;
    my @transfer_ids = ();
    my $transfer_config = Config::Tiny->new();
    foreach my $subscription ( @$subscribers ){
        
        my $valid = $self->_validate_transfer_params(%$subscription);
        next if !$valid;
        
        $transfer_config->{ 'transfer_' . $transfer_id } = $subscription;
        push @transfer_ids, ( 'transfer_' . $transfer_id ) ;
        $transfer_id++;
    }
    
    if(!@transfer_ids){
        $self->{ _logger }->debug('None of the subscriptions had valid parameters. No transfer initiated');
        return;
    }
    
    $transfer_config->{ transfer }->{ transfers } = join ',', @transfer_ids;
    $transfer_config->{ transfer }->{ filepath } = $self->_get_file_location($ds);

    # write the transfer configuration to a INI file
    my %ds_info = $ds->getInfo();
    my $transfer_file = $self->_ds_file_name( $ds_info{ name } ) . '.ini';     
    my $transfer_dir = $self->{ _config }->get('SUBSCRIPTION_SMS_DIRECTORY');
    $transfer_file = File::Spec->catfile( $transfer_dir, $transfer_file );
    my $success = $transfer_config->write( $transfer_file );
    if( !$success ){
        $self->{ _logger }->error("Failed to write the transfer file");
        return;
    }    

    # touch the monitored last_changed file to tell SMS that a new transfer is ready
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
    
    my $transfer_dir = $self->{ _config }->get('SUBSCRIPTION_SMS_DIRECTORY');
    my $last_changed_file = File::Spec->catfile( $transfer_dir, 'last_changed' );
    if( !( -e $last_changed_file )){
        my $success = open my $TEMP, '>', $last_changed_file;
        if( !$success ){
            $self->{ _logger }->error("Failed to created last_changed file: $!");
            return;
        }
    }
    
    my $mod_time = time;
    my $files_changed = utime $mod_time, $mod_time, $last_changed_file;
    if( 1 != $files_changed ){
        $self->{ _logger }->error("Failed to 'touch' last_changed file");
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
                server        => { regex => qr/.+/ },
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
	
	# TODO implement finding actual file location
	return '/dummy/file';
	   
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
	
	my ( $ds_name ) = @_;   

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
