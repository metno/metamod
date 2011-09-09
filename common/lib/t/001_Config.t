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

use strict;
use warnings;
use Data::Dumper;

use Cwd;
use FindBin;
use lib "$FindBin::Bin/../";


use Test::More tests => 14;
use Test::Exception;

BEGIN {use_ok('Metamod::Config');}

dies_ok { my $config = Metamod::Config()->new(); } 'Dies on missing parameter';

dies_ok { my $config = Metamod::Config()->new('xyz'); } 'Dies on unknown file';

my $confFile = $FindBin::Bin.'/master_config.txt';
my $config = Metamod::Config->new($confFile);
isa_ok($config, 'Metamod::Config');
can_ok($config, 'get');
ok($config->get('TARGET_DIRECTORY'), 'get TARGET_DIRECTORY');

ok(!$config->get('NOT_THERE'), 'getting false value on NOT_THERE');
ok(index($config->get("SOURCE_DIRECTORY"), $config->get("BASE_DIRECTORY")) == 0, "get sustitutes variables");

is($config->getDSN(), "dbi:Pg:dbname=metamod_unittest;host=localhost;password=admin", "getDSN");

is($config->get('INSTALLATION_DIR'), Cwd::abs_path("$FindBin::Bin/../../../"), 'Installation dir figured out correctly.');

is($config->get('CONFIG_DIR'), "$FindBin::Bin", 'Config directory figured out correctly.');

my $config2 = Metamod::Config->new($FindBin::Bin.'/../t/master_config.txt');
is($config, $config2, "config-singleton on same file");

$config2 = Metamod::Config->instance();
isa_ok($config2, 'Metamod::Config');

ok($config2->get('TARGET_DIRECTORY'), 'get TARGET_DIRECTORY of default');