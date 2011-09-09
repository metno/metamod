#!/usr/bin/perl -w
#
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
#  email: egil.storen@met.no
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
#
use strict;
use warnings;
use File::Spec;

# small routine to get lib-directories relative to the installed file
sub getTargetDir {
    my ($finalDir) = @_;
    my ($vol, $dir, $file) = File::Spec->splitpath(__FILE__);
    $dir = $dir ? File::Spec->catdir($dir, "..") : File::Spec->updir();
    $dir = File::Spec->catdir($dir, $finalDir);
    return File::Spec->catpath($vol, $dir, "");
}

use lib ('../../common/lib', getTargetDir('lib'), getTargetDir('scripts'), '.');
use encoding 'utf-8';
use Metamod::Config qw( :init_logger );
use MetNo::NcDigest qw( digest );

#
# Check and collect metadata in netCDF files.
# ===========================================
#
# The metadata are checked against a configuration file that define
# which metadata are expected.
#
# Four arguments:
#
# 1. Path to etc directory containing configuration files.
#
# 2. Path to input file. The first line in this file is an URL that points to where
#    the data will be found by users. This dataref URL will be included as metadata in
#    the XML file to be produced.
#    The rest of the lines comprise the files to be parsed, one file
#    on each line. These files all belongs to one dataset.
#
# 3. Ownertag. Short keyword (e.g. "DAM") that will tag the data in the database
#    as owned by a specific project/organisation.
#
# 4. Path to an XML file that will receive the result of the netCDF parsing. If this
#    file already exists, it will contain  the metadata for a previous version
#    of the dataset. In this case, a new version of the file will be created,
#    comprising a merge of the old and new metadata.
#
#---------------------------------------------------------------------------------
#
if (@ARGV < 4 or @ARGV > 5) {
   die "\nUsage:\n\n     $0\n" .
                   "            metadata_configuration_file\n" .
                   "            file_for_netCDF_pathes\n" .
                   "            ownertag\n" .
                   "            path_to_XML_file\n" .
                   "            [isChild]\n\n";
}
my $etcdirectory = $ARGV[0];
my $pathfilename = $ARGV[1];
my $ownertag = $ARGV[2];
my $xml_metadata_path = $ARGV[3];
my $is_child = $ARGV[4];

digest($pathfilename, $ownertag, $xml_metadata_path, $is_child );
