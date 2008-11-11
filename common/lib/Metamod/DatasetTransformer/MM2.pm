package Metamod::DatasetTransformer::MM2;
use base qw(Metamod::DatasetTransformer);

use 5.6.0;
use strict;
use warnings;
use Carp qw(carp croak);
use UNIVERSAL qw( );

our $VERSION = 0.2;

sub originalFormat {
    return "MM2";
}

sub new {
    if (@_ < 3 or (scalar @_ % 2 != 1)) {
        croak ("new " . __PACKAGE__ . " needs argument (package, xmdStr, xmlStr), got: @_\n");
    }
    my ($class, $xmd, $xml, %options) = @_; # %options not used yet
    my ($xmdStr, $xmlStr, $mm2Doc, $dsDoc);
    if (UNIVERSAL::isa($xmd, 'XML::LibXML::Node') and UNIVERSAL::isa($xml, 'XML::LibXML::Node')) {
        $dsDoc = $xmd;
        $mm2Doc = $xml;
    } else {
        $xmdStr = $xmd;
        $xmlStr = $xml;
    }
    my $self = {xmdStr => $xmdStr,
                xmlStr => $xmlStr,
                mm2Doc => $mm2Doc, # init in test, unless given as doc
                dsDoc =>  $dsDoc,  # init in test, unless given as doc
               };
    return bless $self, $class;
}

sub test {
    my $self = shift;

    if (!$self->{dsDoc}) { # start initializing
        eval {
            $self->{dsDoc} = $self->XMLParser->parse_string($self->{xmdStr}) if $self->{xmdStr};
            $self->{mm2Doc} = $self->XMLParser->parse_string($self->{xmlStr}) if $self->{xmlStr};
        }; # do nothing on error, doc stays empty
        if ($self->DEBUG && $@) {
            warn "$@\n";
        }
    }
    unless ($self->{dsDoc} && $self->{mm2Doc}) {
        warn "not both documents initialized" if $self->DEBUG;
        return 0;
    }

    my $xpc = XML::LibXML::XPathContext->new();
    $xpc->registerNs('d', 'http://www.met.no/schema/metamod/dataset');
    $xpc->registerNs('m', 'http://www.met.no/schema/metamod/MM2');

    my $success = 0;
    { # test dataset
        my $root = $self->{dsDoc}->getDocumentElement();
        my $nodeList = $xpc->findnodes('/d:dataset/d:info/@ownertag', $root);
        if ($nodeList->size() == 1) {
            $success++;
        } elsif ($self->DEBUG) {
            warn "could not find /d:dataset/d:info/\@ownertag\n";
        }
    }
    { # test MM2
        my $root = $self->{mm2Doc}->getDocumentElement();
        my $nodeList = $xpc->findnodes('/m:MM2', $root);
        if ($nodeList->size() == 1) {
            $success++;
        } elsif ($self->DEBUG) {
           warn "could not find /m:MM2\n";
        }
    }
    return 1 if $success == 2;
    return 0;
}

sub transform {
    my $self = shift;
    croak("Cannot run transform if test fails\n") unless $self->test;
    
    return ($self->{dsDoc}, $self->{mm2Doc});
}

1;
__END__

=head1 NAME

Metamod::DatasetTransformer::MM2 - identity transform of MM2

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

=item new($xmdStr, $xmlStr, [%options])

In addition to the default initialization by strings, this implementation also allows
initialization by L<XML::LibXML::Node>s.

=back

=head1 VERSION

0.1

=head1 AUTHOR

Heiko Klein, E<lt>H.Klein@met.noE<gt>

=head1 SEE ALSO

L<XML::LibXML>, L<XML::LibXSLT>, L<Metamod::DatasetTransformer>

=cut

