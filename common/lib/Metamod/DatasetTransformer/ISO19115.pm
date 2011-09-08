#----------------------------------------------------------------------------
#  METAMOD - Web portal for metadata search and upload
#
#  Copyright (C) 2010 met.no
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
package Metamod::DatasetTransformer::ISO19115;
use base qw(Metamod::DatasetTransformer);

our $VERSION = do { my @r = (q$LastChangedRevision$ =~ /\d+/g); sprintf "0.%d", @r };

use strict;
use warnings;
use encoding 'utf-8';
use Carp qw();
use Metamod::Config;
use Log::Log4perl;
use 5.6.0;

my $logger = Log::Log4perl::get_logger('metamod::common::'.__PACKAGE__);

sub originalFormat {
    return "ISO19115";
}

sub xslt_iso_dif {
    return Metamod::DatasetTransformer::xslt_dir() . 'iso2dif.xslt';
}

sub new {
    if (@_ < 3 || (scalar @_ % 2 != 1)) {
        croak ("new " . __PACKAGE__ . " needs argument (package, file), got: @_");
    }
    my ($class, $xmdStr, $xmlStr, %options) = @_;
    my $self = {xmdStr => $xmdStr,
                xmlStr => $xmlStr,
                isoDoc => undef, # init by test
                xmdDoc => undef,
                iso2difXslt => $options{iso2difXslt} || xslt_iso_dif(),
                difTransformer => undef,
               };
    # options to be forwarded to DIF2MM2 conversion
    $self->{xmdXslt} = $options{xmdXslt} if exists $options{xmdXslt};
    $self->{mm2Xslt} = $options{mm2Xslt} if exists $options{mm2Xslt};

    return bless $self, $class;
}

sub test {
    my $self = shift;
    # test on xml-file of xmlStr
    unless ($self->{xmlStr}) {
        $logger->debug("no data");
        return 0; # no data
    }

    unless ($self->{isoDoc}) {
        eval {
            $self->{isoDoc} = $self->XMLParser->parse_string($self->{xmlStr});
        }; # do nothing on error, $doc stays empty
        if ($@) {
            $logger->debug("$@");
        }
    }
    return 0 unless $self->{isoDoc}; # $doc not initialized

    my $xpc = XML::LibXML::XPathContext->new();
    $xpc->registerNs('gmd', 'http://www.isotc211.org/2005/gmd');
    $xpc->registerNs('d', 'http://www.met.no/schema/metamod/dataset');

    # test of content in xmlStr
    my $isISO = 0;
    my $root = $self->{isoDoc}->getDocumentElement();
    my $nodeList = $xpc->findnodes('/gmd:MD_Metadata', $root);
    $logger->debug("found ".$nodeList->size." nodes with /gmd:MD_Metadata");
    if ($nodeList->size() == 1) {
        $isISO = 1;
    }

    my $isXMD = 1;
    if ($self->{xmdStr}) {
        $isXMD = 0; # reset to 0, might fail
        # test optional xmdStr (if xmd file has been created earlier)
        unless ($self->{xmdDoc}) {
            eval {
                $self->{xmdDoc} = $self->XMLParser->parse_string($self->{xmdStr});
            }; # do nothing on error, $doc stays empty
            if ($@) {
                $logger->debug("$@ during xmdStr parsing");
            }
        }
        return 0 unless $self->{xmdDoc};

        my $dsRoot = $self->{isoDoc}->getDocumentElement();
        my $nList = $xpc->findnodes('/d:dataset/d:info/@ownertag', $root);
        if ($nodeList->size() == 1) {
            $isXMD = 1;
        } else {
            $logger->debug("could not find /d:dataset/d:info/\@ownertag");
        }
    }
    if ($isXMD && $isISO) {
        # convert iso to dif already in test, to make sure DIF2MM2-test succeeds
        $logger->debug("testing dif-conversion");
        my $difDoc;
        {
            $logger->debug("reading file: ". $self->{iso2difXslt});
            my $styleDoc = $self->XMLParser->parse_file($self->{iso2difXslt});
            my $stylesheet = $self->XSLTParser->parse_stylesheet($styleDoc);
            $difDoc = $stylesheet->transform($self->{isoDoc});
        }
        my %options;
        $options{mm2Xslt} = $self->{mm2Xslt} if exists $self->{mm2Xslt};
        $options{xmdXslt} = $self->{xmdXslt} if exists $self->{xmdXslt};
        require Metamod::DatasetTransformer::DIF;
        my $difDT = new Metamod::DatasetTransformer::DIF($self->{xmdDoc}, $difDoc, %options);
        $self->{difTransformer} = $difDT;

        my $difTestResult = $difDT->test;
        $logger->debug("dif-conversionn result: $difTestResult");
        return $difTestResult;
    } else {
        $logger->debug("isDataset, isISO: $isXMD, $isISO");
        return 0;
    }
}

sub transform {
    my $self = shift;
    $logger->logcroak("Cannot run transform if test fails") unless $self->test;

    # convert from dif to mm2
    my ($xmdDoc, $mm2Doc) = $self->{difTransformer}->transform;

    return ($xmdDoc, $mm2Doc);
}

1;
__END__

=head1 NAME

Metamod::DatasetTransformaer::ISO19115 - conversion from ISO19115 to MM2 metadata

=head1 SYNOPSIS

  use Metamod::DatasetTransfomer::ISO19115.pm;
  my $dsT = new Metamod::DatasetTransfomer::ISO19115($xmdStr, $xmlStr);
  my $datasetStr;
  if ($dsT->test) {
      ($xmd2Doc, $mm2Doc) = $dsT->transform;
  }


=head1 DESCRIPTION

This module is an implentation of L<Metamod::DatasetTransformer> to convert ISO19115 dataset
format to the dataset and MM2 format. ISO19115 files may contain information from MM2 and
Dataset, but Dataset-information may also be provided through the xmdString.

This module translates first to DIF and then to MM2.

=head1 METHODS

For inherited options see L<Metamod::DatasetTransformer>, only differences are mentioned here.

=over 4

=item new($xmdStr, $xmlStr, %options)

Initialize the transformation by the meta-metadata (optional) and the ISO19115 document as string.

Options include:

=over 8

=item iso2difXslt => 'filename.xslt'

Overwrite the default xslt transformation to convert from ISO19115 to DIF.

=item xmdXslt => 'filename.xslt'

Overwrite the default xslt transformation to convert to the DIF to xmd. This option is forwarded to the
Metamod::DatasetTransformer::DIF.

=item mm2Xslt => 'filename.xslt'

Overwrite the default xslt transformation to convert to the DIF to MM2. This option is forwarded to the
Metamod::DatasetTransformer::DIF.

=back
Return: object
Dies on

=back

=head1 AUTHOR

Heiko Klein, E<lt>H.Klein@met.noE<gt>

=head1 SEE ALSO

L<Metamod::DatasetTransformer>, L<Metamod::DatasetTransformer::DIF>

=cut
