=begin licence

----------------------------------------------------------------------------
METAMOD - Web portal for metadata search and upload

Copyright (C) 2013 met.no

Contact information:
Norwegian Meteorological Institute
Box 43 Blindern
0313 OSLO
NORWAY
email: geira@met.no

This file is part of METAMOD

METAMOD is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

METAMOD is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with METAMOD; if not, write to the Free Software
Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
----------------------------------------------------------------------------

=end licence

=cut

=head1 NAME

Metamod::OAI::DataProvider - Data provider for OAI-PMH server

=head1 DESCRIPTION

This module provides a layer between the OAI-PMH server and the metadata
repository.

=head1 FUNCTIONS/METHODS

=cut

package Metamod::OAI::DataProvider;

use strict;
use warnings;

use Carp qw( confess );
use Data::Dumper;
use Capture::Tiny ':all';
use DateTime;
use DateTime::Format::Strptime;
use File::Spec;
use File::Temp qw();
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

has 'config' => ( is => 'ro', isa => 'Metamod::Config', default => sub { Metamod::Config->instance() } );

has 'model' => ( is => 'ro', lazy => 1, builder => '_init_model' );

has 'logger' => ( is => 'ro', default => sub { get_logger('metamod::oai') } );

has 'metadata_formats' => ( is => 'ro', isa => 'HashRef', lazy => 1, builder => '_init_formats' );

has 'available_sets' => ( is => 'ro', isa => 'ArrayRef', lazy => 1, builder => '_init_available_sets' );

has 'tags_to_sets' => ( is => 'ro', isa => 'HashRef', lazy => 1, builder => '_init_tags_to_sets' );

has 'resumption_token_dir' => ( is => 'ro', lazy => 1, builder => '_init_resumption_token_dir' );

has 'max_records' => ( is => 'ro', lazy => 1, default => sub { $_[0]->config->get('PMH_MAXRECORDS') || '1000' } );

has 'debug' => ( is => 'ro' );

sub _init_model {
    my $self = shift;

    my $dns      = $self->config->getDSN();
    my $user     = $self->config->get('PG_WEB_USER');
    my $password = $self->config->has('PG_WEB_USER_PASSWORD') ? $self->config->get('PG_WEB_USER_PASSWORD') : '';

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
        my ( $set_spec, $dataset_tags, $set_name, $set_desc ) = split( '\|', $line );
        $set_spec =~ s/^\s*//;
        push @sets, { setSpec => $set_spec, datasetTags => $dataset_tags, setName => $set_name, setDescription => [$set_desc] };
    }

    return \@sets;
}

sub _init_tags_to_sets {
    my $self = shift;

    my $config_string = $self->config->get('PMH_SETCONFIG');

    if ( !$config_string ) {
        return {};
    }

    my %tags = ();
    my @lines = split( '\n', $config_string );
    foreach my $line (@lines) {
        my ( $set_spec, $dataset_tags, $set_name, $set_desc ) = split( '\|', $line );
        $set_spec =~ s/^\s*//;
        my @tgarr = split(/\s+/,$dataset_tags);
        foreach my $tg (@tgarr) {
            if (exists($tags{$tg})) {
                push @{$tags{$tg}}, $set_spec;
            } else {
                $tags{$tg} = [$set_spec];
            }
        }
    }

    return \%tags;
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
    #print STDERR Dumper $available_sets;

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
        my $record = $self->_oai_record( $identifier, $dataset, $format, $set );
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
    if( !exists $record->{status} || $record->{status} ne 'deleted'){
        try {
            my $xml_dom = $self->_get_metadata( $dataset, $format );
            $record->{metadata} = $xml_dom;
            #delete $record->{status};
        } catch {
            $self->logger->error("This should never have occured: $_");
        };
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
    #$self->logger->debug( '_oai_record_header:', $identifier, ' ', $dataset, ' ', $format );

    my $datestring = $self->_convert_date( $dataset->get_column('ds_datestamp') );

    my $record = {};
    $record->{identifier} = $identifier;
    $record->{datestamp}  = $datestring;

    if ( $dataset->ds_status() == 0 ) {
        $record->{status} = 'deleted';
    }

    my %set_specs = %{ $self->tags_to_sets };
    my $ownertag = $dataset->ds_ownertag();
    if (exists($set_specs{$ownertag})) {
        my @specarr = @{$set_specs{$ownertag}};
        $record->{setSpec} = @specarr == 1 ? $specarr[0] : \@specarr;
    }

    # If metadata validation is turned on we will mark all datasets with invalid
    # metadata as deleted.
    if( $self->config->is('PMH_VALIDATION') && ( $dataset->ds_status() != 0 ) ) {
        my ($xml, $xml_dom);
        try {
            $xml_dom = $self->_get_metadata( $dataset, $format );
            $xml = $xml_dom->toString(1) or die "Missing DOM... file unparsable?";
            $self->_validate_metadata($format, $xml_dom, $dataset);
        } catch {
            $record->{status} = $self->debug ? $_ : 'deleted';
            #$record->{error} = $_;
            $self->logger->warn("Document is not valid $format: $_");
            #$self->logger->debug($xml) if defined $xml;
        };
    }

    return $record;
}

=head2 $self->_get_metadata($dataset, $format)

Get the metadata for a dataset in the correct format. Must be eval-ed

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

    my $file = $dataset->ds_filepath();

    die "OAI: XML file $file not found" unless -e "$file.xml";

    my $ds = Metamod::ForeignDataset->newFromFile( $dataset->ds_filepath() );

    my $formats = $self->metadata_formats();

    if( ! exists $formats->{$format} ){
        die "Invalid format '$format'. This should have been validated by the server.";
    }

    my $convert_func = $formats->{$format};

    my $converted = $convert_func->($ds);
    my $dom = $converted->getMETA_DOC();
    #$self->logger->debug( "DataProvider::_get_metadata( ", $dataset->ds_id(), ", $format ) ", substr( $dom->toString(2), 0, 130 ), '...' );

    return $dom;
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

A setSpec string identifying a set. Only datasets with ownertag in the
datasetTags list defined for the set is returned.

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
        my $available_sets = $self->available_sets();
        foreach my $s1 (@$available_sets) {
            if ($s1->{setSpec} eq $set) {
                my @tgarr = split(/\s+/,$s1->{datasetTags});
                $conds{'ds_ownertag'} = { IN => \@tgarr };
                last;
            }
        }
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
format. Dies if the document is not valid.

=back

=cut

sub _validate_metadata {
    my $self = shift;

    my ( $format, $xml_dom, $dataset ) = @_;

    # consider using specific DIF schema version based on /DIF/Metadata_Version if not backwards compatible

    my %schema_for_format = (
#        dif      => '/schema/dif_v9.8.2.xsd',
        dif      => '/schema/dif.xsd', # always use latest version
        oai_dc   => '/schema/oai_dc.xsd', # doesn't seem to have been updated since 2002
        iso19115 => '/schema/iso19139/gmd/gmd.xsd',
        iso19139 => '/schema/iso19139/gmd/gmd.xsd',
    );

    return 1 if !exists $schema_for_format{$format};

    my $schema = File::Spec->catfile( $self->config->get('INSTALLATION_DIR'), 'common', $schema_for_format{$format} );

    my $ext_validators = $self->config->split('PMH_LOCAL_VALIDATION');
    my $ds_name = $dataset->ds_name();

    #my $error = try {
    try {

        if (my $cmd = $ext_validators->{$format}) { # use custom validator
            return 1 if $cmd eq '-';
            my $tmpfile = File::Temp->new(TEMPLATE => 'oaiXXXXXX', SUFFIX => '.xml');
            $xml_dom->toFH($tmpfile) or die "Could not write temporary OAI file";
            $cmd =~ s/\[SCHEMA\]/$schema/;
            $cmd =~ s/\[FILE\]/$tmpfile/;
            $self->logger->debug("Validating $cmd");
            my $exit;
            my $shell_err = capture_merged {
                $exit = system($cmd);
            };
            if ($exit != 0) {
                $self->logger->error($shell_err);
                die "External validator failed";
            }

        } else { # use ordinary schema
            my $xsd_validator = XML::LibXML::Schema->new( location => $schema );
            $xsd_validator->validate($xml_dom);
        }
        $self->logger->debug("OAI XML document $ds_name in $format format validated successfully");
        return 1;

    } catch {
        die ("XML did not validate according to format '$format' for dataset '$ds_name': $_");
        #return;
    };

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

=head1 AUTHOR

Øystein Torget, E<lt>oysteint@met.noE<gt>

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut
