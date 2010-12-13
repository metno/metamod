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

use FindBin;
use lib "$FindBin::Bin/../";


use Test::More tests => 12;

BEGIN {use_ok('Metamod::Config');}

my $confFile = $FindBin::Bin.'/master_config.txt';
my $config = new Metamod::Config($confFile);
isa_ok($config, 'Metamod::Config');
can_ok($config, 'get');
ok($config->get('TARGET_DIRECTORY'), 'get TARGET_DIRECTORY');
#print STDERR Dumper($config->{vars});
ok(!$config->get('NOT_THERE'), 'getting false value on NOT_THERE');
ok(index($config->get("SOURCE_DIRECTORY"), $config->get("BASE_DIRECTORY")) == 0, "get sustitutes variables");

is($config->getDSN(), "dbi:Pg:dbname=damocles;host=localhost;port=15432;", "getDSN");

my $config2 = new Metamod::Config($FindBin::Bin.'/../t/master_config.txt');
is($config, $config2, "config-singleton on same file");

eval {
	$config2 = new Metamod::Config('xyz');
};
ok($@, 'config dies on missing file');

$config2 = new Metamod::Config();
isa_ok($config2, 'Metamod::Config');
ok($config2->get('TARGET_DIRECTORY'), 'get TARGET_DIRECTORY of default');

my $cwd = Cwd::getcwd();
chdir "/tmp";
my $config3;
eval {
    $config3 = new Metamod::Config();
};
isa_ok($config3, 'Metamod::Config');
chdir $cwd;