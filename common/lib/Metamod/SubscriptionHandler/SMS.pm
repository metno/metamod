#!/usr/bin/env perl

package Metamod::SubscriptionHandler::Email;

use base 'Metamod::SubscriptionHandler';

use strict;
use warnings;

=head1 NAME

Metamod::SubscriptionHandler::Email - Subscription handler for email.

=head1 DESCRIPTION

This module implements a subscription handler that notifies subscribers over
email that a new file has become available. 

=head1 FUNCTIONS/METHODS

=cut


=head2 $self->push_to_subscribers( $ds_name, $file_path, $subscribers )

See documentation in base class.

=cut
sub push_to_subscribers {
    my $self = shift;
    
}

1;