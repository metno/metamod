#! -*- perl -*-
use strict;
use warnings;

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
