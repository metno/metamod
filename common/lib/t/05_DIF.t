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
#use encoding 'utf-8';
use Data::Dumper qw(Dumper);

use FindBin;
use lib "$FindBin::Bin/../";

use Test::More tests => 18;

BEGIN{
    $ENV{METAMOD_SOURCE_DIRECTORY} = "$FindBin::Bin/../../..";
}

use Metamod::Config;

my $config = Metamod::Config->new("$FindBin::Bin/master_config.txt");
$config->initLogger();

BEGIN {use_ok('Metamod::DatasetTransformer::DIF');}

my $DataDir = $FindBin::Bin.'/data/XML/';
my ($xmdStr, $xmlStr) = Metamod::DatasetTransformer::getFileContent($DataDir."exampleDIF");

my $obj = new Metamod::DatasetTransformer::DIF($xmdStr, $xmlStr);
isa_ok($obj, 'Metamod::DatasetTransformer');
isa_ok($obj, 'Metamod::DatasetTransformer::DIF');
ok($obj->test, "test correct file");
my ($dsDoc, $mm2Doc) = $obj->transform;
isa_ok($dsDoc, 'XML::LibXML::Document');
isa_ok($mm2Doc, 'XML::LibXML::Document');
require_ok "Metamod::Dataset";
my $ds = newFromDoc Metamod::Dataset($mm2Doc, $dsDoc);

#$ds->writeToFile("testDatasetOut$$");

# test the datasetRegion
my $dr = $ds->getDatasetRegion;
my %bb = $dr->getBoundingBox;
is_deeply(\%bb, {north => '90.00', south => '-90.00', east => '180.00', west => '-180.00'}, "bounding box in datasetRegion");
my @polygons = $dr->getPolygons;
is(2, scalar @polygons, "two polygons transformed from DIF");

my $obj2 = new Metamod::DatasetTransformer::DIF('bla', 'blub');
isa_ok($obj2, 'Metamod::DatasetTransformer::DIF');
is($obj2->test, 0, "test invalid file");


my ($xmdStr2, $xmlStr2) = Metamod::DatasetTransformer::getFileContent($DataDir."exampleMM2");
my $obj3 = new Metamod::DatasetTransformer::DIF($xmdStr2, $xmlStr2);
isa_ok($obj3, 'Metamod::DatasetTransformer::DIF');
is($obj3->test, 0, "test dataset2 file");
eval {
    $obj3->transform;
};
ok($@, "die on wrong transform");

{
    my ($xmdStr, $xmlStr) = Metamod::DatasetTransformer::getFileContent($DataDir."exampleDIF");
    my $xmdDoc = Metamod::DatasetTransformer->XMLParser()->parse_string($xmdStr) if $xmdStr;
    my $xmlDoc = Metamod::DatasetTransformer->XMLParser()->parse_string($xmlStr);
    my $obj = new Metamod::DatasetTransformer::DIF($xmdDoc, $xmlDoc);
    isa_ok($obj, 'Metamod::DatasetTransformer');
    isa_ok($obj, 'Metamod::DatasetTransformer::DIF');
    ok($obj->test, "test correct file by doc");
    my ($dsDoc, $mm2Doc) = $obj->transform;
    isa_ok($dsDoc, 'XML::LibXML::Document');
}
