#!/usr/bin/env perl

package Metamod::SubscriptionHandler::Email;

use base 'Metamod::SubscriptionHandler';

use strict;
use warnings;

use Mail::Mailer;
use Params::Validate qw( :all );

=head1 NAME

Metamod::SubscriptionHandler::Email - Subscription handler for email.

=head1 DESCRIPTION

This module implements a subscription handler that notifies subscribers over
email that a new file has become available. 

=head1 FUNCTIONS/METHODS

=cut


=head2 $self->push_to_subscribers( $ds, $subscribers )

See documentation in base class.

=cut
sub push_to_subscribers {
    my $self = shift;
    
    my ( $ds, $subscribers ) = validate_pos( @_, { isa => 'Metamod::Dataset' }, { type => ARRAYREF } );
    

    my $headers = $self->_generate_email_header( $ds, $subscribers );
    my $body = $self->_generate_email_body( $ds );
    
    return if !defined $body;
    
    my $success = $self->_send_email( $headers, $body );
    return $success;
    
}

sub _generate_email_header {
    my $self = shift;
    
    my ( $ds, $subscribers ) = @_;
    
    my $config = $self->{ _config };

    my @emails = map { $_->{ address } } @$subscribers;
    my $from_address = $config->get('FROM_ADDRESS') || 'metamod-subscription@met.no';
    my $parentname = $ds->getParentName();
    my $subject = "METAMOD: New dataset available for $parentname";    
    
    my %headers = (
        Bcc => join( ', ', @emails ),
        From => $from_address,
        Subject => $subject,
    );
    
    return \%headers;
    
    
    
}

sub _generate_email_body {
    my $self = shift;
    
    my ( $ds ) = @_;
    
    my %metadata = $ds->getMetadata();
    my $dataref = $metadata{ dataref };
    my $parentname = $ds->getParentName();
    
    if( !defined $dataref ){
        $self->{ _logger }->error('Trying to send email for a file without a dataref');
        return;
    }     
    
    my $email_body = <<END_BODY;
A new data file has just become available for the dataset $parentname

You can download it here: $dataref->[0]
END_BODY
    
}

sub _send_email {
    my $self = shift;
    
    my ( $email_header, $email_body ) = @_;
    my $mail_type = $self->_get_mail_type();
    
    my $mailer = Mail::Mailer->new( $mail_type );
    $mailer->open( $email_header );
    print $mailer $email_body;
    my $error = $mailer->close();
    
    if( $error ){
        $self->{ _logger }->error("Failed to send email: $error");
        return;
    } 
    
    return 1;
}

sub _get_mail_type {
    my $self = shift;
    
    return 'sendmail';
    
}

1;