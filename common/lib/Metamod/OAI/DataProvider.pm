package Metamod::OAI::DataProvider;

use strict;
use warnings;

use Carp qw( confess );
use DateTime;
use DateTime::Format::Strptime;
use File::Spec;
use JSON;
use Log::Log4perl qw( get_logger );
use Moose;
use Params::Validate qw(:all);
use Try::Tiny;
use XML::LibXML;

use Metamod::Config;
use Metamod::DatasetTransformer::ToOAIDublinCore;
use Metamod::DBIxSchema::Metabase;
use Metamod::ForeignDataset;
use Metamod::Utils qw( random_string );


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

has 'resumption_token_dir' => ( is => 'ro', lazy => 1, builder => '_init_resumption_token_dir' );

has 'max_records' => ( is => 'ro', lazy => 1, default => sub { $_[0]->config->get('PMH_MAXRECORDS') || '1000' } );

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

sub _init_resumption_token_dir {
    my $self = shift;

    my $webrun = $self->config->get('WEBRUN_DIRECTORY');
    confess 'WEBRUN_DIRECTORY is required for using resumption tokens' if !$webrun;

    return File::Spec->catdir($webrun, 'resumption_tokens');
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

=head2 $self->get_record($identifier, $format)

Get a single record from the repository.

=over

=item $format

The format that the metadata for the record should be in.

=item $identifier

The OAI identifier for the record.

=item return

If the record is found it returns a hash reference with the keys 'identifier' and 'datestamp'. If the dataset has
been deleted or the metadata for the record is not valid it will also contain the key 'status'. If the dataset has
not been deleted and the metadata is valid it will contain the key 'metadata' with a XML DOM object as value.

If the record cannot be found it returns false.

=back

=cut

sub get_record {
    my $self = shift;

    my ( $format, $identifier ) = validate_pos( @_, 1, 1);

    my $base_resultset = $self->_base_resultset();
    my $dataset =
        $base_resultset->search( { 'oai_info.oai_identifier' => $identifier }, { join => 'oai_info' } )->first();

    if ( !defined $dataset ) {
        return;
    }

    my $record = $self->_oai_record( $identifier, $dataset, $format );
    return $record;
}

=head2 $self->get_records($format, $from, $until, $set, $resumption_token)

Get all the metadata records in the repository that match the specified
criteria.

=over

=item $format

The metadata format that should be used for the metadata.

=item $from

=item $until

=item $set

=item $resumption_token

=item return

=back

=cut

sub get_records {
    my $self = shift;

    my ( $format, $from, $until, $set, $token_id ) = @_;

    my ($datasets, $resumption_token) = $self->_search_datasets( $from, $until, $set, $token_id );

    return (undef, undef) if !defined $datasets;

    my @records = ();
    while ( my $dataset = $datasets->next() ) {

        my $identifier = $dataset->oai_info()->first()->oai_identifier();
        my $record = $self->_oai_record( $identifier, $dataset, $format );
        push @records, $record;
    }

    return (\@records, $resumption_token);

}

=head2 $self->get_identifiers($format, $from, $until, $set, $resumption_token)

Get a list of record headers without metadata that match the specified criteria.

=over

=item $format

=item $from

=item $until

=item $set

=item $resumption_token

=item return

=back

=cut

sub get_identifiers {
    my $self = shift;

    my ( $format, $from, $until, $set, $token_id ) = @_;

    my ($datasets, $resumption_token) = $self->_search_datasets( $from, $until, $set, $token_id );

    return (undef, undef) if !defined $datasets;

    my @identifiers = ();
    while ( my $dataset = $datasets->next() ) {

        my $oai_id = $dataset->oai_info()->first()->get_column('oai_identifier');
        my $record_header = $self->_oai_record_header( $oai_id, $dataset, $format );
        push @identifiers, $record_header;
    }

    return (\@identifiers, $resumption_token);

}

=head2 $self->_convert_date($datestamp)

Convert a datestamp into the format that is used by OAI-PMH.

=over

=item $datestamp

A datestamp string on the format YYYY-MM-DD HH:MM:SS

=item return

A datestamp string on the format YYYY-MM-DDTHH:MM:SSZ. Dies if the datestamp
argument does not have the correct format.

=back

=cut

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

=head2 $self->_oai_record($identifier, $dataset, $format)

Get the data from a dataset that is required for a OAI-PMH record.

=over

=item $identifier

The identifier of the record.

=item $dataset

A C<DBIx::Class> row object for the dataset.

=item $format

The metadata format for the dataset.

=item return

A hash reference representing the OAI-PMH record. The record has the keys
'identifier' and 'datestamp'. In addition it will have the key 'metadata' if
the dataset is not deleted and the metadata is valid (in the case of metadata
validation). If the dataset is deleted or it contains invalid metadata (in the
case of metadata validation) it will have the key 'status'.

=back

=cut

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

=head2 $self->_oai_record_header($identifier, $dataset, $format)

Get the data from a dataset that is required for building a OAI-PMH header.

=over

=item $identifier

The identifier of the record.

=item $dataset

A C<DBIx::Class> row object for the dataset.

=item $format

The metadata format for the dataset.

=item return

A hash reference representing the OAI-PMH header. The header has the keys
'identifier' and 'datestamp'. If the dataset is deleted or it contains invalid
metadata (in the case of metadata validation) it will have the key 'status'.

=back

=cut

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

=head2 $self->_get_metadata($dataset, $format)

Get the metadata for a dataset in the correct format.

=over

=item $dataset

A C<DBIx::Class> row object to the dataset.

=item $format

The format name as a string. This must be one of the format availble metadata
formats.

=item return

Returns the metadata in the correct XML format as a XML dom object. Dies if the
specified format is not among the list of supported formats.

=back

=cut

sub _get_metadata {
    my $self = shift;

    my ( $dataset, $format ) = @_;

    my $ds = Metamod::ForeignDataset->newFromFile( $dataset->ds_filepath() );

    my $formats = $self->metadata_formats();

    if( !exists $formats->{$format}){
        die "Invalid format '$format'. This should have been validated by the server.";
    }

    my $convert_func = $formats->{$format};

    my $converted = $convert_func->($ds);
    return $converted->getMETA_DOC();
}

=head2 $self->_base_resultset()

Get the base DBIx::Class results to use for searching. The reason we use a base
resultset instead of the dataset resultset directly is since only level 1
datasets are exported and depending on configuration only a subset of the level
1 datasets.

=over

=item return

A DBIx::Class resultset with the necessary filters in place.

=back

=cut

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

=head2 $self->_search_datasets($from, $until, $set)

Search the metadata repository for datasets that match the specified conditions.

=over

=item $from

A datestamp on the form 'YYYY-MM-DDTHH:MM:SST. Only datasets with a
ds_datestamp larger or equal to this is returned.

=item $until

A datestamp on the form 'YYYY-MM-DDTHH:MM:SST. Only datasets with a
ds_datestamp less or equal to this is returned.

=item $set

A string with a ownertag. Only datasets matching the ownertag is returned.

=item return

A DBIx::Class resultset with the correct conditions applied.

=back

=cut

sub _search_datasets {
    my $self = shift;

    my ( $from, $until, $set, $token_id ) = @_;

    if( !$self->supports_sets() && $set ){
        confess 'Cannot filter by sets when sets are not supported.';
    }

    my $base_resultset = $self->_base_resultset();

    my %conds = ();
    my %attrs = ( order_by => 'me.ds_id' );
    my $resumption_token;
    if( $token_id ){
        $resumption_token = $self->_get_resumption_token($token_id);

        # We have a invalid or expired resumption token.
        return (undef, undef) if !defined $resumption_token;

        $from = $resumption_token->{from};
        $until = $resumption_token->{until};
        $set = $resumption_token->{set};
    }

    if ( $from && $until ) {
        $conds{ds_datestamp} = [ '-and' => { '>=' => $from }, { '<=' => $until } ];
    } elsif ($from) {
        $conds{ds_datestamp} = { '>=' => $from };
    } elsif ($until) {
        $conds{ds_datestamp} = { '<=' => $until };
    }

    if( $set ) {
        $conds{ds_ownertag} = $set;
    }

    my $datasets_count = $base_resultset->search( \%conds )->count();
    my $max_records = $self->max_records();
    my $new_resumption_token;
    if( $datasets_count > $max_records ){
        $attrs{rows} = $max_records;
        my $offset = 0;

        if( defined $resumption_token ){
            $offset = $resumption_token->{cursor} + $max_records;
            $attrs{offset} = $offset;
        }

        $new_resumption_token = $self->_create_resumption_token($from, $until, $set, $offset, $datasets_count);
    }

    my $datasets = $base_resultset->search( \%conds, \%attrs );

    return ($datasets, $new_resumption_token);
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

sub _get_resumption_token {
    my $self = shift;

    my ($token_id) = @_;

    my $dir = $self->resumption_token_dir();
    my $token_file = $self->_token_file($token_id);

    # if the file does not exist it has like been cleaned or have never existed.
    # In either way OAI-PMH make no distinction between invalid and expired tokens.
    if( !-f $token_file ){
        return;
    }

    open my $TOKEN, '<', $token_file or confess "Failed to open token file '$token_file' for reading: $!";

    my $resumption_token = JSON->new()->decode(<$TOKEN>);

    my $now = DateTime->now;
    my $formatter = DateTime::Format::Strptime->new( pattern => '%Y-%m-%dT%H:%M:%SZ');
    my $expiration_date = $formatter->parse_datetime( $resumption_token->{expiration_date} );
    if( $now > $expiration_date ){
        return;
    }

    return $resumption_token;
}

sub _create_resumption_token {
    my $self = shift;

    my ($from, $until, $set, $cursor, $complete_list_size ) = @_;

    # for robustness we make the directory in case it does not exist already
    if( !-d $self->resumption_token_dir() ){
        mkdir $self->resumption_token_dir() or confess "Failed to create resumption token dir $!";
    }

    my $expire = DateTime->now();
    $expire->add( days => 1 );

    my $resumption_token = {
        from => $from,
        until => $until,
        set => $set,
        cursor => $cursor,
        complete_list_size => $complete_list_size,
        expiration_date => "${expire}Z", # stringify. DateTime does not add Z so we must do so ourselves
        token_id => undef,
    };

    # create a resumption token id and file if this is not the last
    # part of the list.
    if( $cursor + $self->max_records < $complete_list_size ){

        my $token_id = random_string();
        my $token_file = $self->_token_file($token_id);

        # prevent overwriting a file in the unlikely event of a collision
        while( -f $token_file ) {
            $token_id = random_string();
            $token_file = $self->_token_file($token_id);
        }

        $resumption_token->{token_id} = $token_id;

        my $json = JSON->new()->encode($resumption_token);
        open my $TOKEN, '>', $token_file or confess "Could not open token file '$token_file' for writing: $!";
        print $TOKEN $json;
        close $TOKEN;
    }

    return $resumption_token;
}

sub _token_file {
    my ($self, $token_id) = @_;

    return File::Spec->catfile($self->resumption_token_dir(), $token_id);
}

__PACKAGE__->meta->make_immutable();
