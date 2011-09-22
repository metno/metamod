package Metamod::OAI::DataProvider;

use strict;
use warnings;

use File::Spec;
use Log::Log4perl qw( get_logger );
use Moose;
use Try::Tiny;
use XML::LibXML;

use Metamod::Config;
use Metamod::DatasetTransformer::ToOAIDublinCore;
use Metamod::DBIxSchema::Metabase;
use Metamod::ForeignDataset;


=head1 NAME

Metamod::OAI::DataProvider - Data provider for OAI-PMH server

=head1 DESCRIPTION

This module provides a layer between the OAI-PMH server and the metadata
repository.

=head1 FUNCTIONS/METHODS

=cut

has 'config' => ( is => 'ro', isa => 'Metamod::Config', default => sub { Metamod::Config->instance() } );

has 'model' => ( is => 'ro', lazy => 1, builder => '_init_model' );

has 'logger' => ( is => 'ro', default => sub { get_logger(__PACKAGE__) } );

has 'metadata_formats' => ( is => 'ro', isa => 'HashRef', lazy => 1, builder => '_init_formats' );

has 'available_sets' => ( is => 'ro', isa => 'ArrayRef', lazy => 1, builder => '_init_available_sets' );

sub _init_model {
    my $self = shift;

    my $dns      = $self->config->getDSN();
    my $user     = $self->config->get('PG_WEB_USER');
    my $password = $self->config->get('PG_WEB_USER_PASSWORD');

    return Metamod::DBIxSchema::Metabase->connect( $dns, $user, $password, { pg_enable_utf8 => 1 } );
}

sub _init_formats {
    my $self = shift;

    my $formats = {
        'oai_dc'   => \&Metamod::DatasetTransformer::ToOAIDublinCore::foreignDataset2oai_dc,
        'dif'      => \&Metamod::DatasetTransformer::ToDIF::foreignDataset2Dif,
        'iso19115' => \&Metamod::DatasetTransformer::ToISO19115::foreignDataset2iso19115,

        # same as iso19115, but WIS prefers to call it 19139
        'iso19139' => \&Metamod::DatasetTransformer::ToISO19115::foreignDataset2iso19115,
    };
    return $formats;

}

sub _init_available_sets {
    my $self = shift;

    my $config_string = $self->config->get('PMH_SETCONFIG');

    if ( !$config_string ) {
        return [];
    }

    my @sets = ();
    my @lines = split( '\n', $config_string );
    foreach my $line (@lines) {
        my ( $set_spec, $set_name, $set_desc ) = split( '\|', $line );
        push @sets, { setSpec => $set_spec, setName => $set_name, setDescription => [$set_desc] };
    }

    return \@sets;
}

=head2 $self->supports_sets()

Check if the data repository supports sets.

=over

=item return

Returns 1 if the data repository supports sets. False otherwise.

=back

=cut
sub supports_sets {
    my $self = shift;

    my $available_sets = $self->available_sets();

    if( @$available_sets == 0 ){
        return;
    } else {
        return 1;
    }
}

=head2 $self->identifier_exists($identifier)

Check if a identifier exists in data repository.

=over

=item $identifier

The identifier to check.

=item return

Returns 1 if the identifier exists in the data repository. False otherwise.

=back

=cut
sub identifier_exists {
    my $self = shift;

    my ($identifier) = @_;

    my $base_resultset = $self->_base_resultset();
    my $dataset =
        $base_resultset->search( { 'oai_info.oai_identifier' => $identifier }, { join => 'oai_info' } )->first();

    if ( !defined $dataset ) {
        return;
    }

    return 1;

}

sub get_record {
    my $self = shift;

    my ( $identifier, $format ) = @_;

    my $base_resultset = $self->_base_resultset();
    my $dataset =
        $base_resultset->search( { 'oai_info.oai_identifier' => $identifier }, { join => 'oai_info' } )->first();

    if ( !defined $dataset ) {
        return;
    }

    my $record = $self->_oai_record( $identifier, $dataset, $format );
    return $record;
}

sub get_records {
    my $self = shift;

    my ( $format, $from, $until, $set, $resumption_token ) = @_;

    my $datasets = $self->_search_datasets( $from, $until, $set );

    my @records = ();
    while ( my $dataset = $datasets->next() ) {

        my $identifier = $dataset->oai_info()->first()->oai_identifier();
        my $record = $self->_oai_record( $identifier, $dataset, $format );
        push @records, $record;
    }

    return \@records;

}

sub get_identifiers {
    my $self = shift;

    my ( $format, $from, $until, $set, $resumption_token ) = @_;

    my $datasets = $self->_search_datasets( $from, $until, $set );

    my @identifiers = ();
    while ( my $dataset = $datasets->next() ) {

        my $oai_id = $dataset->oai_info()->first()->get_column('oai_identifier');
        my $record_header = $self->_oai_record_header( $oai_id, $dataset, $format );
        push @identifiers, $record_header;
    }

    return \@identifiers;

}

sub _convert_date {
    my $self = shift;

    my ($datestamp) = @_;

    my $datestring;
    if ( $datestamp =~ /(\d\d\d\d)-(\d\d)-(\d\d)\s(\d\d):(\d\d):(\d\d)/ ) {
        $datestring = "$1-$2-$3T$4:$5:$6Z";
    } else {
        die "Not correct format on datestamp: $datestamp";
    }

    return $datestring;

}

sub _oai_record {
    my $self = shift;

    my ( $identifier, $dataset, $format ) = @_;

    my $record = $self->_oai_record_header( $identifier, $dataset, $format );

    # status is only set when the record is marked as deleted. For deleted datasets
    # we do not include metadata
    if( !exists $record->{status} ){
        my $xml_dom = $self->_get_metadata( $dataset, $format );
        $record->{metadata} = $xml_dom;
    }

    return $record;

}

sub _oai_record_header {
    my $self = shift;

    my ( $identifier, $dataset, $format ) = @_;

    my $datestring = $self->_convert_date( $dataset->get_column('ds_datestamp') );

    my $record = {};
    $record->{identifier} = $identifier;
    $record->{datestamp}  = $datestring;

    if ( $dataset->ds_status() == 0 ) {
        $record->{status} = 'deleted';
    }

    if ( @{ $self->available_sets } > 0 ) {
        $record->{setSpec} = $dataset->ds_ownertag();
    }

    # If metadata validation is turned on we will mark all datasets with invalid
    # metadata as deleted.
    if( $self->config->get('PMH_VALIDATION') eq 'on' && $dataset->ds_status() != 0 ){
        my $xml_dom = $self->_get_metadata( $dataset, $format );
        my $success = $self->_validate_metadata($format, $xml_dom, $dataset);
        if(!$success) {
            $record->{status} = 'deleted';
        }
    }

    return $record;
}

sub _get_metadata {
    my $self = shift;

    my ( $dataset, $format ) = @_;

    my $ds = Metamod::ForeignDataset->newFromFile( $dataset->ds_filepath() );

    my $formats      = $self->metadata_formats();
    my $convert_func = $formats->{$format};

    my $converted = $convert_func->($ds);
    return $converted->getMETA_DOC();
}

sub _base_resultset {
    my $self = shift;

    my $model = $self->model();

    my $export_tags = $self->config->get('PMH_EXPORT_TAGS');

    my %conds = ();
    if ($export_tags) {

        my @export_tags = split /\s*,\s*/, $export_tags;

        # remove '' around tags
        @export_tags = map { s/^'//; s/'$//; $_ } @export_tags;

        $conds{'ds_ownertag'} = { IN => \@export_tags };
    }

    $conds{'ds_parent'} = 0;

    my $resultset = $model->resultset('Dataset')->search( \%conds );
    return $resultset;

}

sub _search_datasets {
    my $self = shift;

    my ( $from, $until, $sets ) = @_;

    my $base_resultset = $self->_base_resultset();

    my %conds = ();
    if ( $from && $until ) {
        $conds{ds_datestamp} = [ '-and' => { '>=' => $from }, { '<=' => $until } ];
    } elsif ($from) {
        $conds{ds_datestamp} = { '>=' => $from };
    } elsif ($until) {
        $conds{ds_datestamp} = { '<=' => $until };
    }

    my $datasets = $base_resultset->search( \%conds, { order_by => 'me.ds_id' } );
    return $datasets;
}

=head2 $self->_validate_metadata($format, $xml_dom)

Validate that the metadata follows a specific metadata format.

=over

=item $format

The name of the format to check the file against.

=item $xml_dom

A XML DOM object as returned by XML::LibXML.

=item $dataset

A DBIx::Class row object to the dataset.

=item return

Returns true if the metadata is valid or if no XSD file is registered for the
format. False if the format is not valid.

=back

=cut
sub _validate_metadata {
    my $self = shift;

    my ( $format, $xml_dom, $dataset ) = @_;

    my %schema_for_format = (
        dif    => '/schema/dif_v9.8.2.xsd',
        oai_dc => '/schema/oai_dc.xsd',
    );

    return 1 if !exists $schema_for_format{$format};

    my $schema = File::Spec->catfile( $self->config->get('INSTALLATION_DIR'), 'common', $schema_for_format{$format} );
    my $xsd_validator = XML::LibXML::Schema->new( location => $schema );

    my $success;
    my $error = try {
        $xsd_validator->validate($xml_dom);
        $success = 1;
    } catch {
        my $ds_name = $dataset->ds_name();
        $self->logger->warn("XML did not validate according to format '$format' for dataset '$ds_name': $_");
    };

    return $success;

}

__PACKAGE__->meta->make_immutable();
