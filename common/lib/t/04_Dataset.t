#! -*- perl -*-
use strict;
use warnings;

use lib "..";
use Test::More tests => 16;

use Data::Dumper qw(Dumper);

# test-xslt location
my $xsltDS = "../../schema/oldDataset2Dataset.xslt";
my $xsltMM2 = "../../schema/oldDataset2MM2.xslt";


BEGIN {use_ok('Metamod::Dataset');}

my $ds = new Metamod::Dataset;
isa_ok($ds, 'Metamod::Dataset');
is($ds->originalFormat, 'MM2', "orignal format");

my %info = $ds->getInfo;
ok(exists $info{creationDate}, "getInfo, creationDate");
$info{name} = 'blub';
$ds->setInfo(\%info);
%info = $ds->getInfo;
is($info{name}, 'blub', "setInfo, name");
my @quadTree = (1, 11, 111, 112);
ok(eq_array([], [$ds->setQuadtree(\@quadTree)]), "set quadtree");
ok(eq_array(\@quadTree, [$ds->getQuadtree]), "get quadtree");
ok($ds->writeToFile('test'), "writeToFile");
ok(-f 'test.xml', "xml file exists");
ok(-f 'test.xmd', "xmd file exists");
unlink "test.xml"; unlink "test.xmd";

my @metaVals = qw(a b c);
my %metadata = ("abc" => \@metaVals);
$ds->addMetadata(\%metadata);
my %newMeta = $ds->getMetadata;
ok(exists $newMeta{'abc'}, "write and get metadata, name");
ok(eq_array($newMeta{'abc'}, \@metaVals), "write and get metadata, values");

my @oldVals = $ds->removeMetadataName('abc');
ok(eq_array(\@oldVals, \@metaVals), "removeMetadataName, oldValues");
@oldVals = $ds->removeMetadataName('abc');
ok(eq_array(\@oldVals, []), "removeMetadataName, really gone");

my $oldDs = newFromFile Metamod::Dataset('oldDataset.xml', 'dsXslt' => $xsltDS, 'mm2Xslt' => $xsltMM2);
isa_ok($oldDs, 'Metamod::Dataset');
is($oldDs->originalFormat, 'OldDataset', "old dataset: orignal format");
