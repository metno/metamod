#----------------------------------------------------------------------------
#  METAMOD - Web portal for metadata search and upload
#
#  Copyright (C) 2008 met.no
#
#  Contact information:
#  Norwegian Meteorological Institute
#  Box 43 Blindern
#  0313 OSLO
#  NORWAY
#  email: Heiko.Klein@met.no
#
#  This file is part of METAMOD
#
#  METAMOD is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  METAMOD is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with METAMOD; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#----------------------------------------------------------------------------
package Metamod::ForeignDataset;
our $VERSION = 0.4;

our $DEBUG = 0;

use strict;
use warnings;
use encoding 'utf-8';
use 5.6.0;
use strict;
use warnings;
use Encode;
use Fcntl qw(:DEFAULT :flock); # import LOCK_* constants
use POSIX qw();
use XML::LibXML qw();
use XML::LibXML::XPathContext qw();
use UNIVERSAL qw();
use mmTtime;

use constant NAMESPACE_DS => 'http://www.met.no/schema/metamod/dataset';
use constant DATASET => << 'EOT';
<?xml version="1.0" encoding="utf-8" ?>
<dataset
   xmlns="http://www.met.no/schema/metamod/dataset"
   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
   xsi:schemaLocation="http://www.met.no/schema/metamod/dataset https://wiki.met.no/_media/metamod/dataset.xsd">
  <info name="" status="active" creationDate="1970-01-01T00:00:00Z" datestamp="1970-01-01T00:00:00Z" ownertag="" metadataFormat=""/>
</dataset>
EOT

sub _decode {
	my ($self, $string) = @_;
	if (!Encode::is_utf8($string)) {
		print STDERR "String not properly encoded, assuming utf8: $string\n" if $DEBUG;
        eval {$string = Encode::decode('utf8', $string, Encode::FB_CROAK);};
        if ($@) {
        	print STDERR "Unable to properly decode string: $string\n";
        	$string = Encode::decode('utf8', $string);
        }
	}
	return $string;
}

sub newFromDoc {
    my ($class, $foreign, $dataset, %options) = @_;
    die "no metadata" unless $foreign;
    my $parser = Metamod::DatasetTransformer->XMLParser;
    unless ($dataset) {
        $dataset = $class->DATASET();
        my $sDate = POSIX::strftime("%Y-%m-%dT%H:%M:%SZ", gmtime(mmTtime::ttime()));
        $dataset =~ s/\Q1970-01-01T00:00:00Z\E/$sDate/g; # changes datestamp and creationDate
    }
    my $docDS = UNIVERSAL::isa($dataset, 'XML::LibXML::Document') ? $dataset : $parser->parse_string($dataset);
    my $docMETA = UNIVERSAL::isa($foreign, 'XML::LibXML::Document') ? $foreign : $parser->parse_string($foreign);
    my $format = exists $options{format} ? delete $options{format} : 'unknown';
    return $class->_initSelf($format, $docDS, $docMETA, %options);
}

sub newFromFile {
    my ($class, $basename, %options) = @_;
    my ($dsXML, $metaXML) = Metamod::DatasetTransformer::getFileContent($basename);
    return $class->newFromDoc($metaXML, $dsXML, %options);
}

sub _initSelf {
    my ($class, $orgFormat, $docDS, $docMETA, %options) = @_;
    die "undefined docDS, cannot init\n" unless $docDS;
    die "undefined docMETA, cannot init\n" unless $docMETA;
    my $xpc = XML::LibXML::XPathContext->new();
    $xpc->registerNs('d', $class->NAMESPACE_DS);
    my $self = {
                xpath => $xpc,
                docDS => $docDS,
                docMETA => $docMETA,
                originalFormat => $orgFormat,
               };
    return bless $self, $class;
}


sub writeToFile {
    my ($self, $fileBase) = @_;
    $fileBase = Metamod::DatasetTransformer::getBasename($fileBase);

    my ($xmlF, $xmdF);
    # use sysopen, flock, truncate instead of open ">file" (see perlopentut)
    sysopen($xmdF, "$fileBase.xmd", O_WRONLY | O_CREAT) or die "cannot write $fileBase.xmd: $!\n";
    flock ($xmdF, LOCK_EX) or die "cannot lock $fileBase.xmd: $!\n";
    sysopen($xmlF, "$fileBase.xml", O_WRONLY | O_CREAT) or die "cannot write $fileBase.xml: $!\n";
    flock ($xmlF, LOCK_EX) or die "cannot lock $fileBase.xml: $!\n";
    truncate($xmdF, 0) or die "can't truncate $fileBase.xmd: $!\n";
    truncate($xmlF, 0) or die "can't truncate $fileBase.xml: $!\n";
    binmode $xmdF; # drop all PerlIO layers possibly created by a use open pragma
    binmode $xmlF;
    # use libxml to write the file, avoid any interference by perl (possible character conversion)
    $self->{docDS}->toFH($xmdF, 1);
    $self->{docMETA}->toFH($xmlF, 1);
    close $xmlF;
    close $xmdF;
    
    return 1;
}

sub getDS_XML {
    my ($self) = @_;
    return $self->{docDS}->toString(1);
}

sub getMETA_XML {
    my ($self) = @_;
    return $self->{docMETA}->toString(1);
}

sub getDS_DOC {
    my ($self) = @_;
    my $doc = $self->{docDS};
    my $out = new XML::LibXML::Document($doc->version, $doc->encoding);
    $out->setDocumentElement($doc->getDocumentElement->cloneNode(1));
    return $out;
}

sub getMETA_DOC {
    my ($self) = @_;
    my $doc = $self->{docMETA};
    my $out = new XML::LibXML::Document($doc->version, $doc->encoding);
    $out->setDocumentElement($doc->getDocumentElement->cloneNode(1));
    return $out;
}



sub getInfo {
    my ($self) = @_;
    my %retVal;
    my $info = $self->{xpath}->findnodes('/d:dataset/d:info', $self->{docDS})->item(0);
    foreach my $attr ($info->attributes) {
        $retVal{$attr->name} = $attr->value;
    }
    return %retVal;
}

sub setInfo {
    my ($self, $infoRef) = @_;
    my %info = ($self->getInfo, %$infoRef);
    return $self->replaceInfo($infoRef);
}

sub replaceInfo {
    my ($self, $infoRef) = @_;
    my %oldInfo = $self->getInfo;
    my %newInfo = %$infoRef;
    my $infoNode = $self->{xpath}->findnodes('/d:dataset/d:info', $self->{docDS})->item(0);
    while (my ($name, $val) = each %oldInfo) {
        $infoNode->removeAttribute($self->_decode($name)) unless $newInfo{$name};
    }
    while (my ($name, $val) = each %newInfo) {
        $infoNode->setAttribute($self->_decode($name), $self->_decode($val));
    }
    return undef;
}

sub originalFormat {
    my ($self) = @_;
    return $self->{originalFormat};
}

sub getQuadtree {
    my ($self) = @_;
    my @retVal;
    my ($q) = $self->{xpath}->findnodes('/d:dataset/d:quadtree_nodes', $self->{docDS});
    if ($q) {
        foreach my $child ($q->childNodes) {
            if ($child->nodeType == XML::LibXML::XML_TEXT_NODE) {
                push @retVal, split ' ', $child->nodeValue;
            }
        }
    }
    @retVal = map {s/^\s+//; s/\s+$//; $_;} @retVal; # trim
    return @retVal;
}

sub setQuadtree {
    my ($self, $quadRef) = @_;
    my @oldQuadtree = $self->getQuadtree;
    foreach my $node ($self->{xpath}->findnodes('/d:dataset/d:quadtree_nodes', $self->{docDS})) {
        # remove old value
        $node->parentNode->removeChild($node);
    }
    if (@$quadRef > 0) {
        my $valStr = join "\n", @$quadRef;
        my $qEl = $self->{docDS}->createElementNS($self->NAMESPACE_DS,'quadtree_nodes');
        $qEl->appendChild($self->{docDS}->createTextNode($valStr));
        $self->{docDS}->documentElement->appendChild($qEl);
    }
    return @oldQuadtree;
}

sub isXMLCharacter {
    # see http://www.w3.org/TR/REC-xml/#dt-character
    # Char	   ::=   	#x9 | #xA | #xD | [#x20-#xD7FF] | [#xE000-#xFFFD] | [#x10000-#x10FFFF]
    my $ic = ord($_[0]);
    my $retVal = 0;
    if ($ic == 0x9 || $ic == 0xA || $ic == 0xD) {
        $retVal = 1;
    } elsif ($ic >= 0x20 and $ic <=0xD7FF) {
        $retVal = 1;
    } elsif ($ic >= 0xE000 and $ic <= 0xFFFD) {
        $retVal = 1;
    } elsif ($ic >= 0x10000 and $ic <= 0x10ffff) {
        $retVal = 1;
    } else {
        $retVal = 0;
    }
    return $retVal;
}

sub removeUndefinedXMLCharacters {
    my ($str) = @_;
    for (my $i = 0; $i < length($str); $i++) {
        if (!isXMLCharacter(substr($str, $i, 1))) {
            # remove character
            $str = substr($str, 0, $i) . substr($str, $i+1);
            $i--;
        }
    }
    return $str;
}

1;
__END__

=head1 NAME

Metamod::ForeignDataset - working with Metamod datasets without known Metadata

=head1 SYNOPSIS

  use Metamod::ForeignDataset;
  
  # create a new dataset/mm2
  $ds = new Metamod::ForeignDataset('<DIF></DIF>');
  %info = ('name' => 'NEW/Name',
              'ownertag' => 'DAM');
  $ds->setInfo(\%info);
  
  # read an existing dataset from $basename.xml and $basename.xmd
  $ds = newFromFile Metamod::ForeignDataset($basename);
  %info = $ds->getInfo;
  @quadtreeNodes = $ds->getQuadtree;

=head1 DESCRIPTION

The Metamod::ForeignDataset package give a convenient way to work with the xml-files describing
default datasets consisting of meta-metadata (dataset.xmd files) and metadata (file.xml) files or
strings. The metadata-file is not modified, except for content-invariant changes through the xml-parser/writer.

XML::LibXML requires properly encoded utf-8 strings as input, with
perl utf8-flag switched on. Please make sure to provide such data by:

=over 4

=item use Encode; and decode all data with decode('charset', $string);

=item use encoding 'utf-8'; To set non-binary input-files annd all literals ('name') to utf8

=back

=head1 FUNCTIONS

=over 4

=item isXMLCharacter($str)

Check if the first character in $str is a valid xml-character as defined in http://www.w3.org/TR/REC-xml/#dt-character

=item removeUndefinedXMLCharacters($str)

Remove all undefined xml characters from the string.
Return: clean string in scalar context

=back

=head1 METHODS

These methods need to be implemented by the extending modules.

=over 4

=item newFromDoc($foreign, [$dataset, %options])

Create a dataset from L<XML::LibXML::Document> or xml-string. The foreign-(metadata) document needs to be set. If $dataset is empty, new dataset information will be created.
In that case the creationDate-info will be set to currentDate, status-info is active, everything
else is empty.

Currently known options: 'format', this will set the originalFormat of the dataset.

Return: $dataset object
Dies on missing $foreign, or on invalid xml-strings.

=item newFromFile($basename)

read a dataset from a file. The file may or may not end with .xml or .xmd. The xml-file needs to exist.
The xml file is mapped to foreign and the xmd file is mapped to $dataset. See L<newFromDoc> for more information.

Return: $dataset object
Dies on missing xml-file, or on invalid xml-strings in xml or xmd files.

=item writeToFile($basename)

write the current content to $basename.xml and $basename.xmd (appendixes will be truncated). This will
overwrite an existing file! Dies on error.

=item getDS_XML

Return: xml-string of dataset as byte stream in the original document encoding

=item getMETA_XML

Return: xml-string of MM2 as byte stream in the original document encoding

=item getDS_DOC

Get a clone of the internal metadata document.

Return: XML::LibXML::Document of dataset

=item getMETA_DOC

Get a clone of the internal metadata document.

Return: XML::LibXML::Document of the metadata


=item getInfo()

read the info attributes (name, ownertag, status, metadataFormat, creationDate) from the dataset

Return: %info

=item setInfo(\%info)

add or overwrite info attributes to the dataset

Return: undef

=item replaceInfo(\%info)

replace all info attributes with those in %info. This will remove all attributes not in %info.

Return: undef


=item originalFormat()

Return: string describing the original format as defined through 'newFromFile' or 'newFromDoc'. This does
not describe the originalFormat field in the info region of the .xmd file.

=item getQuadtree()

Return: array with quadtree_nodes

=item setQuadtree(\@quadtree_nodes)

set the @quadtree_nodes as dataset-quadtree-nodes

Return: @oldQuadtree_nodes

=back

=head1 AUTHOR

Heiko Klein, E<lt>H.Klein@met.noE<gt>

=head1 SEE ALSO

L<XML::LibXML>, L<Metamod::Dataset>

=cut

