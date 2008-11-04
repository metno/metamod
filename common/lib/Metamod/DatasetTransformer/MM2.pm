package Metamod::DatasetTransformer::MM2;
use base qw(Metamod::DatasetTransformer);

use 5.6.0;
use strict;
use warnings;
use Carp qw(carp croak);
use XML::LibXML;
use XML::LibXSLT;

our $DEBUG = 0;

our $VERSION = 0.1;

sub originalFormat {
    return "MM2";
}

sub new {
    if (@_ < 3 or (scalar @_ % 2 != 1)) {
        croak ("new " . __PACKAGE__ . " needs argument (package, xmdStr, xmlStr), got: @_\n");
    }
    my ($class, $xmdStr, $xmlStr, %options) = @_; # %options not used yet
    my $self = {xmdStr => $xmdStr,
                xmlStr => $xmlStr,
                mm2Doc => undef, # init in test
                dsDoc => undef, # init in test
               };
    return bless $self, $class;
}

sub test {
    my $self = shift;

    if (!$self->{dsDoc}) { # start initializing
        my $parser = XML::LibXML->new();
        eval {
            $self->{dsDoc} = $parser->parse_string($self->{xmdStr});
            $self->{mm2Doc} = $parser->parse_string($self->{xmlStr});
        }; # do nothing on error, doc stays empty
        if ($DEBUG && $@) {
            warn "$@\n";
        }
    }
    unless ($self->{dsDoc} && $self->{mm2Doc}) {
        warn "not both documents initialized" if $DEBUG;
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
        } elsif ($DEBUG) {
            warn "could not find /d:dataset/d:info/\@ownertag\n";
        }
    }
    { # test MM2
        my $root = $self->{mm2Doc}->getDocumentElement();
        my $nodeList = $xpc->findnodes('/m:MM2', $root);
        if ($nodeList->size() == 1) {
            $success++;
        } elsif ($DEBUG) {
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


=back

=head1 VERSION

0.1

=head1 AUTHOR

Heiko Klein, E<lt>H.Klein@met.noE<gt>

=head1 SEE ALSO

L<XML::LibXML>, L<XML::LibXSLT>, L<Metamod::DatasetTransformer>

=cut

