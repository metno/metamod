
=begin licence

METAMOD - Web portal for metadata search and upload

Copyright (C) 2010 met.no

Contact information:
Norwegian Meteorological Institute
Box 43 Blindern
0313 OSLO
NORWAY
email: Heiko.Klein@met.no

This file is part of METAMOD

METAMOD is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

METAMOD is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with METAMOD; if not, write to the Free Software
Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

=end licence

=cut

package Metamod::DatasetTransformer::ToDIF;
use base('Exporter');

our $VERSION = do { my @r = (q$LastChangedRevision$ =~ /\d+/g); sprintf "0.%d", @r };

use strict;
use warnings;
use Log::Log4perl;
use Metamod::DatasetTransformer;
use Metamod::ForeignDataset;

our @EXPORT_OK = qw(foreignDataset2Dif);
our $_logger = Log::Log4perl::get_logger('metamod::common::'.__PACKAGE__);

my $mm2ToDifStyle;
my $isoToDifStyle;
my $jifStyle;
my $_init = 0;
sub _init {
    return if $_init++;

    my $mm2ToDifXslt = Metamod::DatasetTransformer::xslt_dir() . 'mm2dif.xsl';
    my $isoToDifXslt = Metamod::DatasetTransformer::xslt_dir() . 'iso2dif.xslt';
    my $jifXslt = Metamod::DatasetTransformer::xslt_dir() . 'jif.xsl';

    my $styleDoc = Metamod::DatasetTransformer->XMLParser->parse_file($mm2ToDifXslt);
    $mm2ToDifStyle = Metamod::DatasetTransformer->XSLTParser->parse_stylesheet($styleDoc);
    if (!$mm2ToDifStyle) {
        $_logger->logcroak("cannot parse stylesheet $mm2ToDifXslt");
    }
    $styleDoc = Metamod::DatasetTransformer->XMLParser->parse_file($isoToDifXslt);
    $isoToDifStyle = Metamod::DatasetTransformer->XSLTParser->parse_stylesheet($styleDoc);
    if (!$isoToDifStyle) {
        $_logger->logcroak("cannot parse stylesheet $isoToDifXslt");
    }
    $styleDoc = Metamod::DatasetTransformer->XMLParser->parse_file($jifXslt);
    $jifStyle = Metamod::DatasetTransformer->XSLTParser->parse_stylesheet($styleDoc);
    if (!$jifStyle) {
        $_logger->logcroak("cannot parse stylesheet $jifXslt");
    }
}

sub foreignDataset2Dif {
    my ($foreignDataset) = @_;
        _init();
    if (!UNIVERSAL::isa($foreignDataset, 'Metamod::ForeignDataset')) {
        $_logger->error_log("foreignDataset2iso19115 requires Metamod::ForeignDataset, got: " . ref($foreignDataset));
    }
    # get a DatasetTransformer-plugin
    my $transformer = Metamod::DatasetTransformer::autodetect($foreignDataset);
        if (UNIVERSAL::isa($transformer, 'Metamod::DatasetTransformer::DIF')) {
        $_logger->debug("foreign dataset is DIF, no change needed");
        return $foreignDataset;
    } elsif (UNIVERSAL::isa($transformer,'Metamod::DatasetTransformer::ISO19115')) {
        $_logger->debug("foreignDataset is ISO19115, only simple transformation needed");
        my $isoDoc = $foreignDataset->getMETA_DOC();
        my $difDoc = $isoToDifStyle->transform($isoDoc);
        return Metamod::ForeignDataset->newFromDoc($difDoc, $foreignDataset->getXMD_DOC());
    } elsif (UNIVERSAL::isa($transformer,'Metamod::DatasetTransformer')) {
        my ($xmdDoc, $xmlDoc);
        if (UNIVERSAL::isa($transformer,'Metamod::DatasetTransformer::MM2')) {
            $_logger->debug("foreignDataset is MM2, only simple transformation needed");
            $xmdDoc = $foreignDataset->getXMD_DOC();
            $xmlDoc = $foreignDataset->getMETA_DOC();
        } else {
            $_logger->debug("foreignDataset is does map to internal, converting to internal->DIF->ISO");
            ($xmdDoc, $xmlDoc) = $transformer->transform();
        }
        # transform to dif
        my %info = $foreignDataset->getInfo();
        # path-separator / changed to _
        my $dsName = $info{name};
        $dsName =~ s:([^/]+)/:$1_:;
        my %params = (
            DS_name => $dsName,
            DS_creationdate => $info{creationDate},
            DS_datestamp => $info{datestamp},
        );
        my $mm2Doc = $foreignDataset->getMETA_DOC();
        my $_difDoc = $mm2ToDifStyle->transform(
            $mm2Doc,
            XML::LibXSLT::xpath_to_string(%params) # always double quote strings for XSLT
        );
        # post-transform processing
        my $difDoc = $jifStyle->transform($_difDoc);

        return Metamod::ForeignDataset->newFromDoc($difDoc, $foreignDataset->getXMD_DOC());
    }

    # each working case returns with result, throw exception
    my %info = $foreignDataset->getInfo();
    $_logger->error_die('cannot translate dataset '.$info{name}.' to internal format');
}

1;
__END__

=head1 NAME

Metamod::DatasetTransformer::ToDIF - transform foreign datasets to DIF

=head1 SYNOPSIS

  use Metamod::DatasetTransformer::ToDIF qw(foreignDataset2Dif);
  my $foreignDataset = ...;
  my $dif;
  eval { $dif = foreignDataset2Dif($foreignDataset) };
  if ($@) { ... };

=head1 DESCRIPTION

The Metamod::DatasetTransformer::ToDIF reads (DIF, ISO, MM2, OldDataset) file formats and
converts them to DIF by either using direct transformations, or by converting to the
internal format first. In constrast to the Metamod::DatasetTransformer::DIF module,
this module is able to convert the datasets to DIF instead of an
internal format.


=head1 FUNCTIONS

=over 4

=item foreignDataset2Dif($foreignDataset)

Return: $foreignDataset (in DIF format)
Throws: on file-system related problems
        if the xml-schema doesn't match
        if no parameter given

=back

=head1 AUTHOR

Heiko Klein, E<lt>H.Klein@met.noE<gt>

=head1 SEE ALSO

L<Metamod::DatsetTransformer>

=cut