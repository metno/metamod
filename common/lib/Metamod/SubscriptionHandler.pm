#!/usr/bin/env perl

package Metamod::SubscriptionHandler;

use strict;
use warnings;

use Carp;

=head1 NAME

Metamod::SubscriptionHandler - Base class for all subscription handlers

=head1 DESCRIPTION

This module is a base class for all subscription handlers.

=head1 FUNCTIONS/METHODS

=cut

sub new {
    my $class = shift;
    
    my $self = bless {}, $class;
    
    return $self;    
}

=head2 $self->push_to_subscribers( $ds_name, $file_path, $subscribers )

Push the new file to the subscripers.

=over

=item $ds_name

The name of the dataset that the new file belongs to. Used to find the
subscribers that should be notified.

=item $file_path

The path to where the file can be found for the subscription handler.

=item $subscribers

A reference to list of subscriptions. Each subscription is a hash reference
with the information neccessary for the specific subscription handler.

=item return

Returns 1 on success. False otherwise.

=back

=cut
sub push_to_subscribers {
	my $self = shift;
	
	confess 'Should be implemented in the sub class';
}

1;