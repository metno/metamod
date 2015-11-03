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
#use encoding 'iso8859-1';
use Encode qw(decode encode);

use FindBin;
use lib "$FindBin::Bin/../";

use Test::More tests => 51;

use Data::Dumper qw(Dumper);

BEGIN{
    $ENV{METAMOD_SOURCE_DIRECTORY} = "$FindBin::Bin/../../..";
}

use Metamod::Config;
my $config = Metamod::Config->new("$FindBin::Bin/master_config.txt");
$config->initLogger();

BEGIN {use_ok('Metamod::ForeignDataset')};
BEGIN {use_ok('Metamod::Dataset');}

my $string = pack('U4',"65","66","31","67");

=for deprecated
ok(Metamod::ForeignDataset::isXMLCharacter($string), "char is valid xml");
ok(!Metamod::ForeignDataset::isXMLCharacter(substr($string, 2)), "char invalid in xml");
=cut

is(Metamod::ForeignDataset::removeUndefinedXMLCharacters($string), "ABC", "remove undefined characters");
is(Metamod::ForeignDataset::removeUndefinedXMLCharacters(substr($string, 2)), "C", "remove undefined characters at beginning");

my $DataDir = $FindBin::Bin.'/data/XML/';
# short test of ForeignDataset, most tests in submodule Dataset
my $fds = Metamod::ForeignDataset->newFromFile($DataDir.'oldDataset.xml', ('format' => 'oldDataset'));
isa_ok($fds, 'Metamod::ForeignDataset');
ok($fds->getMETA_XML, "getMETA_XML");
is($fds->originalFormat, 'oldDataset', 'origFormat');

my $ds = new Metamod::Dataset;
isa_ok($ds, 'Metamod::ForeignDataset');
isa_ok($ds, 'Metamod::Dataset');
is($ds->originalFormat, 'MM2', "orignal format");

my %info = $ds->getInfo;
ok(exists $info{creationDate}, "getInfo, creationDate");
%info = ();
$info{'name'} = 'blub';
eval {$ds->setInfo(\%info);};
ok($@, "croak on wrong dataset-name");
$info{'name'} = 'project/blub';
eval {$ds->setInfo(\%info);};
%info = $ds->getInfo;
is($info{name}, 'project/blub', "setInfo, name");
ok(exists $info{creationDate}, "check no overwrite of creationDate");
is($ds->getParentName, undef, "get undef parent");
$info{name} = 'project/parent/blub';
$ds->setInfo(\%info);
%info = $ds->getInfo;
is($ds->getParentName, 'project/parent', "get defined parent");

my @quadTree = (1, 11, 111, 112);
ok(eq_array([], [$ds->setQuadtree(\@quadTree)]), "set quadtree");
ok(eq_array(\@quadTree, [$ds->getQuadtree]), "get quadtree");
ok($ds->_writeToFileHelper('test'), "_writeToFileHelper");
ok(-f 'test.xml', "xml file exists");
ok(-f 'test.xmd', "xmd file exists");

my $testFD = Metamod::ForeignDataset->newFromFile('test');
my $wmsInfo = '<wms><sdl type="1">blablub</sdl></wms>';
my $projectionInfo = '<fimexSetup name="bla">a long string</fimexSetup>';
ok(!$testFD->getWMSInfo, 'no WMSInfo yet');
ok(!$testFD->getProjectionInfo, 'no ProjectionInfo yet');
$testFD->setWMSInfo($wmsInfo); # throw exception
ok(1, 'adding WMSInfo'); # made it here
$testFD->setProjectionInfo($projectionInfo); # throw exception
ok(1, 'adding ProjectionInfo'); # made it here
ok( $testFD->getWMSInfo() =~ /$wmsInfo$/s, 'wmsInfo unchanged' );
ok( $testFD->getProjectionInfo() =~ /$projectionInfo$/s, 'projectionInfo unchanged');

my $region = new Metamod::DatasetRegion();
$region->addPoint([0, 0]);
$testFD->setDatasetRegion($region);
my $outRegion = $testFD->getDatasetRegion;
isa_ok($outRegion, 'Metamod::DatasetRegion');
ok($outRegion->equals($region), 'region put == region get');
my $str = $testFD->getXMD_XML();
ok($str =~ /<lonLatPoints/, 'dataset contains lonLatPoints');

ok(Metamod::ForeignDataset->deleteDatasetFile("test"), "delete dataset");
ok(! -f "test.xml", "test.xml deleted");
ok(! -f "test.xmd", "test.xmd deleted");

my @metaVals = qw(a b c);
my $umlauts = decode('iso8859-1', chr(248).chr(230).chr(252)); # decode('iso8859-1', "/o, ae, "u");
my %metadata = ("abc" => \@metaVals, umlauts => [$umlauts]);
$ds->addMetadata(\%metadata);
my %newMeta = $ds->getMetadata;
ok(exists $newMeta{'abc'}, "write and get metadata, name");
ok(eq_array($newMeta{'abc'}, \@metaVals), "write and get metadata, values");
ok($ds->_writeToFileHelper('test'), "_writeToFileHelper with umlauts");
$ds = newFromFile Metamod::Dataset('test.xml');
ok(ref $ds, "reading dataset with umlauts");
%newMeta = $ds->getMetadata;
is($newMeta{umlauts}[0], $umlauts, "correctly reading umlauts");
unlink "test.xml"; unlink "test.xmd";

my $dsClone = $ds->getXMD_DOC;
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

my $oldDs = eval { newFromFile Metamod::Dataset($DataDir.'oldDataset.xml') };
isa_ok($oldDs, 'Metamod::Dataset');
is(eval { $oldDs->originalFormat }, 'OldDataset', "old dataset: orignal format");
%metadata = eval { $oldDs->getMetadata };
is (scalar keys %metadata, 2, "reading old datasets metadata");
@quadTree = eval { $oldDs->getQuadtree };
is (scalar @quadTree, 4, "quadtree of old dataset");

my $newDs = newFromFile Metamod::Dataset($DataDir.'exampleMM2.xml');
isa_ok($newDs, 'Metamod::Dataset');
is($newDs->originalFormat, 'MM2', "MM2 dataset: orignal format");
%metadata = $newDs->getMetadata;
is (scalar keys %metadata, 1, "reading MM2 datasets metadata");
is (scalar $newDs->getQuadtree, 3, "reading quadtree of exampleMM2");

my $difDS = Metamod::ForeignDataset->newFromFileAutocomplete($DataDir.'exampleDIF');
isa_ok($difDS, 'Metamod::ForeignDataset');
