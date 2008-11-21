package Metamod::ForeignDataset;
our $VERSION = 0.2;


use strict;
use warnings;
use 5.6.0;
use strict;
use warnings;
use Fcntl qw(:DEFAULT :flock); # import LOCK_* constants
use POSIX qw();
use XML::LibXML();
use UNIVERSAL qw();

use constant NAMESPACE_DS => 'http://www.met.no/schema/metamod/dataset';
use constant DATASET => << 'EOT';
<?xml version="1.0" encoding="iso8859-1" ?>
<?xml-stylesheet href="dataset.xsl" type="text/xsl"?>
<dataset
   xmlns="http://www.met.no/schema/metamod/dataset"
   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
   xsi:schemaLocation="http://www.met.no/schema/metamod/dataset https://wiki.met.no/_media/metamod/dataset.xsd">
  <info name="" status="active" creationDate="1970-01-01T00:00:00Z" datestamp="1970-01-01T00:00:00Z" ownertag="" metadataFormat=""/>
</dataset>
EOT



sub newFromDoc {
    my ($class, $foreign, $dataset, %options) = @_;
    die "no metadata" unless $foreign;
    my $parser = Metamod::DatasetTransformer->XMLParser;
    unless ($dataset) {
        $dataset = $class->DATASET();
        my $sDate = POSIX::strftime("%Y-%m-%dT%H:%M:%SZ", gmtime());
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
    print $xmdF $self->getDS_XML;
    print $xmlF $self->getMETA_XML;
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
    my $info = $self->{xpath}->findnodes('/d:dataset/d:info', $self->{docDS})->item(0);
    while (my ($name, $val) = each %info) {
        $info->setAttribute($name, $val);
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

=head1 FUNCTIONS

=over 4


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

read the info elements (name, ownertag, status, metadataFormat, creationDate) from the dataset

Return: %info

=item setInfo(\%info)

add or overwrite info elements to the dataset

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

