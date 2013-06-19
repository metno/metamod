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

package Metamod::MMD;
#package Metamod::DatasetTransformer::MMD; # problems with questionnaire
#use base qw(Metamod::DatasetTransformer);

=head1 NAME

Metamod::MMD - transform between MM2 and MMD formats

=head1 SYNOPSIS

  my $doc = Metamod::MMD->new($mm2file);
  my $doc = Metamod::MMD->new($xmlstring);
  my $doc = Metamod::MMD->new($filehandle);
  my $doc = Metamod::MMD->new($DOM_object);
  my $mmd = $doc->mmd;
  print $mmd->toString(1);

  my $doc = Metamod::MMD->new($mmdfile);
  my $mm2 = $doc->mm2;

=head1 DESCRIPTION

The MMD format is the new metadata format for METAMOD and other met.no systems, designed
for better intercompatibility between data formats and a richer vocabulary. Designed to
be used in conjunction with the met.no Metadata Editor available at L<https://github.com/metno/metadata-editor>.

=head1 FUNCTIONS

=cut


use strict;
use warnings;

use XML::LibXML;
use XML::LibXML::XPathContext;
use XML::LibXSLT;
use Const::Fast;

const my $mm2ns => 'http://www.met.no/schema/metamod/MM2';
const my $mmdns => 'http://www.met.no/schema/mmd';

use Metamod::Config;
use Metamod::DatasetTransformer;

my $xslt = XML::LibXSLT->new();

__PACKAGE__->run(@ARGV) unless caller();

=head2 $doc = Metamod::MMD->new($xml)

Generate a new object from the XML file given. Acceptable paramater forms are:

=over 4

=item *

filename string

=item *

ref to XML::LibXML::Document object

=item *

ref to filehandle

=item *

XML string

=back

=cut

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    my $param = shift or die "Missing input document param";

    if (ref $param) {
        if (ref $param eq 'XML::LibXML::Document') {
            print STDERR "Processing DOM object...\n";
            $$self{'dom'} = $param;
        } elsif (ref $param eq 'GLOB') {
            print STDERR "Processing filehandle ...\n";
            $$self{'dom'} = XML::LibXML->load_xml( IO => $param ) or die "Cannot parse XML filehandle";
        }
    } else {
        if ( $param =~ /^<\?xml/ ) {
            print STDERR "Processing XML string ...\n";
            $$self{'dom'} = XML::LibXML->load_xml( string => $param ) or die "Cannot parse XML string";
        } else {
            $$self{'filename'} = $param;
            print STDERR "Processing $$self{'filename'} ...\n";
            $$self{'dom'} = XML::LibXML->load_xml( location => $$self{'filename'} ) or die "Cannot parse XML file " . $$self{'filename'};
        }
    }

    $$self{'format'} = $$self{'dom'}->documentElement->namespaceURI;
    $$self{'schemadir'} = Metamod::DatasetTransformer::xslt_dir();
    print STDERR "Format is $$self{'format'}\n";
    return $self;
}

=head2 $doc->mmd

Transform document to new MMD format

=cut

sub mmd {
    my $self = shift or die;
    return $$self{'dom'} if $$self{'format'} eq $mmdns;
    my $style_doc = XML::LibXML->load_xml( location => $$self{'schemadir'}.'mm2-to-mmd.xsl', no_cdata => 1 ) or die "Missing or invalid XSL stylesheet";
    my $stylesheet = $xslt->parse_stylesheet($style_doc);
    my $result = $stylesheet->transform( $$self{'dom'} );
    #print STDERR $result->toString(1);
    my $xmlschema = XML::LibXML::Schema->new( location => $$self{'schemadir'}.'mmd.xsd' );
    eval { $xmlschema->validate($result); } or die $@;
    return $result;
}

=head2 $doc->mm2

Transform document to old MM2 format

=cut

sub mm2 {
    my $self = shift or die;
    return $$self{'dom'} if $$self{'format'} eq $mm2ns;
    my $style_doc = XML::LibXML->load_xml( location => $$self{'schemadir'}.'mmd-to-mm2.xsl', no_cdata => 1) or die "Missing or invalid XSL stylesheet";
    my $stylesheet = $xslt->parse_stylesheet($style_doc);
    my $result = $stylesheet->transform( $$self{'dom'} );
    #print STDERR $result->toString(1);
    return $result;
}

=head2 run

Run tests from command line

=cut

sub run {
    my $self = shift;
    my $file = shift @ARGV;
    if ($file) {
        test($file);
    } else {
        print STDERR "Usage: perl $0 <xmlfile>\n";
    }
}

sub test {
    my $file = shift or die;
    my $config = Metamod::Config->new(); # to avoid "you must call new() once before you can call instance()"
    my $doc = Metamod::MMD->new($file);
    my $mmd = $doc->mmd;
    print $mmd->toString(1);
    my $doc2 = Metamod::MMD->new($mmd);
    my $mm2 = $doc2->mm2;
    print $mm2->toString(1);
}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
