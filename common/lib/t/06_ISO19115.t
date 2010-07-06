#! /usr/bin/perl
use strict;
use warnings;

use lib "..";
use Test::More tests => 8;
use Data::Dumper;

BEGIN{$ENV{METAMOD_XSLT_DIR} = '../../schema/';}
BEGIN {use_ok('Metamod::DatasetTransformer::ISO19115')};

my ($xmdStr, $xmlStr) = Metamod::DatasetTransformer::getFileContent("exampleISO19115");

my $obj = new Metamod::DatasetTransformer::ISO19115($xmdStr, $xmlStr);
isa_ok($obj, 'Metamod::DatasetTransformer::ISO19115');

ok($obj->test, "test correct file");
my ($dsDoc, $mm2Doc) = $obj->transform;
isa_ok($dsDoc, 'XML::LibXML::Document');
isa_ok($mm2Doc, 'XML::LibXML::Document');

my $obj2 = new Metamod::DatasetTransformer::ISO19115('bla', 'blub');
isa_ok($obj2, 'Metamod::DatasetTransformer::ISO19115');
is($obj2->test, 0, "test invalid file");
eval {
    $obj2->transform;
};
ok($@, "die on wrong transform");