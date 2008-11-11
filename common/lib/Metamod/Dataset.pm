package Metamod::Dataset;
use base qw(Metamod::ForeignDataset);

use strict;
use warnings;
use Metamod::DatasetTransformer;
use Metamod::DatasetTransformer::MM2;

our $VERSION = 0.3;

use constant NAMESPACE_MM2 => 'http://www.met.no/schema/metamod/MM2';
use constant MM2 => <<'EOT';
<?xml version="1.0" encoding="iso8859-1"?>
<?xml-stylesheet href="MM2.xsl" type="text/xsl"?>
<MM2
   xmlns="http://www.met.no/schema/metamod/MM2"
   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
   xsi:schemaLocation="http://www.met.no/schema/metamod/MM2 https://wiki.met.no/_media/metamod/mm2.xsd">
</MM2>
EOT
sub new {
    my ($class, %options) = @_;
    my $sDate = POSIX::strftime("%Y-%m-%dT%H:%M:%SZ", gmtime());
    my $dataDS = $class->DATASET;
    $dataDS =~ s/\Q1970-01-01T00:00:00Z\E/$sDate/g;
    $dataDS =~ s/metadataFormat=""/metadataFormat="MM2"/g;
	my $dataMM2 = $class->MM2;
    return $class->newFromDoc($dataMM2, $dataDS, %options);
}

sub newFromDoc {
    my ($class, $foreign, $dataset, %options) = @_;
    die "no metadata" unless $foreign;
    unless ($dataset) {
        my $sDate = POSIX::strftime("%Y-%m-%dT%H:%M:%SZ", gmtime());
        my $dataset = $class->DATASET;
        $dataset =~ s/\Q1970-01-01T00:00:00Z\E/$sDate/g;
        $dataset =~ s/metadataFormat=""/metadataFormat="MM2"/g;
    }
    my $parser = Metamod::DatasetTransformer->XMLParser;
    my $docDS = UNIVERSAL::isa($dataset, 'XML::LibXML::Node') ? $dataset : $parser->parse_string($dataset);
    my $docMETA = UNIVERSAL::isa($foreign, 'XML::LibXML::Node') ? $foreign : $parser->parse_string($foreign);
    my $mdmm2 = new Metamod::DatasetTransformer::MM2($docDS, $docMETA, %options);
    die "not MM2 metadata" unless $mdmm2->test;
    return $class->_initSelf('MM2', $docDS, $docMETA, %options);
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
    my ($class, @args) = @_;
    my $self = $class->SUPER::_initSelf(@args);
    $self->{xpath}->registerNs('m', $self->NAMESPACE_MM2);
    return $self;
}

sub getMetadata {
    my ($self) = @_;
    my %metadata;
    foreach my $n ($self->{xpath}->findnodes('/m:MM2/m:metadata', $self->{docMETA})) {
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
            my $el = $self->{docMETA}->createElementNS($self->NAMESPACE_MM2, 'metadata');
            $el->setAttribute('name', $name);
            $el->appendChild($self->{docMETA}->createTextNode($val));
            $self->{docMETA}->documentElement->appendChild($el);
        }
    }
}

sub removeMetadata {
    my ($self) = @_;
    foreach my $n ($self->{xpath}->findnodes('/m:MM2/m:metadata', $self->{docMETA})) {
        $n->parentNode->removeChild($n);
    }
}

sub removeMetadataName {
    my ($self, $name) = @_;
    my @oldValues;
    foreach my $n ($self->{xpath}->findnodes('/m:MM2/m:metadata[@name=\''.$name."']", $self->{docMETA})) {
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

sub getMM2_XML {
    my ($self) = @_;
    return $self->getMETA_XML;
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
The Metamod::Dataset is also a L<Metamod::ForeignDataset>, so functions described there are also
valid.

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

=item newFromDoc($mm2Doc, [$xmdDoc, %options])

read a dataset from a document or xml/xmd string.

=item newFromFile($basename)

read a dataset from a file. The file may or may not end with .xml or .xmd. The file will be read
through the L<Metamod::DatasetTransformer>. Thus, also other formats with a Transformer-Implementation
can be read.

Return: $dataset object


=item writeToFile($basename)

see L<Metamod::ForeignDataset>

=item getDS_XML

see L<Metamod::ForeignDataset>

=item getMM2_XML

see L<Metamod::ForeignDataset::getMETA_XML>
Return: xml-string of MM2

=item getInfo()

see L<Metamod::ForeignDataset>

=item setInfo(\%info)

see L<Metamod::ForeignDataset>

=item originalFormat()

see L<Metamod::ForeignDataset>

=item getQuadtree()

see L<Metamod::ForeignDataset>

=item setQuadtree(\@quadtree_nodes)

see L<Metamod::ForeignDataset>

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

