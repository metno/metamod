#! -*- perl -*-
use strict;
use warnings;

use lib "..";
use Test::More tests => 10;

BEGIN {use_ok('Metamod::DatasetTransformer::OldDataset');}

my $xsltDS = "../../schema/oldDataset2Dataset.xslt";
my $xsltMM2 = "../../schema/oldDataset2MM2.xslt";

my ($xmdStr, $xmlStr) = Metamod::DatasetTransformer::getFileContent("oldDataset");

my $obj = new Metamod::DatasetTransformer::OldDataset($xmdStr, $xmlStr, 'dsXslt' => $xsltDS, 'mm2Xslt' => $xsltMM2 );
isa_ok($obj, 'Metamod::DatasetTransformer');
isa_ok($obj, 'Metamod::DatasetTransformer::OldDataset');
ok($obj->test, "test correct file");
my ($dsDoc, $mm2Doc) = $obj->transform;
isa_ok($dsDoc, 'XML::LibXML::Document');

my $obj2 = new Metamod::DatasetTransformer::OldDataset('bla', 'blub', 'dsXslt' => $xsltDS );
isa_ok($obj2, 'Metamod::DatasetTransformer::OldDataset');
is($obj2->test, 0, "test invalid file");


my ($xmdStr2, $xmlStr2) = Metamod::DatasetTransformer::getFileContent("exampleMM2");
my $obj3 = new Metamod::DatasetTransformer::OldDataset($xmdStr2, $xmlStr2, 'dsXslt' => $xsltDS );
isa_ok($obj3, 'Metamod::DatasetTransformer::OldDataset');
is($obj3->test, 0, "test dataset2 file");
eval {
    $obj3->transform;
};
ok($@, "die on wrong transform");
