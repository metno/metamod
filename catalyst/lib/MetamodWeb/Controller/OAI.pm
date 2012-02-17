package MetamodWeb::Controller::OAI;

=begin LICENSE

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

=end LICENSE

=cut

use Moose;
use namespace::autoclean;

use Data::Dump qw(dump);
use HTTP::OAI;
use HTTP::OAI::Metadata::OAI_DC;
use HTTP::OAI::Repository qw( validate_request );
use XML::SAX::Writer;

use Metamod::Config;
use Metamod::OAI::DataProvider;
use Metamod::OAI::SetDescription;

BEGIN { extends 'MetamodWeb::BaseController::Base'; }

=head1 NAME

MetamodWeb::Controller::OAI - Controller that implements a OAI-PMH server.

=head1 DESCRIPTION

This module implements a OAI-PMH compatible server. For information on
OAI-PMH please take a look at the protocol specification.

=head1 METHODS

=cut

=head2 oai

This is the only entry point into the OAI-PMH compatible server. Different
actions are executed on the value of the 'verb' URL parameter.

Please see the OAI-PMH protocol specification for more details on the different
verbs and parameters.


=cut

sub oai : Path('/oai') : Args {
    my ( $self, $c ) = @_;

    my $params = $c->req->params();

    my @errors = validate_request(%$params);

    my $response;
    if (@errors) {
        $response = $errors[0];
    } else {

        if ( $params->{verb} eq 'GetRecord' ) {
            $response = $self->_get_record($c);
        } elsif ( $params->{verb} eq 'Identify' ) {
            $response = $self->_identify($c);
        } elsif ( $params->{verb} eq 'ListIdentifiers' ) {
            $response = $self->_list_identifiers($c);
        } elsif ( $params->{verb} eq 'ListMetadataFormats' ) {
            $response = $self->_list_metadata_formats($c);
        } elsif ( $params->{verb} eq 'ListRecords' ) {
            $response = $self->_list_records($c);
        } elsif ( $params->{verb} eq 'ListSets' ) {
            $response = $self->_list_sets($c);
        }
    }

    # errors need to be wrapped in a response object.
    if ( $response->isa('HTTP::OAI::Error') ) {
        my $new_response = HTTP::OAI::Response->new();
        $new_response->errors($response);
        $response = $new_response;
    }

    my $xml;
    my $writer = XML::SAX::Writer->new( Output => \$xml );
    $response->requestURL( $c->req->uri() );
    $response->set_handler($writer);
    $response->generate();

    $c->response->content_type('text/xml');
    $c->response->body($xml);
}

sub _list_identifiers {
    my ( $self, $c ) = @_;

    my $dataprovider = Metamod::OAI::DataProvider->new( model => $c->model('Metabase') );
    my $params = $c->req->params();

    my $metadata_prefix = $params->{metadataPrefix};
    my $formats         = $self->_formats();
    if ( !$params->{resumptionToken} && !exists $formats->{$metadata_prefix} ) {
        return HTTP::OAI::Error->new( code => 'cannotDisseminateFormat' );
    }
    if ( $params->{set} && !$dataprovider->supports_sets() ) {
        return HTTP::OAI::Error->new( code => 'noSetHierarchy' );
    }
    my ( $identifiers, $resumption_token ) = $dataprovider->get_identifiers( $params->{metadataPrefix},
        $params->{from}, $params->{until}, $params->{set}, $params->{resumptionToken} );

    if ( !defined $identifiers ) {
        return HTTP::OAI::Error->new( code => 'badResumptionToken' );
    }

    if ( @$identifiers == 0 ) {
        return HTTP::OAI::Error->new( code => 'noRecordsMatch' );
    }

    my $li = new HTTP::OAI::ListIdentifiers();
    foreach my $identifier (@$identifiers) {

        my $h = $self->_oai_header($identifier);
        $li->identifier($h);
    }

    if( defined $resumption_token ){
        my $rt = HTTP::OAI::ResumptionToken->new(
            resumptionToken => $resumption_token->{token_id},
            expirationDate => $resumption_token->{expiration_date},
            cursor => $resumption_token->{cursor},
            completeListSize => $resumption_token->{complete_list_size},
        );
        $li->resumptionToken($rt);
    }


    return $li;

}

sub _identify {
    my ( $self, $c ) = @_;

    my $config = Metamod::Config->instance();

    my $identify = new HTTP::OAI::Identify(
        baseURL           => $c->req->base() . $c->req->path(),
        adminEmail        => "mailto:" . $config->get('OPERATOR_EMAIL'),
        repositoryName    => $config->get('PMH_REPOSITORY_NAME'),
        protocolVersion   => '2.0',
        earliestDatestamp => $config->get('PMH_EARLIEST_DATESTAMP'),
        deletedRecord     => 'transient',
        granularity       => 'YYYY-MM-DDThh:mm:ssZ'
    );

    return $identify;

}

sub _list_metadata_formats {
    my ( $self, $c ) = shift;

    # we convert all metadata so identifier is ignored.
    my ($identifier) = @_;

    my $dataprovider = Metamod::OAI::DataProvider->new( model => $c->model('Metabase') );
    if ( !$dataprovider->identifier_exists($identifier) ) {
        return HTTP::OAI::Error->new( code => 'idDoesNotExist' );
    }

    my $formats = $self->_formats();

    my $lmf = HTTP::OAI::ListMetadataFormats->new();

    while ( my ( $key, $info ) = each %$formats ) {

        my $mf = HTTP::OAI::MetadataFormat->new();
        $mf->metadataPrefix($key);
        $mf->schema( $info->{schema} );
        $mf->metadataNamespace( $info->{metadataNamespace} );

        $lmf->metadataFormat($mf);
    }

    return $lmf;
}

sub _formats {
    my $self = shift;

    my %formats = (
        'oai_dc' => {
            'metadataPrefix'    => 'oai_dc',
            'schema'            => 'http://www.openarchives.org/OAI/2.0/oai_dc.xsd',
            'metadataNamespace' => 'http://www.openarchives.org/OAI/2.0/oai_dc/',
            'record_prefix'     => 'dc',
            'record_namespace'  => 'http://purl.org/dc/elements/1.1/'
        },
        'dif' => {
            'metadataPrefix'    => 'DIF',
            'schema'            => 'http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/dif.xsd',
            'metadataNamespace' => 'http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/',
            'record_namespace'  => '',
        },
        'iso19115' => {
            'metadataPrefix'    => 'gmd',
            'schema'            => 'http://www.isotc211.org/2005/gmd/gmd.xsd',
            'metadataNamespace' => 'http://www.isotc211.org/2005/gmd',
            'record_namespace'  => '',
        },

        # same as iso19115, but WIS prefers to call it 19139
        'iso19139' => {
            'metadataPrefix'    => 'gmd',
            'schema'            => 'http://www.isotc211.org/2005/gmd/gmd.xsd',
            'metadataNamespace' => 'http://www.isotc211.org/2005/gmd',
            'record_namespace'  => '',
        },
    );

    return \%formats;

}

sub _get_record {
    my ( $self, $c ) = @_;

    my $dataprovider = Metamod::OAI::DataProvider->new( model => $c->model('Metabase') );
    my $params = $c->req->params();

    my $metadata_prefix = $params->{metadataPrefix};
    my $formats         = $self->_formats();
    if ( !exists $formats->{$metadata_prefix} ) {
        return HTTP::OAI::Error->new( code => 'cannotDisseminateFormat' );
    }

    my $record = $dataprovider->get_record( $params->{metadataPrefix}, $params->{identifier} );
    if ( !defined $record ) {
        return HTTP::OAI::Error->new( code => 'idDoesNotExist' );
    }

    my $gr = HTTP::OAI::GetRecord->new();

    my $r = $self->_oai_record($record);
    $gr->record($r);

    return $gr;

}

sub _list_records {
    my ( $self, $c ) = @_;

    my $dataprovider = Metamod::OAI::DataProvider->new( model => $c->model('Metabase') );
    my $params = $c->req->params();

    my $metadata_prefix = $params->{metadataPrefix};
    my $formats         = $self->_formats();
    if ( !$params->{resumptionToken} && !exists $formats->{$metadata_prefix} ) {
        return HTTP::OAI::Error->new( code => 'cannotDisseminateFormat' );
    }

    if ( $params->{set} && !$dataprovider->supports_sets() ) {
        return HTTP::OAI::Error->new( code => 'noSetHierarchy' );
    }

    my ( $records, $resumption_token ) = $dataprovider->get_records( $params->{metadataPrefix},
        $params->{from}, $params->{until}, $params->{set}, $params->{resumptionToken} );

    if( !defined $records ){
        return HTTP::OAI::Error->new( code => 'badResumptionToken' );
    }

    if ( @$records == 0 ) {
        return HTTP::OAI::Error->new( code => 'noRecordsMatch' );
    }

    my $lr = new HTTP::OAI::ListRecords();

    foreach my $record (@$records) {
        my $r = $self->_oai_record($record);
        $lr->record($r);
    }

    if( defined $resumption_token ){
        my $rt = HTTP::OAI::ResumptionToken->new(
            resumptionToken => $resumption_token->{token_id},
            expirationDate => $resumption_token->{expiration_date},
            cursor => $resumption_token->{cursor},
            completeListSize => $resumption_token->{complete_list_size},
        );
        $lr->resumptionToken($rt);
    }

    return $lr;
}

sub _list_sets {
    my ( $self, $c ) = @_;

    my $dataprovider = Metamod::OAI::DataProvider->new( model => $c->model('Metabase') );

    if ( !$dataprovider->supports_sets() ) {
        return HTTP::OAI::Error->new( code => 'noSetHierarchy' );
    }

    my $sets = $dataprovider->available_sets();

    my $ls = HTTP::OAI::ListSets->new();
    foreach my $set (@$sets) {
        my $s = HTTP::OAI::Set->new();
        $s->setSpec( $set->{setSpec} );
        $s->setName( $set->{setName} );

        my $description_md = HTTP::OAI::Metadata::OAI_DC->new( dc => { description => $set->{setDescription} } );
        my $set_desc = Metamod::OAI::SetDescription->new( setDescription => [$description_md] );
        $s->setDescription($set_desc);
        $ls->set($s);
    }

    return $ls;

}

sub _oai_record {
    my $self = shift;

    my ($record) = @_;

    my $r      = HTTP::OAI::Record->new();
    my $header = $self->_oai_header($record);
    $r->header($header);

    if ( !exists $record->{status} ) {
        my $metadata = HTTP::OAI::Metadata->new( dom => $record->{metadata} );
        $r->metadata($metadata);
    }

    return $r;

}

sub _oai_header {
    my $self = shift;

    my ($record) = @_;

    my $header = HTTP::OAI::Header->new();
    $header->identifier( $record->{identifier} );
    $header->datestamp( $record->{datestamp} );
    $header->status( $record->{status} ) if exists $record->{status};

    $header->setSpec( $record->{setSpec} ) if exists $record->{setSpec};
    return $header;
}

sub old : Path('/pmh/oai2.php') : Args {
    # redirect old php version to new
    my ( $self, $c ) = @_;
    return $c->res->redirect( $c->uri_for( '/oai', $c->req->params ) );
}

__PACKAGE__->meta->make_immutable;

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
