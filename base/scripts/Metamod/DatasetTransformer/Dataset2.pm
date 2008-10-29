use strict;
use warnings;
use Carp qw(carp croak);
use XML::LibXML;
use XML::LibXSLT;

use 5.6.0;

package Metamod::DatasetTransformer::Dataset2;
use base qw(Metamod::DatasetTransformer);

our $VERSION = 0.1;

sub new {
    if (@_ < 2) {
        croak ("new " . __PACKAGE__ . " needs argument (package, xmlStr), got: @_\n");
    }
    my ($class, $xmlStr, %options) = @_; # %options not used yet
    my $parser = XML::LibXML->new();
    my $doc;
    eval {
        $doc = $parser->parse_string($xmlStr);
    }; # do nothing on error, $doc stays empty
    my $self = {xmlStr => $xmlStr,
                doc => $doc,
               };
    return bless $self, $class;
}

sub test {
    my $self = shift;
    return 0 unless $self->{doc}; # $doc not initialized

    my $xpc = XML::LibXML::XPathContext->new();
    $xpc->registerNs('d', 'http://www.met.no/schema/metamod/dataset2/');

    my $root = $self->{doc}->getDocumentElement();
    my $nodeList = $xpc->findnodes('/d:dataset/d:info/@ownertag', $root);
    if ($nodeList->size() == 1) {
        return 1;
    }
    return 0;
}

sub transform {
    my $self = shift;
    croak("Cannot run transform if test fails\n") unless $self->test;
    
    return $self->{doc};
}

1;
__END__

=head1 NAME

Metamod::DatasetTransformer::Dataset2 - identity transform of dataset2

=head1 SYNOPSIS

  use Metamod::DatasetTransfomer::Dataset2.pm;
  my $dsT = new Metamod::DatasetTransfomer::Dataset2($xmlStr);
  my $datasetStr;
  if ($dsT->test) {
      $ds2Obj = $dsT->transform;
  }

=head1 DESCRIPTION

This module is an implentation of L<Metamod::DatasetTransformer>. It does the identity conversion
of the dataset2 format.

=head1 METHODS

For inherited options see L<Metamod::DatasetTransformer>, only differences are mentioned here.

=over 4


=back

=head1 VERSION

0.1

=head1 AUTHOR

Heiko Klein, E<lt>H.Klein@met.noE<gt>

=head1 SEE ALSO

L<XML::LibXML>, L<XML::LibXSLT>, L<Metamod::DatasetTransformer>

=cut

