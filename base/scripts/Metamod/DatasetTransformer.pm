use strict;
use warnings;

use 5.6.0;

package Metamod::DatasetTransformer;

our $VERSION = 0.1;

sub new {
    die "'new' not implemented yet: new(\$dataStr)\n";
}

sub test {
    die "'test' not implemented yet\n";
}

sub transform {
    die "'transform' not implemented yet\n";
}

1;
__END__

=head1 NAME

Metamod::DatasetTransformer - interface to transform datasets

=head1 SYNOPSIS

  use Metamod::DatasetTransfomer::Impl;
  my $implX = new Metamod::DatasetTransfomer::ImplX($dataStr);
  my $datasetStr;
  if ($implX->test) {
      $datasetObj = $implX->transform;
  }

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item new($filename)

Initialize this object with an appropriate filename. This method should not die, except for severe programming errors.

=item test

Test if the filename belongs to this transformer. Return 1 on success 0 on failure. This method should not die,
except for severe programming errors.

=item transform

Transform the file to the 'dataset2' format. This functions returns a XML::LibXML::Document. This function should die
if L<test> returns 0, or if the test wasn't sufficient.

=back

=head1 VERSION

0.1

=head1 AUTHOR

Heiko Klein, E<lt>H.Klein@met.noE<gt>

=head1 SEE ALSO

L<XML::LibXML>

=cut

