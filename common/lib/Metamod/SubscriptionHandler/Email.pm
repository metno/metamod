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
    my $body = $self->_get_email_body( $ds );
    
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
    my $subject = $self->_get_email_subject( $ds );    
    
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

    my $config = $self->{ _config };
    my $baseURL = $config->get('BASE_PART_OF_EXTERNAL_URL');
    my $localURL = $config->get('LOCAL_URL');
    my $fullURL = $baseURL . $localURL . "/sch/subscription?action=display_remove_subscription&dataset_name=$parentname";    
    
    if( !defined $dataref ){
        $self->{ _logger }->error('Trying to send email for a file without a dataref');
        return;
    }     
    
    my $email_body = <<END_BODY;
A new data file has just become available for the dataset $parentname

You can download it here: $dataref->[0]

If you wish to 
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
        $self->{ _logger }->error("Failed to send email: $!");
        return;
    } 
    
    return 1;
}

sub _get_mail_type {
    my $self = shift;
    
    return 'sendmail';
    
}

sub _get_email_subject {
    my $self = shift;
    
    my ( $ds ) = @_;

    my $parentname = $ds->getParentName();    
    
    my $email_text = $self->_read_email_template();
    
    my $subject;
    if( $email_text =~ /^Subject: (.*)$/mi ) {
        $subject = $1;
    } else {
        $subject = '[METAMOD] New file';
    }
    
    $subject =~ s/\[==DATASET_NAME==\]/$parentname/g;
    
    return $subject;
    
}

sub _get_email_body {
    my $self = shift;
    
    my ( $ds ) = @_;
    
    my %metadata = $ds->getMetadata();
    my $dataref = $metadata{ dataref };
    my $parentname = $ds->getParentName();

    my $config = $self->{ _config };
    my $base_url = $config->get('BASE_PART_OF_EXTERNAL_URL');
    my $local_url = $config->get('LOCAL_URL');
    my $cancel_url = $base_url . $local_url . "/sch/subscription?action=display_remove_subscription&dataset_name=$parentname";    
    my $file_url = $dataref->[0];
    
    if( !defined $dataref ){
        $self->{ _logger }->error('Trying to send email for a file without a dataref');
        return;
    }     
    
    my $email_body = $self->_read_email_template();

    #remove the subject line
    $email_body =~ s/^Subject:.*$//mi;
    
    #replace template variables
    $email_body =~ s/\[==DATASET_NAME==\]/$parentname/g;
    $email_body =~ s/\[==FILE_URL==\]/$file_url/g;
    $email_body =~ s/\[==CANCEL_URL==\]/$cancel_url/g;    

    return $email_body;    
}

sub _read_email_template {
    my $self = shift;

    if( exists $self->{ _email_template } ){
        return $self->{ _email_template };
    }
    
    my $config = $self->{ _config };
    my $target = $config->get( 'TARGET_DIRECTORY' );
        
    my $email_text;
    my $email_file = "$target/etc/subscription_email_template.txt";
    if( -e $email_file ){
        
        my $success = open my $FH, '<', $email_file;
        if( !$success ){
            $self->{ _logger }->warn( "Failed to open email template: $!" );
        } else {
            $email_text = do { local $/ = undef; <$FH> };
        }        
    } 
    
    # still no email text, then go for a default
    if( !$email_text ){
        $email_text = <<END_EMAIL;
Subject: [METAMOD] New dataset available for [==DATASET_NAME==]
A new data file has just become available for the dataset [==DATASET_NAME==]

You can download it here: [==FILE_URL==]

If you wish to cancel your subscription go to the following address: 

[==CANCEL_URL==]
END_EMAIL
       
    }
    $self->{ _logger }->debug( $email_text );
    $self->{ _email_template } = $email_text;
    
    return $email_text;
    
}

1;