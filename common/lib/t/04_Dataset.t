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

use lib "..";
use Test::More tests => 33;

use Data::Dumper qw(Dumper);

# test-xslt location
my $xsltDS = "../../schema/oldDataset2Dataset.xslt";
my $xsltMM2 = "../../schema/oldDataset2MM2.xslt";

BEGIN {use_ok('Metamod::ForeignDataset')};
BEGIN {use_ok('Metamod::Dataset');}

my $string = pack('U4',"65","66","31","67");
ok(Metamod::ForeignDataset::isXMLCharacter($string), "char is valid xml");
ok(!Metamod::ForeignDataset::isXMLCharacter(substr($string, 2)), "char invalid in xml");
is(Metamod::ForeignDataset::removeUndefinedXMLCharacters($string), "ABC", "remove undefined characters");
is(Metamod::ForeignDataset::removeUndefinedXMLCharacters(substr($string, 2)), "C", "remove undefined characters at beginning");

# short test of ForeignDataset, most tests in submodule Dataset
my $fds = Metamod::ForeignDataset->newFromFile('oldDataset.xml', ('format' => 'oldDataset'));
isa_ok($fds, 'Metamod::ForeignDataset');
ok($fds->getMETA_XML, "getMETA_XML");
is($fds->originalFormat, 'oldDataset');

my $ds = new Metamod::Dataset;
isa_ok($ds, 'Metamod::ForeignDataset');
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

my $dsClone = $ds->getDS_DOC;
my $mmClone = $ds->getMETA_DOC;
my $dsc = Metamod::Dataset->newFromDoc($mmClone, $dsClone);
my %oldHash = $ds->getInfo;
my %newHash = $dsc->getInfo;
ok(eq_hash(\%oldHash, \%newHash), "compare clone with ds");
%oldHash = $ds->getMetadata;
%newHash = $dsc->getMetadata;
ok(eq_hash(\%oldHash, \%newHash), "compare clone with ds, metadata");

my @oldVals = $ds->removeMetadataName('abc');
ok(eq_array(\@oldVals, \@metaVals), "removeMetadataName, oldValues");
@oldVals = $ds->removeMetadataName('abc');
ok(eq_array(\@oldVals, []), "removeMetadataName, really gone");

my $oldDs = newFromFile Metamod::Dataset('oldDataset.xml', 'dsXslt' => $xsltDS, 'mm2Xslt' => $xsltMM2);
isa_ok($oldDs, 'Metamod::Dataset');
is($oldDs->originalFormat, 'OldDataset', "old dataset: orignal format");
%metadata = $oldDs->getMetadata;
is (scalar keys %metadata, 2, "reading old datasets metadata");
@quadTree = $oldDs->getQuadtree;
is (scalar @quadTree, 4, "quadtree of old dataset");

my $newDs = newFromFile Metamod::Dataset('exampleMM2.xml');
isa_ok($newDs, 'Metamod::Dataset');
is($newDs->originalFormat, 'MM2', "MM2 dataset: orignal format");
%metadata = $newDs->getMetadata;
is (scalar keys %metadata, 1, "reading MM2 datasets metadata");
is (scalar $newDs->getQuadtree, 3, "reading quadtree of exampleMM2");
