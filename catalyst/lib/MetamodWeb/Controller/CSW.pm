package MetamodWeb::Controller::CSW;

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

=head1 NAME

MetamodWeb::Controller::CSW - Experimental OGC CSW server

=head1 DESCRIPTION

Trying to make a server for OpenGIS® Catalogue Services Specification version 2.0.2.

Simplifications...

over 4

=item *

only mandatory requirements are discussed

=item *

only HTTP key-value-pair (KVP) requests are discussed (no XML POST or SOAP requests)

=back

=cut

use Moose;
use namespace::autoclean;
use Data::Dumper;
use File::Spec;
use DateTime;
use MetamodWeb::Utils::XML::Generator;

BEGIN { extends 'MetamodWeb::BaseController::Base'; }

sub auto :Private {
    my ( $self, $c ) = @_;
}


=head1 METHODS

=head2 /csw

CSW server endpoint

=head3 Examples

  /csw?service=CSW&version=2.0.2&request=GetRecords&typeName=csw:Record&constraintlanguage=CQLTEXT&constraint="csw:AnyText Like '%pollution%'"

=head2 TODO

L<http://schemas.opengis.net/csw/2.0.2/record.xsd|validation>

L<http://www.ogcnetwork.net/system/files/csw-capabilities.xml.txt|GetCapabilities>

=cut

sub csw :Path("/csw") :ActionClass('REST') :Args(0) {
    my ( $self, $c ) = @_;
    $c->stash( template => 'search/transform.tt', 'current_view' => 'Raw' );
    $c->stash( debug => $self->logger->is_debug() );
    $c->stash( config => Metamod::Config->instance );

}

sub csw_GET {
    my ($self, $c) = @_;

    my $p = {}; # make param names case insensitive
    foreach (keys %{ $c->request->params }) {
        $p->{lc()} = $c->request->params->{$_};
    }

    $c->detach( 'Root', 'error', [ 400, "Only CSW service supported"  ] ) unless $$p{'service'} eq 'CSW';
    $c->detach( 'Root', 'error', [ 400, "Only version 2.0.2 supported"] ) unless $$p{'version'} eq '2.0.2';

    my $req = $p->{request} or die "Missing request";
    #print STDERR "************ REQ = $req\n";
    my $dom = $self->can($req) ? $self->$req($c, $p) : $self->_dump($c, $p); # FIXME make case insensitive

    $c->response->content_type('text/xml');
    $c->response->body( $dom->toString(1) );

}

sub csw_POST {
    my ($self, $c) = @_;
    $c->detach( 'Root', 'error', [ 501, "POST not yet implemented"  ] );
}

my $dom = new MetamodWeb::Utils::XML::Generator;

sub _dump {
    my ($self, $c, $p) = @_;
    my $dom = new MetamodWeb::Utils::XML::Generator;
    my (@params, %attr);
    $attr{method} = $c->request->method;
    foreach (sort keys %$p) {
        if (ref $$p{$_}) {
            for my $v (@{$$p{$_}}) {
                push @params, $dom->tag($_, $v);
            }
        } else {
            push @params, $dom->tag($_, $$p{$_});
        }
    }

    $dom->setDocumentElement(
        $dom->tag('request', \%attr, \@params )
    );
    return $dom;
}

my $cswNS = {
    service => "CSW",
    version => "2.0.2",
    'xmlns'     => "http://www.opengis.net/cat/csw/2.0.2",
    'xmlns:dc'  => "http://purl.org/dc/elements/1.1/",
    'xmlns:dct' => "http://purl.org/dc/terms/",
    'xmlns:gml' => "http://www.opengis.net/gml",
    'xmlns:gmd' => "http://www.isotc211.org/2005/gmd",
    'xmlns:ows' => "http://www.opengis.net/ows",
    'xmlns:ogc' => "http://www.opengis.net/ogc",
    'xmlns:xlink' => "http://www.w3.org/1999/xlink",
    'xmlns:xsi' => "http://www.w3.org/2001/XMLSchema-instance",
    outputFormat => "application/xml",
    schemaLanguage => "http://www.w3.org/2001/XMLSchema",
};

=head2 GetRecords operation (querying the catalog!)

The below example queries the catalog using a search for any occurence
of the string 'pollution' in any field. The service, version, and
request parameters are standard for an OGC service. The parameters that
make this a catalog search are constraintlanguage, which says the query
will be written in CQL, and constraint, which is the query (expressed in
CQL).

  http://ex.com/csw?service=CSW&version=2.0.2&request=GetRecords&typeName=csw:Record
	 &constraintlanguage=CQLTEXT&constraint="csw:AnyText Like '%pollution%'"

Since we're using all the defaults from CSW, we know that we'll be
returning csw:SummaryRecords (wrapped in a little extra CSW response
XML). Therefore, we know we could have specified any of the 10 core
queryables above for our search. The below example limits the query to
the title and subject fields.

  http://ex.com/csw?service=CSW&version=2.0.2&request=GetRecords&typeName=csw:Record
	 &constraintlanguage=CQLTEXT&constraint="dc:title OR dc:subject LIKE '%pollution%'"

=cut

sub GetRecords {
    my ($self, $c) = @_;

    my $schloc = { 'xsi:schemaLocation' => "http://www.opengis.net/cat/csw/2.0.2 ../../../csw/2.0.2/record.xsd" };
    my $root = $dom->tag('SummaryRecord', $cswNS, $schloc );
    $dom->setDocumentElement($root);
    $root->appendTextChild('dc:identifier', '00180e67-b7cf-40a3-861d-b3a09337b195');
    $root->appendTextChild('dc:abstract', 'IMAGE2000 product 1 individual orthorectified scenes. IMAGE2000 was  produced from ETM+ Landsat 7 satellite data and provides a consistent European coverage of individual orthorectified scenes in national map projection systems.');
    return $dom;
}

=head2 GetRecordById operation

This operation is a subset of the GetRecords operation, and is included
as a convenient short form for retrieving and linking to records in a
catalogue. The key parameter is Id, which is a comma-separated list of
anyURI, allowing you to request more than one record from the catalog.

    http://ex.com/csw?service=CSW&version=2.0.2&request=GetRecordById&Id=http://ex.com/2342343

This response will always be XML conforming to csw:SummaryRecord of MIME type application/xml.

=cut

sub GetRecordById {
    my ($self, $c, $p) = @_;

    # TODO - FIXME
    # Id must be URI (or dc:identifier? FGDC:System assigned identifier?)
    # Id can be multiple, split by comma

    my $ds_id = $p->{'id'} or $c->detach( 'Root', 'error', [ 400, 'Missing Id parameter'  ] );
    my $ds = $c->model('Metabase::Dataset')->find($ds_id);
    if( !defined $ds ){
        $self->logger->warn("Could not find dataset for ds_id '$ds_id'");
        $c->detach('Root', 'default' );
    }

    $dom->setDocumentElement(
        $dom->tag('SummaryRecord',
            { 'xsi:schemaLocation' => "http://www.opengis.net/cat/csw/2.0.2 ../../../csw/2.0.2/record.xsd" },
            $cswNS,
            _md2CSWelements($ds),
        )
    );
    return $dom;
}

=head2 GetCapabilities operation

The easiest way to implement the GetCapabilities operation is to create
an XML file in a text editor that has all the required information.
Here's an example of a basic capabilities document. The idea is to list
contact information, and describe the operations the catalog supports,
and what URLs to use to access those operations. You can also describe
advanced query capabilities in the <ogc:Filter_Capabilities> section.

=cut

sub GetCapabilities {
    my ($self, $c, $p) = @_;

    $dom->setDocumentElement(
        $dom->tag('Capabilities',
            { 'xsi:schemaLocation' => "http://www.opengis.net/cat/csw/2.0.2 ../../../csw/2.0.2/CSW-discovery.xsd" },
            $cswNS,
            [ $dom->tag('ows:ServiceIdentification',
                [ $dom->tag('ows:Title', 'METAMOD CSW Capabilities') ])
            ],
        )
    );
    return $dom;
}

=head2 DescribeRecord operation

The mandatory DescribeRecord operation allows a client to discover
elements of the information model supported by the target catalogue
service. The operation allows some or all of the information model to be
described. In this most basic CSW, that only supports csw:Record, the
request and response to DescribeRecord are always the same:

    http://ex.com/csw?service=CSW&version=2.0.2&request=DescribeRecord

=cut

sub DescribeRecord {
    my ($self, $c, $p) = @_;

    $dom->setDocumentElement(
        $dom->tag('DescribeRecord',
            { 'xsi:schemaLocation' => "http://www.opengis.net/cat/csw/2.0.2 ../../../csw/2.0.2/CSW-discovery.xsd" },
            $cswNS,
            [ $dom->tag('TypeName', 'csw:Record') ],
        )
    );
    return $dom;
}

sub _md2CSWelements {
    # TODO: sort elements in correct order according to schema
    my $ds = shift;
    my $md = $ds->metadata();

    my %CSWterm = (
        abstract    => 'dct:abstract',
        title       => 'dc:title',
        variable    => 'dc:subject',        # Accepted values are based on the ISO 19115 topic category codes
        topiccategory   => 'dc:subject',
        dataref     => 'dc:relation',
        file_format => 'format',
        format_description  => 'format',
    );
    my @nodes = (
        $dom->tag('dc:identifier', $ds->unqualified_ds_name ),
        $dom->tag('dc:type', 'dataset'),
    );

    foreach my $name (keys %$md) {
        foreach my $val (@{ $md->{$name}}) {
            next unless $val;
            if ($name eq 'bounding_box') {
                my @pts = split ',', $val; # ESWN
                my $lc = $dom->tag('ows:LowerCorner', $pts[2] . ' ' . $pts[1]);
                my $uc = $dom->tag('ows:UpperCorner', $pts[0] . ' ' . $pts[3]);
                push @nodes, $dom->tag('ows:WGS84BoundingBox', [$lc, $uc]);
            } else {
                $val =~ s/ > HIDDEN$//;
                my $term = $CSWterm{$name};
                push @nodes, $dom->tag($term, $val) if $term;
            }
        }
    }
    return \@nodes;
}

=Head1 Element Set

Returnables as defined per request:

Brief

    dc:identifier
    dc:title
    dc:type
    ows:Envelope

Summary

    dc:identifier
    dc:title
    dc:type
    dc:format
    ows:Envelope
    dc:subject
    dct:modified
    dc:abstract

Full

    dc:identifier
    dc:title
    dc:type
    ows:Envelope
    dc:subject
    dct:modified
    dc:abstract
    dct:references

=cut

=head1 AUTHOR

Geir Aalberg, E<lt>geira\@met.noE<gt>

=head1 SEE ALSO

L<http://www.ogcnetwork.net/node/630>

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

__PACKAGE__->meta->make_immutable;
