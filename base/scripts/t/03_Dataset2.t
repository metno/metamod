#! -*- perl -*-
use strict;
use warnings;

use lib "..";
use Test::More tests => 10;

BEGIN {use_ok('Metamod::DatasetTransformer::Dataset2');}

my $xmlStr;
{
    open F, 'dataset2.xml' or die "Cannot read dataset2.xml: $!\n";
    local $/ = undef;
    $xmlStr = <F>;
    close F;
}

my $obj = new Metamod::DatasetTransformer::Dataset2($xmlStr);
isa_ok($obj, 'Metamod::DatasetTransformer');
isa_ok($obj, 'Metamod::DatasetTransformer::Dataset2');
ok($obj->test, "test correct dataset2 file");
isa_ok($obj->transform, 'XML::LibXML::Document');

my $obj2 = new Metamod::DatasetTransformer::Dataset2('bla');
isa_ok($obj2, 'Metamod::DatasetTransformer::Dataset2');
is($obj2->test, 0, "test invalid file");


my $xmlStr2;
{
    open F, 'dataset.xml' or die "Cannot read dataset.xml: $!\n";
    local $/ = undef;
    $xmlStr2 = <F>;
    close F;
}
my $obj3 = new Metamod::DatasetTransformer::Dataset2($xmlStr2);
isa_ok($obj3, 'Metamod::DatasetTransformer::Dataset2');
is($obj3->test, 0, "test dataset file");
eval {
    $obj3->transform;
};
ok($@, "die on wrong transform");
