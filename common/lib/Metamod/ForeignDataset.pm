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

package Metamod::ForeignDataset;
our $VERSION = do { my @r = (q$LastChangedRevision$ =~ /\d+/g); sprintf "0.%d", @r };

use strict;
use Data::Dumper;
use warnings;
use encoding 'utf-8';
use 5.6.0;
use strict;
use warnings;
use Encode;
use Fcntl qw(:DEFAULT :flock); # import LOCK_* constants
use POSIX qw();
use Metamod::DatasetImporter;
use Metamod::DatasetTransformer qw();
use Metamod::DatasetRegion qw();
use Metamod::Subscription;
use XML::LibXML::XPathContext qw();
use Log::Log4perl;
use UNIVERSAL qw();
use mmTtime;
use Carp qw(cluck);

use constant NAMESPACE_DS => 'http://www.met.no/schema/metamod/dataset';
use constant DATASET => << 'EOT';
<?xml version="1.0" encoding="utf-8" ?>
<dataset
   xmlns="http://www.met.no/schema/metamod/dataset"
   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
   xsi:schemaLocation="http://www.met.no/schema/metamod/dataset https://wiki.met.no/_media/metamod/dataset.xsd">
  <info name="/" status="active" creationDate="1970-01-01T00:00:00Z" datestamp="1970-01-01T00:00:00Z" ownertag="" metadataFormat=""/>
</dataset>
EOT
my $logger = Log::Log4perl::get_logger('metamod::common::'.__PACKAGE__);
my $nameReg = qr{^([^/]*)/([^/]*/)?([^/]*)$}; # project/[parent/]name where parent is optional

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

=begin deprecated

=item isXMLCharacter($str)

Check if the first character in $str is a valid xml-character as defined in http://www.w3.org/TR/REC-xml/#dt-character

=end deprecated

=item removeUndefinedXMLCharacters($str)

Remove all undefined xml characters as defined in http://www.w3.org/TR/REC-xml/#dt-character from the string.

Return: clean string in scalar context

=back

=head1 METHODS

These methods need to be implemented by the extending modules.

=cut

sub _decode {
    my ($self, $string) = @_;
    if (!Encode::is_utf8($string)) {
        $logger->debug("String not properly encoded, assuming utf8: $string");
        eval {$string = Encode::decode('utf8', $string, Encode::FB_CROAK);};
        if ($@) {
            $logger->warn("Unable to properly decode string: $string");
            $string = Encode::decode('utf8', $string);
        }
    }
    return $string;
}

=head2 newFromDoc($metaXML, [$xmdXML, %options])

Create a dataset from L<XML::LibXML::Document> or xml-string. The foreign-(metadata) document needs to be set. If $xmdXML is empty, new dataset information will be created.
In that case the creationDate-info will be set to currentDate, status-info is active, everything
else is empty.

Currently known options: 'format', this will set the originalFormat of the dataset.

Return: $xmdXML object
Dies on missing $metaXML, or on invalid xml-strings.

=cut

sub newFromDoc {
    my ($class, $metaXML, $xmdXML, %options) = @_;
    unless ($metaXML) {
        $logger->logconfess("no metadata");
    }
    my $parser = Metamod::DatasetTransformer->XMLParser;
    unless ($xmdXML) {
        $xmdXML = $class->DATASET();
        my $sDate = POSIX::strftime("%Y-%m-%dT%H:%M:%SZ", gmtime(mmTtime::ttime()));
        $xmdXML =~ s/\Q1970-01-01T00:00:00Z\E/$sDate/g; # changes datestamp and creationDate
    }
    my $docXMD = UNIVERSAL::isa($xmdXML, 'XML::LibXML::Document') ? $xmdXML : $parser->parse_string($xmdXML);
    my $docMETA = UNIVERSAL::isa($metaXML, 'XML::LibXML::Document') ? $metaXML : $parser->parse_string($metaXML);
    my $format = exists $options{format} ? delete $options{format} : 'unknown';
    return $class->_initSelf($format, $docXMD, $docMETA, %options);
}

=head2 newFromFile($basename)

read a dataset from a file. The file may or may not end with .xml or .xmd. The xml-file needs to exist.
The xml file is mapped to foreign and the xmd file is mapped to $xmdXML. See L<newFromDoc> for more information.

Return: $xmdXML object
Dies on missing xml-file, or on invalid xml-strings in xml or xmd files.

=cut

sub newFromFile {
    my ($class, $basename, %options) = @_;
    my ($xmdXML, $metaXML) = Metamod::DatasetTransformer::getFileContent($basename);
    return $class->newFromDoc($metaXML, $xmdXML, %options);
}

=head2 newFromFileAutocomplete($basename)

Read a dataset from a file. If only a .xml file is given without .xml file,
try to autdetect the DatasetTransformer plugin and let it generate the xmd information.

=cut

sub newFromFileAutocomplete {
    my ($class, $basename, %options) = @_;
    my ($xmdXML, $metaXML) = Metamod::DatasetTransformer::getFileContent($basename);
    my $retVal;
    if ($xmdXML) {
        # autocomplete not required
        $retVal = $class->newFromDoc($metaXML, $xmdXML, %options);
    } else {
        my $transformer = Metamod::DatasetTransformer::autodetect($basename);
        if ($transformer) {
            $logger->debug('autocompleting file with '.ref($transformer));
            my ($xmdDoc, $metaDoc) = $transformer->transform();
            $retVal = $class->newFromDoc($metaXML, $xmdDoc, %options);
        } else {
            $logger->error('cannot read/autocomplete file: '.$basename);
        }
    }
    return $retVal;
}

sub _initSelf {
    my ($class, $orgFormat, $docXMD, $docMETA, %options) = @_;
    die "undefined docXMD, cannot init\n" unless $docXMD;
    die "undefined docMETA, cannot init\n" unless $docMETA;
    my $xpc = XML::LibXML::XPathContext->new();
    $xpc->registerNs('d', $class->NAMESPACE_DS);
    $xpc->registerNs('r', Metamod::DatasetRegion->NAMESPACE_DSR);
    my $self = {
                xpath => $xpc,
                docXMD => $docXMD,
                docMETA => $docMETA,
                originalFormat => $orgFormat,
               };
                   # test correct xmd
    my $infoNodeList = $self->{xpath}->findnodes('/d:dataset/d:info', $self->{docXMD});
    if ($infoNodeList->size() != 1) {
        $logger->error_die("could not find /d:dataset/d:info in xmd ". $self->{docXMD}->toString);
    }

    return bless $self, $class;
}


=head2 writeToFile($basename)

write the current content to $basename.xml and $basename.xmd (appendixes will be truncated). This will
overwrite an existing file! Dies on error.

=cut

sub writeToFile {
    my ($self, $fileBase) = @_;

    $self->_writeToFileHelper($fileBase);
    my $success = eval { $self->_writeToDatabase($fileBase); };

    my $is_level_2 = (defined $self->getParentName()) ? 1 : undef;
    if( $success && $is_level_2 ){
        # We need a Metamod::Dataset version of the current dataset to get access to
        # the metadata.
        my $self_as_ds = Metamod::Dataset->newFromFile($fileBase);

        my $subscription = Metamod::Subscription->new();
        my $num_subscribers = $subscription->activate_subscription_handlers($self_as_ds);
    }

    return $success;
}

=head2 $self->_writeToFileHelper($fileBase)

Writes the dataset information to .xml and .xmd files.

B<IMPLEMTATION NOTE:> This has been separated as its own function to facilitate
unit testing of writing to file without involving the database.

=over

=item $fileBase

The base filename

=item return

Returns 1 on success. Throws and exception on failure.

=back

=cut

sub _writeToFileHelper {
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
    $self->{docXMD}->toFH($xmdF, 2);    # should pretty-print xml (not currently working)
    $self->{docMETA}->toFH($xmlF, 2);
    close $xmlF;
    close $xmdF;

    return 1;

}

=head2 $self->_writeToDatabase($filename)

Write the information in the dataset to the metabase database.

=over

=item $filename

The filename for this dataset.

=item return

=back

=cut

sub _writeToDatabase {
    my $self = shift;

    my ($filename) = @_;

    my $importer = Metamod::DatasetImporter->new();
    return $importer->write_to_database( $filename ); # dies on failure

}

=head2 deleteDatasetFile($basename)

delete the files belonging to the dataset $basename (.xml and .xmd).
Return false on failure, true on success.
This is a class rather than a object-method.

=cut

sub deleteDatasetFile {
     my ($self, $fileBase) = @_;
     $fileBase = Metamod::DatasetTransformer::getBasename($fileBase);
    my ($xmlF, $xmdF);
    # use sysopen, flock, truncate instead of open ">file" (see perlopentut)
    sysopen($xmdF, "$fileBase.xmd", O_WRONLY | O_CREAT) or die "cannot write $fileBase.xmd: $!\n";
    flock ($xmdF, LOCK_EX) or die "cannot lock $fileBase.xmd: $!\n";
    sysopen($xmlF, "$fileBase.xml", O_WRONLY | O_CREAT) or die "cannot write $fileBase.xml: $!\n";
    flock ($xmlF, LOCK_EX) or die "cannot lock $fileBase.xml: $!\n";

    my $err1 = unlink "$fileBase.xmd";
    my $err2 = unlink "$fileBase.xml";
    close $xmlF;
    close $xmdF;

    return $err1 && $err2;
}

=head2 getXMD_XML

Return: xml-string of xmd-file as byte stream

=cut

sub getXMD_XML {
    my ($self) = @_;
    return $self->{docXMD}->toString(1);
}

=head2 getMETA_XML

Return: xml-string of MM2 as byte stream in the original document encoding

=cut

sub getMETA_XML {
    my ($self) = @_;
    return $self->{docMETA}->toString(1);
}

=head2 getXMD_DOC

Get a clone of the internal xmd document.

Return: XML::LibXML::Document of dataset

=cut

sub getXMD_DOC {
    my ($self) = @_;
    my $doc = $self->{docXMD};
    my $out = new XML::LibXML::Document($doc->version, $doc->encoding);
    $out->setDocumentElement($doc->getDocumentElement->cloneNode(1));
    return $out;
}

=head2 getMETA_DOC

Get a clone of the internal metadata document.

Return: XML::LibXML::Document of the metadata

=cut

sub getMETA_DOC { # may return any data format
    my ($self) = @_;
    my $doc = $self->{docMETA};
    #cluck "getMETA called";
    #printf STDERR "%s\n%s\n%s\n", -1 x 33, $doc->toString, -1 x 33;
    my $out = new XML::LibXML::Document($doc->version, $doc->encoding);
    $out->setDocumentElement($doc->getDocumentElement->cloneNode(1));
    return $out;
}

=head2 getInfo()

read the info attributes (name, ownertag, status, metadataFormat, creationDate, datestamp) from the dataset

Return: %info

=cut

sub getInfo {
    my ($self) = @_;
    my %retVal;
    my $info = $self->{xpath}->findnodes('/d:dataset/d:info', $self->{docXMD})->item(0);
    foreach my $attr ($info->attributes) {
        $retVal{$attr->name} = $attr->value;
    }
    return %retVal;
}

=head2 setInfo(\%info)

add or overwrite info attributes to the dataset

Return: undef

=cut

sub setInfo {
    my ($self, $infoRef) = @_;
    my %info = ($self->getInfo, %$infoRef);
    return $self->replaceInfo(\%info);
}

=head2 replaceInfo(\%info)

replace all info attributes with those in %info. This will remove all attributes not in %info.

Return: undef

=cut

sub replaceInfo {
    my ($self, $infoRef) = @_;
    my %oldInfo = $self->getInfo;
    my %newInfo = %$infoRef;
    unless ($newInfo{name} and $newInfo{name} =~ /$nameReg/) {
        my $infoName = $newInfo{name} || 'undef';
        if ($infoName ne 'TESTFILE') {
           Carp::croak("Cannot set name to $infoName, need project/[parent/]filename");
        }
    }
    my $infoNode = $self->{xpath}->findnodes('/d:dataset/d:info', $self->{docXMD})->item(0);
    while (my ($name, $val) = each %oldInfo) {
        $infoNode->removeAttribute($self->_decode($name)) unless $newInfo{$name};
    }
    while (my ($name, $val) = each %newInfo) {
        $infoNode->setAttribute($self->_decode($name), $self->_decode($val));
    }
    return undef;
}

=head2 getParentName

The dataset-name can consist on 2 or 3 parts: project/parentname/filename or project/filename
In the first case, this method will return project/parentname in the second case undef.

=cut

sub getParentName {
    my ($self) = @_;
    my %info = $self->getInfo;
    if ($info{name} =~ /$nameReg/) {
        if ($2) {
            my $parent = substr $2, 0, length($2)-1; # remove trailing slash
            return join('/', $1, $parent);
        } else {
            return undef;
        }
    } else {
        Carp::croak("Cannot parse name to $info{name}, need project/[parent/]filename");
    }
}

=head2 originalFormat()

Return: string describing the original format as defined through 'newFromFile' or 'newFromDoc'. This does
not describe the originalFormat field in the info region of the .xmd file.

=cut

sub originalFormat {
    my ($self) = @_;
    return $self->{originalFormat};
}

# get the last node before the named one
# this function is useful to use $node->insertAfter
# this works for all nodes in dataset, except the first and required 'info'
sub _getLastNodeBefore {
    my ($self, $nodeName) = @_;
    my @datasetSequenceOrder = qw(d:info d:quadtree_nodes d:wmsInfo d:projectionInfo r:datasetRegion);
    my $i = 0;
    my %seqOrder = map {$_ => $i++} @datasetSequenceOrder;
    unless (exists $seqOrder{$nodeName}) {
        croak("function not defind for $nodeName, need @datasetSequenceOrder\n");
    }
    foreach my $lastNodeName (reverse @datasetSequenceOrder) {
        # go reverse and return the first existing node with appears at or before the $nodeName
        if ($seqOrder{$lastNodeName} <= $seqOrder{$nodeName}) {
            my @lastNodesBefore = $self->{xpath}->findnodes("/d:dataset/$lastNodeName", $self->{docXMD});
            if (@lastNodesBefore) {
                return $lastNodesBefore[-1];
            }
        }
    }
    return undef;
}

=head2 getQuadtree()

Return: array with quadtree_nodes

=cut

sub getQuadtree {
    my ($self) = @_;
    my @retVal;
    my ($q) = $self->{xpath}->findnodes('/d:dataset/d:quadtree_nodes', $self->{docXMD});
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

=head2 setQuadtree(\@quadtree_nodes)

set the @quadtree_nodes as dataset-quadtree-nodes

Return: @oldQuadtree_nodes

=cut

sub setQuadtree {
    my ($self, $quadRef) = @_;
    my @oldQuadtree = $self->getQuadtree;
    foreach my $node ($self->{xpath}->findnodes('/d:dataset/d:quadtree_nodes', $self->{docXMD})) {
        # remove old value
        $node->parentNode->removeChild($node);
    }
    if (@$quadRef > 0) {
        # create node with new content
        my $valStr = join "\n", @$quadRef;
        my $qEl = $self->{docXMD}->createElementNS($self->NAMESPACE_DS,'quadtree_nodes');
        $qEl->appendChild($self->{docXMD}->createTextNode($valStr));
        $self->{docXMD}->documentElement->insertAfter($qEl, $self->_getLastNodeBefore('d:quadtree_nodes'));
    }
    return @oldQuadtree;
}

=head2 getWMSInfo()

Return: raw-xml content of the WMSInfo node

=cut

sub getWMSInfo {
    my ($self) = @_;
    my ($node) = $self->{xpath}->findnodes('/d:dataset/d:wmsInfo/*[1]', $self->{docXMD}) or return;
    my $doc = XML::LibXML->createDocument( "1.0", "UTF-8" );
    $doc->setDocumentElement( $node->cloneNode(1) );
    #printf STDERR "***************\n%s***************\n", $doc->toString;
    return $doc->toString;
}

=head2 setWMSInfo($wmsInfo)

set/replace the raw-xml WMSInfo node.

Return: old WMSInfo

Throws: Exception if $wmsInfo is not valid

=cut

sub setWMSInfo {
    my ($self, $content) = @_;
    my $oldContent = $self->getWMSInfo;
    foreach my $node ($self->{xpath}->findnodes('/d:dataset/d:wmsInfo', $self->{docXMD})) {
    # remove old value
    $node->parentNode->removeChild($node);
    }
    if ($content) {
    # create node with new content
    my $el = $self->{docXMD}->createElementNS($self->NAMESPACE_DS, 'wmsInfo');
    my $parser = Metamod::DatasetTransformer->XMLParser;
    my $contentDoc = $parser->parse_string($content);
    $el->appendChild($contentDoc->documentElement);

    # add content to doc, before optional projectionInfo
        $self->{docXMD}->documentElement->insertAfter($el, $self->_getLastNodeBefore('d:wmsInfo'));
    }
    return $oldContent;
}

=head2 getProjectionInfo()

Return: raw content of the ProjectionInfo node

=cut

sub getProjectionInfo {
    my ($self) = @_;
    my $retVal;
    my ($node) = $self->{xpath}->findnodes('/d:dataset/d:projectionInfo/*[1]', $self->{docXMD}) or return;
    my $doc = XML::LibXML->createDocument( "1.0", "UTF-8" );
    $doc->setDocumentElement( $node->cloneNode(1) );
    #printf STDERR "***************\n%s***************\n", $doc->toString;
    return $doc->toString;
}

=head2 setProjectionInfo($projectionInfo)

set/replace the raw ProjectionInfo node

Return: old ProjectionInfo

Throws: Exception if $projectionInfo is not valid

=cut

sub setProjectionInfo {
    my ($self, $content) = @_;
    my $oldContent = $self->getProjectionInfo;
    foreach my $node ($self->{xpath}->findnodes('/d:dataset/d:projectionInfo', $self->{docXMD})) {
        # remove old value
        $node->parentNode->removeChild($node);
    }
    if ($content) {
        # create node with new content
        my $el = $self->{docXMD}->createElementNS($self->NAMESPACE_DS, 'projectionInfo');
        my $parser = Metamod::DatasetTransformer->XMLParser;
        my $contentDoc = $parser->parse_string($content);
        $el->appendChild($contentDoc->documentElement);

        # add element to doc
        $self->{docXMD}->documentElement->insertAfter($el, $self->_getLastNodeBefore('d:projectionInfo'));
    }
    return $oldContent;
}

=head2 getDatasetRegion()

Return: a Metamod::DatasetRegion

Warning: this is a copy of the region, when changing, a call to setDatasetRegion is required

=cut


sub getDatasetRegion {
    my ($self) = @_;
    my ($node) = $self->{xpath}->findnodes('/d:dataset/r:datasetRegion', $self->{docXMD});
    return new Metamod::DatasetRegion($node);
}

=head2 deleteDatasetRegion()

Return: the old region

=cut

sub deleteDatasetRegion {
    my ($self) = @_;
    my $oldRegion = $self->getDatasetRegion;
    foreach my $node ($self->{xpath}->findnodes('/d:dataset/r:datasetRegion', $self->{docXMD})) {
        # remove old value
        $node->parentNode->removeChild($node);
    }
    return $oldRegion;
}

=head2 setDatasetRegion($region)

set the Metamod::DatasetRegion to a new region.

=cut

sub setDatasetRegion {
    my ($self, $dsRegion) = @_;
    my $oldRegion = $self->deleteDatasetRegion;
    if ($dsRegion) {
        croak("setDatasetRegion require Metamod::DatasetRegion, got $dsRegion")
            unless UNIVERSAL::isa($dsRegion, 'Metamod::DatasetRegion');
        my $regionXML = $dsRegion->toString;
        my $regionDoc = Metamod::DatasetTransformer->XMLParser->parse_string($regionXML);
        my $rNode = $regionDoc->documentElement;
        # add element to doc
        $self->{docXMD}->documentElement->insertAfter($rNode, $self->_getLastNodeBefore('r:datasetRegion'));
    }
    return $oldRegion;
}

=begin deprecated
sub isXMLCharacter {
    # see http://www.w3.org/TR/REC-xml/#dt-character
    # Char       ::=       #x9 | #xA | #xD | [#x20-#xD7FF] | [#xE000-#xFFFD] | [#x10000-#x10FFFF]
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
=end deprecated
=cut

sub removeUndefinedXMLCharacters {
    my ($str) = @_;
    # see http://www.w3.org/TR/REC-xml/#dt-character
    # Char     ::=      #x9 | #xA | #xD | [#x20-#xD7FF] | [#xE000-#xFFFD] | [#x10000-#x10FFFF]
    $str =~ s/[^\x09\x0A\x0D\x20-\x{D7FF}\x{E000}-\x{FFFD}\x{10000}-\x{10FFFF}]//go;
    return $str;
}

1;

__END__

=head1 AUTHOR

Heiko Klein, E<lt>H.Klein@met.noE<gt>

=head1 SEE ALSO

L<XML::LibXML>, L<Metamod::Dataset>

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut
