#! /usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../";

use Test::More tests => 8;
use Data::Dumper;

BEGIN{
    $ENV{METAMOD_MASTER_CONFIG} = "$FindBin::Bin/master_config.txt";
    $ENV{METAMOD_LOG4PERL_CONFIG} = "$FindBin::Bin/log4perl_config.ini";
    $ENV{METAMOD_SOURCE_DIRECTORY} = "$FindBin::Bin/../../..";
}

use Metamod::Config qw(:init_logger);

BEGIN {use_ok('Metamod::DatasetTransformer::ISO19115')};

my $DataDir = $FindBin::Bin.'/data/XML/';
my ($xmdStr, $xmlStr) = Metamod::DatasetTransformer::getFileContent($DataDir."exampleISO19115");

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