#!/usr/bin/env perl

package Metamod::Subscription;

use strict;
use warnings;

=head1 NAME

Metamod::Subscription - API for handling push subscriptions to new datasets

=head1 DESCRIPTION

Metamod::Subscription implements the API used for notifying subscripers that a
new file is availabe in a dataset.

The subscriptions are stored in the METAMOD user database and it is the
responsibility of this module to check if there are any subscriptions that
match a new file.

=head1 FUNCTIONS/METHODS

=cut

sub new {
    my $class = shift;
    
    my $self = bless {}, $class;
    
    return $self;
    
}


=head2 $self->activate_subscription_handlers( $ds_name, $file_path )

Find all subscriptions to the dataset and activate the corresponding
subscription handler for pushing the new file to the subscribers.

=over

=item $ds_name

The name of the dataset that the new file belongs to. Used to find the
subscribers that should be notified.

=item $file_path

The path to where the file can be found for the subscription handler.

=item return

Returns the number of subscriptions to the dataset.

=back

=cut
sub activate_subscription_handlers {
	my $self = shift;   
}

1;