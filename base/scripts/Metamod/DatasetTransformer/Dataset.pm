use strict;
use warnings;
use Carp qw(carp croak);
use XML::LibXML;
use XML::LibXSLT;

use 5.6.0;

package Metamod::DatasetTransformer::Dataset;
use base qw(Metamod::DatasetTransformer);

our $VERSION = 0.1;
our $XSLT_FILE = "[==SOURCE_DIRECTORY==]/common/schema/metamodDatasetChanger.xslt";

sub new {
    if (@_ < 2) {
        croak ("new " . __PACKAGE__ . " needs argument (package, xmlStr), got: @_\n");
    }
    my ($class, $xmlStr, %options) = @_;
    my $parser = XML::LibXML->new();
    my $doc;
    eval {
        $doc = $parser->parse_string($xmlStr);
    }; # do nothing on error, $doc stays empty
    my $self = {xmlStr => $xmlStr,
                doc => $doc,
                xslt => $options{xslt} || $XSLT_FILE,
                parser => $parser,
               };
    return bless $self, $class;
}

sub test {
    my $self = shift;
    return 0 unless $self->{doc}; # $doc not initialized
    my $root = $self->{doc}->getDocumentElement();
    my $nodeList = $root->findnodes('/dataset/@ownertag');
    if ($nodeList->size() == 1) {
        return 1;
    }
    return 0;
}

sub transform {
    my $self = shift;
    croak("Cannot run transform if test fails\n") unless $self->test;
    
    my $styleDoc = $self->{parser}->parse_file($self->{xslt});
    my $xslt = new XML::LibXSLT();
    my $stylesheet = $xslt->parse_stylesheet($styleDoc);

    return $stylesheet->transform($self->{doc});
}

1;
__END__

=head1 NAME

Metamod::DatasetTransformer::Dataset - transform dataset1 to dataset2

=head1 SYNOPSIS

  use Metamod::DatasetTransfomer::Dataset.pm;
  my $dsT = new Metamod::DatasetTransfomer::Dataset($xmlStr);
  my $datasetStr;
  if ($dsT->test) {
      $ds2Obj = $dsT->transform;
  }

=head1 DESCRIPTION

This module is an implentation of L<Metamod::DatasetTransformer> to convert the old
dataset format to the dataset2 format.

=head1 METHODS

For inherited options see L<Metamod::DatasetTransformer>, only differences are mentioned here.

=over 4

=item new($xmlStr, %options)

Options include:

=over 8

=item xslt => 'filename.xslt'

Overwrite the default xslt file by this file.

=back

=back

=head1 VERSION

0.1

=head1 AUTHOR

Heiko Klein, E<lt>H.Klein@met.noE<gt>

=head1 SEE ALSO

L<XML::LibXML>, L<XML::LibXSLT>, L<Metamod::DatasetTransformer>

=cut

