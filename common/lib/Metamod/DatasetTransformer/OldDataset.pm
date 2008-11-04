package Metamod::DatasetTransformer::OldDataset;
use base qw(Metamod::DatasetTransformer);

use strict;
use warnings;
use Carp qw(carp croak);
use XML::LibXML;
use XML::LibXSLT;

use 5.6.0;


our $VERSION = 0.1;
our $XSLT_FILE_MM2 = "[==SOURCE_DIRECTORY==]/common/schema/oldDataset2MM2.xslt";
our $XSLT_FILE_DS = "[==SOURCE_DIRECTORY==]/common/schema/oldDataset2Dataset.xslt";

sub originalFormat {
    return "OldDataset";
}

sub new {
    if (@_ < 3 || (scalar @_ % 2 != 1)) {
        croak ("new " . __PACKAGE__ . " needs argument (package, file), got: @_\n");
    }
    my ($class, $xmdStr, $xmlStr, %options) = @_;
    my $parser = XML::LibXML->new();
    my $self = {xmdStr => $xmdStr,
                xmlStr => $xmlStr,
                oldDoc => undef, # init by test
                dsXslt => $options{dsXslt} || $XSLT_FILE_DS,
                mm2Xslt => $options{mm2Xslt} || $XSLT_FILE_MM2,
                parser => $parser,
               };
    return bless $self, $class;
}

sub test {
    my $self = shift;
    # test on xml-file of xmlStr
    unless ($self->{xmlStr}) {
        return 0; # no data
    }
    unless ($self->{oldDoc}) {
        eval {
            $self->{oldDoc} = $self->{parser}->parse_string($self->{xmlStr});
        }; # do nothing on error, $doc stays empty
    }
    return 0 unless $self->{oldDoc}; # $doc not initialized
    
    # test of content in xmlStr
    my $root = $self->{oldDoc}->getDocumentElement();
    my $nodeList = $root->findnodes('/dataset/@ownertag');
    if ($nodeList->size() == 1) {
        return 1;
    }
    return 0;
}

sub transform {
    my $self = shift;
    croak("Cannot run transform if test fails\n") unless $self->test;
    my $xslt = new XML::LibXSLT();
    
    my $styleDoc = $self->{parser}->parse_file($self->{mm2Xslt});    
    my $stylesheet = $xslt->parse_stylesheet($styleDoc);
    my $mm2Doc = $stylesheet->transform($self->{oldDoc});
    
    $styleDoc = $self->{parser}->parse_file($self->{dsXslt});
    $stylesheet = $xslt->parse_stylesheet($styleDoc);
    my $dsDoc = $stylesheet->transform($self->{oldDoc});

    return ($dsDoc, $mm2Doc);
}

1;
__END__

=head1 NAME

Metamod::DatasetTransformer::OldDataset - transform old-dataset to dataset and MM2

=head1 SYNOPSIS

  use Metamod::DatasetTransfomer::OldDataset.pm;
  my $dsT = new Metamod::DatasetTransfomer::Dataset($xmdStr, $xmlStr);
  my $datasetStr;
  if ($dsT->test) {
      $ds2Obj = $dsT->transform;
  }

=head1 DESCRIPTION

This module is an implentation of L<Metamod::DatasetTransformer> to convert the old
dataset format to the dataset and MM2 format. Old datasets combined the metadata-information and the
metadata of metadata (now called dataset) into one file. There doesn't exist a .xmd file for the old
datasets.

=head1 METHODS

For inherited options see L<Metamod::DatasetTransformer>, only differences are mentioned here.

=over 4

=item new($xmlStr, %options)

Options include:

=over 8

=item dsXslt => 'filename.xslt'

Overwrite the default xslt file to convert to the actual dataset format.

=item mm2Xslt => 'filename.xslt'

Overwrite the default xslt file to convert to the mm2 format.

=back

=back

=head1 VERSION

0.1

=head1 AUTHOR

Heiko Klein, E<lt>H.Klein@met.noE<gt>

=head1 SEE ALSO

L<XML::LibXML>, L<XML::LibXSLT>, L<Metamod::DatasetTransformer>

=cut

