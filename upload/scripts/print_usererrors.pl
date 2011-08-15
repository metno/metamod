#!/usr/bin/perl -w

=begin LICENSE

METAMOD - Web portal for metadata search and upload

Copyright (C) 2008 met.no

Contact information:
Norwegian Meteorological Institute
Box 43 Blindern
0313 OSLO
NORWAY
email: egil.storen@met.no

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

=end LICENSE

=cut

use strict;
use Data::Dumper;

use Metamod::PrintUsererrors;

#
#  Check number of command line arguments
#
if ( scalar @ARGV != 3 ) {
    print STDERR "Usage: $0 <config_file> <usererror_file> <errorinfo_file>\n";
    exit 2;
}

my $config_file    = $ARGV[0];
my $usererror_file = $ARGV[1];
my $errorinfo_file = $ARGV[2];

Metamod::PrintUsererrors::print_errors($config_file, $usererror_file, $errorinfo_file);