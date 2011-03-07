#! -*- perl -*-
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

use FindBin;
use lib "$FindBin::Bin/../";

use Test::More tests => 10;

BEGIN {use_ok('Metamod::DatasetTransformer::MM2');}
Log::Log4perl::init( "$FindBin::Bin/log4perl_config.ini" );

my $DataDir = $FindBin::Bin.'/data/XML/';
my ($xmdStr, $xmlStr) = Metamod::DatasetTransformer::getFileContent($DataDir."exampleMM2");

my $obj = new Metamod::DatasetTransformer::MM2($xmdStr, $xmlStr);
isa_ok($obj, 'Metamod::DatasetTransformer');
isa_ok($obj, 'Metamod::DatasetTransformer::MM2');
ok($obj->test, "test correct MM2 file");
isa_ok($obj->transform, 'XML::LibXML::Document');

my $obj2 = new Metamod::DatasetTransformer::MM2('bla', 'blub');
isa_ok($obj2, 'Metamod::DatasetTransformer::MM2');
is($obj2->test, 0, "test invalid file");


my ($xmdStr2, $xmlStr2) = Metamod::DatasetTransformer::getFileContent($DataDir."oldDataset");
my $obj3 = new Metamod::DatasetTransformer::MM2($xmdStr2, $xmlStr2);
isa_ok($obj3, 'Metamod::DatasetTransformer::MM2');
is($obj3->test, 0, "test dataset file");
eval {
    $obj3->transform;
};
ok($@, "die on wrong transform");
