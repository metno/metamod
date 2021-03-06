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
package Metamod::DatasetTransformer::ToISO19115;
use base('Exporter');

our $VERSION = do { my @r = (q$LastChangedRevision$ =~ /\d+/g); sprintf "0.%d", @r };

use strict;
use warnings;
use Data::Dumper;
use Metamod::ForeignDataset;
use Metamod::DatasetTransformer;
use Metamod::DatasetTransformer::ToDIF;
use Carp qw(cluck);
use Log::Log4perl;

our @EXPORT_OK = qw(foreignDataset2iso19115);
our $_logger = Log::Log4perl->get_logger('metamod::common::Metamod::DatasetTransformer::ToISO19115');

my ($difToIsoStyle, $mmdToIsoStyle);
my $_init = 0;
sub _init {
    return if $_init++;

    my $difToIsoXslt = Metamod::DatasetTransformer::xslt_dir() . 'dif2iso.xslt';
    my $mmdToIsoXslt = Metamod::DatasetTransformer::xslt_dir() . 'mmd-to-iso.xsl';
    $difToIsoStyle = Metamod::DatasetTransformer->XSLTParser->parse_stylesheet_file($difToIsoXslt) or $_logger->logcroak("cannot parse stylesheet $difToIsoXslt");
    $mmdToIsoStyle = Metamod::DatasetTransformer->XSLTParser->parse_stylesheet_file($mmdToIsoXslt) or $_logger->logcroak("cannot parse stylesheet $difToIsoXslt");
}

sub foreignDataset2iso19115 {
    my ($foreignDataset, $options) = @_;
    $options = {} unless defined $options;
    _init();
    if (!UNIVERSAL::isa($foreignDataset, 'Metamod::ForeignDataset')) {
        $_logger->error_log("foreignDataset2iso19115 requires Metamod::ForeignDataset, got: " . ref($foreignDataset));
    }
    my $difFds;
    # get a DatasetTransformer-plugin
    my $transformer = Metamod::DatasetTransformer::autodetect($foreignDataset);
    if (UNIVERSAL::isa($transformer, 'Metamod::DatasetTransformer::ISO19115')) {
        $_logger->debug("foreign dataset is ISO, no change needed");
        return $foreignDataset;
    } elsif (UNIVERSAL::isa($transformer,'Metamod::DatasetTransformer::DIF')) {
        $_logger->debug("foreignDataset is DIF, only one transformation need");
        $difFds = $foreignDataset;
    } elsif (UNIVERSAL::isa($transformer,'Metamod::DatasetTransformer::MMD')) {
        ## MMD is converted directly to ISO without going through MM2 and DIF
        $_logger->debug("foreignDataset is MMD, only simple transformation needed");
        my $mmdDoc = $foreignDataset->getMETA_DOC();
        my $isoDoc = $mmdToIsoStyle->transform($mmdDoc);
        return Metamod::ForeignDataset->newFromDoc($isoDoc, $foreignDataset->getXMD_DOC());
    } elsif (UNIVERSAL::isa($transformer,'Metamod::DatasetTransformer')) {
        $_logger->debug("foreignDataset is does map to internal, converting to internal->DIF->ISO");
        my ($xmdDoc, $xmlDoc) = $transformer->transform();
        # transform to dif
        # require Metamod::DatasetTransformer::ToDIF; # must 'use' instead since INC not working after chdir
        $difFds = Metamod::DatasetTransformer::ToDIF::foreignDataset2Dif($foreignDataset);
    } else {
        my %info = $foreignDataset->getInfo();
        $_logger->error_die('cannot translate dataset '.$info{name}.' to internal format');
    }
    my %info = $foreignDataset->getInfo();
    my %params = ('DATASET_TIMESTAMP' => $info{datestamp}); # required
    $params{REPOSITORY_IDENTIFIER} = $options->{REPOSITORY_IDENTIFIER}
        if exists $options->{REPOSITORY_IDENTIFIER};
    my $isoDoc = $difToIsoStyle->transform($difFds->getMETA_DOC(), XML::LibXSLT::xpath_to_string(%params));
    return Metamod::ForeignDataset->newFromDoc($isoDoc, $difFds->getXMD_DOC());

}

1;
__END__

=head1 NAME

Metamod::DatasetTransformer::ToISO19115 - transform datasetTransformer objects to Iso19115

=head1 SYNOPSIS

  use Metamod::DatasetTransformer::ToISO19115 qw(foreignDataset2iso19115);
  my $foreignDataset = ...; # arbitrary ForeignDataset
  my $ds2iso;
  eval {
    $ds2iso = foreignDataset2iso19115($fds);
  }; if ($@) {
    ...
  }

=head1 DESCRIPTION

The Metamod::DatasetTransformer::ToISO19115 reads (DIF, ISO, MM2, OldDataset) file formats and is able to convert
them to a internal format. This module is able to convert the datasets to ISO19115 instead of an
internal format.

=head2 FUNCTIONS

=head3 foreignDataset2iso19115($foreignDataset, [{options}])

Parameter: $foreignDataset Metamod::ForeignDataset of base-filename.
           $options: currently supported: {REPOSITORY_IDENTIFIER => '...'}, text-string of the
           repository-name, i.e. $config->getVar('PMH_REPOSITORY_IDENTIFIER')

Return: object
Exceptions: on file-system related problems
            if the xml-schema doesn't match
            if no parameter given

=head1 AUTHOR

Heiko Klein, E<lt>H.Klein@met.noE<gt>

=head1 SEE ALSO

L<Metamod::DatsetTransformer>

=cut
