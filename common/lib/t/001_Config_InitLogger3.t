#! -*- perl -*-
#----------------------------------------------------------------------------
#  METAMOD - Web portal for metadata search and upload
#
#  Copyright (C) 2009 met.no
#
#  Contact information:
#  Norwegian Meteorological Institute
#  Box 43 Blindern
#  0313 OSLO
#  NORWAY
#  email: oystein.torget@met.no
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

use strict;
use warnings;

use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin/../";


use Log::Log4perl qw( get_logger );

use Test::More tests => 1;
use Test::Files;

use Metamod::Config;

Metamod::Config::staticInitLogger("$FindBin::Bin/master_config.txt");

my $logger = get_logger( 'test' );

$logger->info( 'Test 1' );
$logger->error( 'Test 2' );

compare_ok( "$FindBin::Bin/expected_log.log", "$FindBin::Bin/log4perl_test.log", 'Output from logger initialised from staticInitLogger' );
