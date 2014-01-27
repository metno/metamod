#----------------------------------------------------------------------------
#  METAMOD - Web portal for metadata search and upload
#
#  Copyright (C) 2008 met.no
#
#  Contact information:
#  Norwegian Meteorological Institute
#  Box 43 Blindern
#  0313 OSLO
#  NORWAY
#  email: Heiko.Klein@met.no
#
#  This file is part of METAMOD
#
#  METAMOD is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  METAMOD is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with METAMOD; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#----------------------------------------------------------------------------
package Metamod::DatasetTransformer::MM2;
use base qw(Metamod::DatasetTransformer);

use 5.6.0;
use strict;
use warnings;
use Carp qw(carp croak);
use UNIVERSAL qw( );
use Log::Log4perl;

our $VERSION = do { my @r = (q$LastChangedRevision$ =~ /\d+/g); sprintf "0.%d", @r };
my $logger = Log::Log4perl::get_logger('metamod::common::Metamod::DatasetTransformer::MM2');

sub originalFormat {
    return "MM2";
}

sub new {
    if (@_ < 3 or (scalar @_ % 2 != 1)) {
        croak ("new " . __PACKAGE__ . " needs argument (package, xmdStr, xmlStr), got: @_\n");
    }
    my ($class, $xmd, $xml, %options) = @_; # %options not used yet
    my ($xmdStr, $xmlStr, $mm2Doc, $xmdDoc);
    if (UNIVERSAL::isa($xmd, 'XML::LibXML::Node') and UNIVERSAL::isa($xml, 'XML::LibXML::Node')) {
        $xmdDoc = $xmd;
        $mm2Doc = $xml;
    } else {
        $xmdStr = $xmd;
        $xmlStr = $xml;
    }
    my $self = {xmdStr => $xmdStr,
                xmlStr => $xmlStr,
                mm2Doc => $mm2Doc, # init in test, unless given as doc
                xmdDoc =>  $xmdDoc,  # init in test, unless given as doc
               };
    return bless $self, $class;
}

sub test {
    my $self = shift;

    if (!$self->{xmdDoc}) { # start initializing
        eval {
            $self->{xmdDoc} = $self->XMLParser->parse_string($self->{xmdStr}) if $self->{xmdStr};
            $self->{mm2Doc} = $self->XMLParser->parse_string($self->{xmlStr}) if $self->{xmlStr};
        }; # do nothing on error, doc stays empty
        if ($@) {
            $logger->debug("$@\n");
        }
    }
    unless ($self->{xmdDoc} && $self->{mm2Doc}) {
        $logger->debug("not both documents initialized");
        return 0;
    }

    my $xpc = XML::LibXML::XPathContext->new();
    $xpc->registerNs('d', 'http://www.met.no/schema/metamod/dataset');
    $xpc->registerNs('m', 'http://www.met.no/schema/metamod/MM2');

    my $success = 0;
    { # test dataset
        my $root = $self->{xmdDoc}->getDocumentElement();
        my $nodeList = $xpc->findnodes('/d:dataset/d:info/@ownertag', $root);
        if ($nodeList->size() == 1) {
            $success++;
        } else {
            $logger->debug("could not find /d:dataset/d:info/\@ownertag");
        }
    }
    { # test MM2
        my $root = $self->{mm2Doc}->getDocumentElement();
        my $nodeList = $xpc->findnodes('/m:MM2', $root);
        #$logger->debug("found ".$nodeList->size()." elements of /m:MM2");
        if ($nodeList->size() == 1) {
            $success++;
        }
    }
    return 1 if $success == 2;
    return 0;
}

sub transform {
    my $self = shift;
    croak("Cannot run transform if test fails") unless $self->test;

    return ($self->{xmdDoc}, $self->{mm2Doc});
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
