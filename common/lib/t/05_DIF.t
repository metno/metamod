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
use encoding 'utf-8';

use lib "..";
use Test::More tests => 12;

BEGIN {use_ok('Metamod::DatasetTransformer::DIF');}

my $xsltDS = "../../schema/dif2dataset.xslt";
my $xsltMM2 = "../../schema/dif2MM2.xslt";

my ($xmdStr, $xmlStr) = Metamod::DatasetTransformer::getFileContent("exampleDIF");

my $obj = new Metamod::DatasetTransformer::DIF($xmdStr, $xmlStr, 'dsXslt' => $xsltDS, 'mm2Xslt' => $xsltMM2 );
isa_ok($obj, 'Metamod::DatasetTransformer');
isa_ok($obj, 'Metamod::DatasetTransformer::DIF');
ok($obj->test, "test correct file");
my ($dsDoc, $mm2Doc) = $obj->transform;
isa_ok($dsDoc, 'XML::LibXML::Document');
require_ok "Metamod::Dataset";
my $ds = newFromDoc Metamod::Dataset($mm2Doc, $dsDoc);
is(scalar $ds->getQuadtree, 48, "getting quadtree");
#$ds->writeToFile("testDatasetOut$$");

my $obj2 = new Metamod::DatasetTransformer::DIF('bla', 'blub', 'dsXslt' => $xsltDS );
isa_ok($obj2, 'Metamod::DatasetTransformer::DIF');
is($obj2->test, 0, "test invalid file");


my ($xmdStr2, $xmlStr2) = Metamod::DatasetTransformer::getFileContent("exampleMM2");
my $obj3 = new Metamod::DatasetTransformer::DIF($xmdStr2, $xmlStr2, 'dsXslt' => $xsltDS, 'mm2Xslt' => $xsltMM2  );
isa_ok($obj3, 'Metamod::DatasetTransformer::DIF');
is($obj3->test, 0, "test dataset2 file");
eval {
    $obj3->transform;
};
ok($@, "die on wrong transform");
