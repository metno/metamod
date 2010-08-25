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


=head2 $self->activate_subscription_handlers( $ds_id )

Find all subscriptions to the dataset and activate the corresponding
subscription handler for pushing the new file to the subscribers.

=over

=item $ds_id

The DS_id of the new dataset. Used to look up data about the dataset in the
database.

=item return

Returns the number of subscriptions to the dataset.

=back

=cut
sub activate_subscription_handlers {
	my $self = shift;
	
	my ( $ds_id ) = @_;
	
	print "I just got called. I am soooo happy! Welcome id: $ds_id\n";
	   
}

1;