#! -*- perl -*-
use strict;
use warnings;

use lib "..";
use Test::More tests => 2;

BEGIN {use_ok('Metamod::DatasetTransformer');}

my @plugins = Metamod::DatasetTransformer::getPlugins();
ok ((@plugins > 0), "plugins found");
print "@plugins\n";
