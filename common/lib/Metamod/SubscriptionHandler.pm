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

=head2 new()

=cut

sub new {
    my $class = shift;

    my $self = bless {}, $class;
    $self->{_config} = Metamod::Config->new();
    $self->{_logger} = get_logger('metamod.subscription');

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

=head2 $self->_get_userbase()

=over

=item return

Returns a C<Metamod::mmUserbase> object if one can be created. If the object
cannot be created it returns C<undef>.

=back

=cut

sub _get_userbase {
    my $self = shift;

    if ( defined $self->{_userbase} ) {
        return $self->{_userbase};
    }

    my $userbase;
    eval { $userbase = Metamod::mmUserbase->new(); };
    if ($@) {
        $self->{_logger}->error( "Failed to connect to the user database:" . $@ );
        return;
    }

    $self->{_userbase} = $userbase;
    return $self->{_userbase};

}

sub DESTROY {
    my $self = shift;

    # cleanup the userbase object to avoid hanging connections
    if ( exists $self->{_userbase} && defined $self->{_userbase} ) {
        $self->{_userbase}->close();
    }

}

1;
