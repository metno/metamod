
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

package Metamod::DatasetTransformer::ToOAIDublinCore;
use base('Exporter');

use strict;
use warnings;
use Log::Log4perl;
use Metamod::DatasetTransformer;
use Metamod::ForeignDataset;

=head1 NAME

Metamod::DatasetTransformer::ToOAIDublinCore - transform foreign datasets to OAI Dublin Core format.

=head1 SYNOPSIS

  use Metamod::DatasetTransformer::ToAOIDublinCore qw(foreignDataset2oai_dc);
  my $foreignDataset = ...;
  my $dc;
  eval { $dc = foreignDataset2oai_dc($foreignDataset) };
  if ($@) { ... };

=head1 DESCRIPTION

The Metamod::DatasetTransformer::ToOAIDublinCore reads (DIF, ISO, MM2,
OldDataset) file formats and converts them to OAI Dublin core format by first
transforming the dataset to MM2 if necessary and then doing a transformation
from MM2 to OAI Dublic Core.

Please note that having metadata in OAI Dublin Core from the start is not
supported.

=head1 FUNCTIONS

=over 4

=item foreignDataset2oai_dc($foreignDataset)

Return: $foreignDataset (in DIF format)
Throws: on file-system related problems
        if the xml-schema doesn't match
        if no parameter given

=back

=cut

our @EXPORT_OK = qw(foreignDataset2oai_dc);
our $_logger = Log::Log4perl::get_logger('metamod::common::'.__PACKAGE__);

my $mm2oai_dc_style;
my $_init = 0;
sub _init {
    return if $_init++;

    my $mm2oai_dc = Metamod::DatasetTransformer::xslt_dir() . 'mm2oai_dc.xsl';

    my $styleDoc = Metamod::DatasetTransformer->XMLParser->parse_file($mm2oai_dc);
    $mm2oai_dc_style = Metamod::DatasetTransformer->XSLTParser->parse_stylesheet($styleDoc);
    if (!$mm2oai_dc_style) {
        $_logger->logcroak("cannot parse stylesheet $mm2oai_dc");
    }

}

sub foreignDataset2oai_dc {
    my ($foreignDataset) = @_;

    _init();
    if (!UNIVERSAL::isa($foreignDataset, 'Metamod::ForeignDataset')) {
        $_logger->error_log("foreignDataset2oai_dc requires Metamod::ForeignDataset, got: " . ref($foreignDataset));
    }


    my $transformer = Metamod::DatasetTransformer::autodetect($foreignDataset);
    my ($xmd_doc, $xml_doc);
    if( !$transformer->isa('Metamod::DatasetTransformer::MM2')){
        ($xmd_doc, $xml_doc) = $transformer->transform();
    } else {
        $xmd_doc = $foreignDataset->getXMD_DOC();
        $xml_doc = $foreignDataset->getMETA_DOC();
    }
    my $oai_dc_doc = $mm2oai_dc_style->transform($xml_doc);

    return Metamod::ForeignDataset->newFromDoc($oai_dc_doc, $xmd_doc);

}

1;