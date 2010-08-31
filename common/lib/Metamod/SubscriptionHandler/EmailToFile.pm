package Metamod::SubscriptionHandler::EmailToFile;

use strict;
use warnings;

use base 'Metamod::SubscriptionHandler::Email';

=head1 NAME

Metamod::SubscriptionHandler::EmailToFile - Subscription handler that sends email to file. Used for automatic testing.

=head1 DESCRIPTION

This class is used to override the neccessary parts of Metamod::SubscriptionHandler::Email so that emails are written
to a file instead of being being actually sent. This simplifies testing.

=head1 FUNCTIONS/METHODS

=cut

sub _get_mail_type {
    my $self = shift;
    
    return 'testfile';
    
}



1;