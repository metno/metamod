package Metamod::Dataset;

use 5.6.0;
use strict;
use warnings;
use Fcntl qw(:DEFAULT :flock); # import LOCK_* constants
use POSIX qw();
use XML::LibXML();
use Metamod::DatasetTransformer;

our $VERSION = 0.2;

our $NamespaceDS = 'http://www.met.no/schema/metamod/dataset';
our $NamespaceMM2 = 'http://www.met.no/schema/metamod/MM2';


sub new {
    my ($class, %options) = @_;
    my $sDate = POSIX::strftime("%Y-%m-%dT%H:%M:%SZ", gmtime());
    my $dataDS =
'<?xml version="1.0" encoding="iso8859-1" ?>
<?xml-stylesheet href="dataset.xsl" type="text/xsl"?>
<dataset
   xmlns="http://www.met.no/schema/metamod/dataset"
   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
   xsi:schemaLocation="http://www.met.no/schema/metamod/dataset https://wiki.met.no/_media/metamod/dataset.xsd">
  <info name="" status="active" creationDate="'.$sDate.'" ownertag="" metadataFormat="MM2"/>
</dataset>';
	my $dataMM2 =
'<?xml version="1.0" encoding="iso8859-1"?>
<?xml-stylesheet href="MM2.xsl" type="text/xsl"?>
<MM2
   xmlns="http://www.met.no/schema/metamod/MM2"
   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
   xsi:schemaLocation="http://www.met.no/schema/metamod/MM2 https://wiki.met.no/_media/metamod/mm2.xsd">
</MM2>';
    my $parser = Metamod::DatasetTransformer->XMLParser;
    my $docDS = $parser->parse_string($dataDS);
    my $docMM2 = $parser->parse_string($dataMM2);
    return $class->_initSelf('MM2', $docDS, $docMM2);
}

sub newFromFile {
    my ($class, $basename, %options) = @_;
    my ($dsXML, $mm2XML) = Metamod::DatasetTransformer::getFileContent($basename);
    my @plugins = Metamod::DatasetTransformer::getPlugins();
    foreach my $plugin (@plugins) {
        my $p = $plugin->new($dsXML, $mm2XML, %options);
        if ($p->test) {
            my $format = $p->originalFormat;
            my ($docDS, $docMM2) = $p->transform;
            return $class->_initSelf($format, $docDS, $docMM2);
        }
    }
    return undef;
}

sub _initSelf {
    my ($class, $orgFormat, $docDS, $docMM2, %options) = @_;
    die "undefined docDS, cannot init\n" unless $docDS;
    die "undefined docMM2, cannot init\n" unless $docMM2;
    my $xpc = XML::LibXML::XPathContext->new();
    $xpc->registerNs('d', $NamespaceDS);
    $xpc->registerNs('m', $NamespaceMM2);
    my $self = {
                xpath => $xpc,
                docDS => $docDS,
                docMM2 => $docMM2,
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
    print $xmdF $self->getDS_XML;
    print $xmlF $self->getMM2_XML;
    close $xmlF;
    close $xmdF;
    
    return 1;
}

sub getDS_XML {
    my ($self) = @_;
    return $self->{docDS}->toString();
}

sub getMM2_XML {
    my ($self) = @_;
    return $self->{docMM2}->toString();
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
        my $qEl = $self->{docDS}->createElementNS($NamespaceDS,'quadtree_nodes');
        $qEl->appendChild($self->{docDS}->createTextNode($valStr));
        $self->{docDS}->documentElement->appendChild($qEl);
    }
    return @oldQuadtree;
}

sub getMetadata {
    my ($self) = @_;
    my %metadata;
    foreach my $n ($self->{xpath}->findnodes('/m:MM2/m:metadata', $self->{docMM2})) {
        my $value = "";
        foreach my $child ($n->childNodes) {
    		if ($child->nodeType == XML::LibXML::XML_TEXT_NODE) {
   				$value .= $child->nodeValue;
            }
        } 
        push @{ $metadata{$n->getAttribute("name")} }, $value;
    }
    return %metadata;
}

sub addMetadata {
    my ($self, $metaRef) = @_;
    foreach my $name (keys %$metaRef) {
        foreach my $val (@{ $metaRef->{$name} }) {
            my $el = $self->{docMM2}->createElementNS($NamespaceMM2, 'metadata');
            $el->setAttribute('name', $name);
            $el->appendChild($self->{docMM2}->createTextNode($val));
            $self->{docMM2}->documentElement->appendChild($el);
        }
    }
}

sub removeMetadata {
    my ($self) = @_;
    foreach my $n ($self->{xpath}->findnodes('/m:MM2/m:metadata', $self->{docMM2})) {
        $n->parentNode->removeChild($n);
    }
}

sub removeMetadataName {
    my ($self, $name) = @_;
    my @oldValues;
    foreach my $n ($self->{xpath}->findnodes('/m:MM2/m:metadata[@name=\''.$name."']", $self->{docMM2})) {
        my $value = "";
        foreach my $child ($n->childNodes) {
    		if ($child->nodeType == XML::LibXML::XML_TEXT_NODE) {
   				$value .= $child->nodeValue;
            }
        }
        push @oldValues, $value;
        $n->parentNode->removeChild($n);
    }
       
    return @oldValues;
}

1;
__END__

=head1 NAME

Metamod::Dataset - working with Metamod datasets

=head1 SYNOPSIS

  use Metamod::Dataset;
  
  # create a new dataset/mm2
  $ds = new Metamod::Dataset();
  %info = ('name' => 'NEW/Name',
              'ownertag' => 'DAM');
  $ds->setInfo(\%info);
  %metadata = ('datacollection_period_from' => '2008-11-05',
                  'abstract' => 'This is model data');
  $ds->addMetadata(\%metadata);
  # write the file to $basename.xml and $basename.xmd
  $ds->writeToFile($basename);
  
  # read an existing dataset from $basename.xml and $basename.xmd
  $ds = newFromFile Metamod::Dataset($basename);
  %info = $ds->getInfo;
  %metadata = $ds->getMetadata;
  @quadtreeNodes = $ds->getQuadtree;

=head1 DESCRIPTION

The Metamod::Dataset package give a convenient way to work with the xml-files describing
default datasets consisting of meta-metadata (dataset.xmd files) and metadata (MM2.xml) files.

=head1 FUNCTIONS

=over 4


=back

=head1 METHODS

These methods need to be implemented by the extending modules.

=over 4

=item new()

Create a new dataset. The creationDate-info will be set to currentDate, status-info is active, everything
else is empty

Return: $dataset object

=item newFromFile($basename)

read a dataset from a file. The file may or may not end with .xml or .xmd. The file will be read
through the L<Metamod::DatasetTransformer>. Thus, also other formats with a Transformer-Implementation
can be read.

Return: $dataset object

=item writeToFile($basename)

write the current content to $basename.xml and $basename.xmd (appendixes will be truncated). This might
overwrite an existing file! Dies on error.

=item getDS_XML

Return: xml-string of dataset

=item getMM2_XML

Return: xml-string of MM2

=item getInfo()

read the info elements (name, ownertag, status, metadataFormat, creationDate) from the dataset

Return: %info

=item setInfo(\%info)

add or overwrite info elements to the dataset

Return: undef

=item originalFormat()

Return: string describing the original format

=item getQuadtree()

Return: array with quadtree_nodes

=item setQuadtree(\@quadtree_nodes)

set the @quadtree_nodes as dataset-quadtree-nodes

Return: @oldQuadtree_nodes

=item getMetadata()

read the Metadata

Return; %metadata with ($name => [$val1, $val2, $val3, ...])

=item addMetadata(\%metadata)

add metadata from a hashref of the form ($name => [$val1, $val2, $val3, ...])

Return: undef

=item removeMetadata

remove all metadata

Return: undef

=item removeMetadataName($name)

remove all metadata with $name

Return: @values list of $name

=back

=head1 AUTHOR

Heiko Klein, E<lt>H.Klein@met.noE<gt>

=head1 SEE ALSO

L<XML::LibXML>, L<Metamod::DatasetTransformer>

=cut

