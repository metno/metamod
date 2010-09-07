#!/usr/bin/env perl

package Metamod::Subscription;

use strict;
use warnings;

use Log::Log4perl qw( get_logger );
use XML::LibXML;

use Metamod::SubscriptionHandler::Email;
use Metamod::SubscriptionHandler::SMS;
use Metamod::SubscriptionUtils qw( split_parent_name );
use Metamod::mmUserbase;

=head1 NAME

Metamod::Subscription - API for handling push subscriptions to new datasets

=head1 DESCRIPTION

Metamod::Subscription implements the API used for notifying subscribers that a
new file is availabe in a dataset.

The subscriptions are stored in the METAMOD user database and it is the
responsibility of this module to check if there are any subscriptions that
match a new file.

=head1 FUNCTIONS/METHODS

=cut

sub new {
    my $class = shift;

    my $self = bless {}, $class;

    $self->{_logger} = get_logger('metamod.subscription');

    my $parser = XML::LibXML->new();
    $self->{_parser} = $parser;

    my $config        = Metamod::Config->new();
    my $schema_file   = $config->get("SOURCE_DIRECTORY") . '/common/schema/subscription.xsd';
    my $xsd_validator = XML::LibXML::Schema->new( location => $schema_file );
    $self->{_xsd_validator} = $xsd_validator;

    return $self;

}

=head2 $self->activate_subscription_handlers( $ds )

Find all subscriptions to the dataset and activate the corresponding
subscription handler for pushing the new file to the subscribers.

=over

=item $ds

A reference to a L<Metamod::Dataset> object.

=item return

Returns the number of subscriptions to the dataset on success. If an error is encountered it returns C<undef>.

=back

=cut

sub activate_subscription_handlers {
    my $self = shift;

    my ($ds) = validate_pos( @_, { isa => 'Metamod::ForeignDataset' } );

    my $subscriptions = $self->_get_subscriptions($ds);
    if ( !defined $subscriptions ) {
        return;
    }

    my $num_subscriptions = 0;
    while ( my ( $type, $subs ) = each %$subscriptions ) {
        my $handler = $self->_get_subscription_handler($type);
        if( !defined $handler ){
            $self->{ _logger }->error("Handler is not defined for type '$type'");
            next;
        }
        
        my $error = $handler->push_to_subscribers( $ds, $subs );
        if ($error) {
            $self->{_logger}->error("Failed to push to subscribers for type '$type': $error");
        } else {
            $num_subscriptions += scalar @$subs;
        }
    }

    return $num_subscriptions;
}

sub _parse_subscription_xml {
    my ( $self, $xml_string ) = @_;

    my $parser = $self->{_parser};

    my $dom;
    eval { $dom = $parser->parse_string($xml_string); };

    if ($@) {
        $self->{_logger}->error("Failed to parse '$xml_string': $@");
        return;
    }

    my $xsd_validator = $self->{_xsd_validator};
    eval { $xsd_validator->validate($dom); };

    if ($@) {
        $self->{_logger}->error("The following subscription XML was not valid: $xml_string \nGot error: $@.");
        return;
    }

    my $xpc = XML::LibXML::XPathContext->new( $dom->documentElement() );
    $xpc->registerNs( 's', "http://www.met.no/schema/metamod/subscription" );

    my %subs_info = ();

    my @subs = $xpc->findnodes('/s:subscription');
    my $sub  = $subs[0];
    $subs_info{type} = $sub->getAttribute('type');

    foreach ( $xpc->findnodes('/*/s:param') ) {
        $subs_info{ $_->getAttribute('name') } = $_->getAttribute('value');
    }

    return \%subs_info;

}

=head2 $self->_get_subscriptions( $ds )

Get all the subscriptions for the specific dataset.

=over

=item $ds

A reference to a dataset object.

=item return

Returns a hash reference with subscription type as key and a list of hashreferences as values. 
Each hash reference contains information about a single subscription.

On error the method returns C<undef>.

=back

=cut

sub _get_subscriptions {
    my $self = shift;

    my ($ds) = @_;

    my ( $applic_id, $ds_name ) = split_parent_name( $ds->getParentName() );

    my $userbase;
    eval { $userbase = Metamod::mmUserbase->new(); };

    if ($@) {
        $self->{_logger}->error( 'Failed to connect to the user database: ' . $@ );
        return;
    }

    my $dataset_found = $userbase->dset_find( $applic_id, $ds_name );

    if ( !$dataset_found ) {
        $self->{_logger}->debug("No dataset for '$applic_id' and '$ds_name' in the user database");
        return {};
    }

    my $num_subscriptions = $userbase->infoUDS_set( 'SUBSCRIPTION_XML', 'DATASET' );
    if ( !$num_subscriptions ) {
        $self->{_logger}->debug("Found no subscriptions for the dataset '$applic_id', '$ds_name'");
        return {};
    }

    # hash of subscriptions. Subscription types are used as key and the values are references to a list of hash
    # references with subscription info
    my %subscriptions = ();

    do {
        my $sub_xml = $userbase->infoUDS_get();

        my $sub_info = $self->_parse_subscription_xml($sub_xml);

        next if !defined $sub_info;

        # get the U_id of the user that own the subscription
        my $success = $userbase->user_isync();
        if ( !$success ) {
            $self->{_logger}->error("Failed to sync user to information. Skipping subscription.");
            next;
        }
        $sub_info->{U_email} = $userbase->user_get('u_email');

        # get the type information and remove as it is no longer for the subscription info
        my $type = delete $sub_info->{type};
        $subscriptions{$type} = [] if !exists $subscriptions{$type};

        push @{ $subscriptions{$type} }, $sub_info;

    } while ( $userbase->infoUDS_next() );

    return \%subscriptions;
}

sub _get_subscription_handler {
    my ( $self, $type ) = @_;

    # This could probably be a bit more fancy, but since there currently are so few alternatives
    # we go the simple route instead
    if ( 'email' eq $type ) {
        return Metamod::SubscriptionHandler::Email->new();
    } elsif ( 'sms' eq $type ) {
        return Metamod::SubscriptionHandler::SMS->new();
    } elsif ( 'emailtofile' eq $type ) {
        return Metamod::SubscriptionHandler::EmailToFile->new();
    } else {
        return;
    }

}

1;
