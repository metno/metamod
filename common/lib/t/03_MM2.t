#! -*- perl -*-
use strict;
use warnings;

use lib "..";
use Test::More tests => 10;

BEGIN {use_ok('Metamod::DatasetTransformer::MM2');}

my ($xmdStr, $xmlStr) = Metamod::DatasetTransformer::getFileContent("exampleMM2");

my $obj = new Metamod::DatasetTransformer::MM2($xmdStr, $xmlStr);
isa_ok($obj, 'Metamod::DatasetTransformer');
isa_ok($obj, 'Metamod::DatasetTransformer::MM2');
ok($obj->test, "test correct MM2 file");
isa_ok($obj->transform, 'XML::LibXML::Document');

my $obj2 = new Metamod::DatasetTransformer::MM2('bla', 'blub');
isa_ok($obj2, 'Metamod::DatasetTransformer::MM2');
is($obj2->test, 0, "test invalid file");


my ($xmdStr2, $xmlStr2) = Metamod::DatasetTransformer::getFileContent("oldDataset");
my $obj3 = new Metamod::DatasetTransformer::MM2($xmdStr2, $xmlStr2);
isa_ok($obj3, 'Metamod::DatasetTransformer::MM2');
is($obj3->test, 0, "test dataset file");
eval {
    $obj3->transform;
};
ok($@, "die on wrong transform");
