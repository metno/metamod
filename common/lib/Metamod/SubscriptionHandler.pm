#!/usr/bin/env perl

package Metamod::SubscriptionHandler;

use strict;
use warnings;

use Carp;
use Log::Log4perl qw( get_logger );

use Metamod::Config;

=head1 NAME

Metamod::SubscriptionHandler - Base class for all subscription handlers

=head1 DESCRIPTION

This module is a base class for all subscription handlers.

=head1 FUNCTIONS/METHODS

=cut

sub new {
    my $class = shift;
    
    my $self = bless {}, $class;
    $self->{ _config } = Metamod::Config->new();
    $self->{ _logger } = get_logger('metamod.subscription');
    
    return $self;    
}

=head2 $self->push_to_subscribers( $ds, $subscribers )

Push the new file to the subscripers.

=over

=item $ds

A reference to L<Metamod::Dataset> object

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