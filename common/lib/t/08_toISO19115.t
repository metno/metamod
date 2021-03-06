#! /usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../";

use Test::More tests => 12;
use Data::Dumper;
use Metamod::Config;


$ENV{METAMOD_XSLT_DIR} = "$FindBin::Bin/../../schema/";

my $config = Metamod::Config->new("$FindBin::Bin/master_config.txt");
$config->initLogger();

use_ok('Metamod::DatasetTransformer::ToISO19115', "foreignDataset2iso19115");

# iso -> iso
my $DataDir = $FindBin::Bin.'/data/XML/';
my $fds = Metamod::ForeignDataset->newFromFileAutocomplete($DataDir."exampleISO19115");
isa_ok($fds, 'Metamod::ForeignDataset');
isa_ok(Metamod::DatasetTransformer::autodetect($fds), 'Metamod::DatasetTransformer::ISO19115');

my $isoFds = foreignDataset2iso19115($fds);
is($isoFds, $fds, "iso returns without conversion");

# dif -> iso
$fds = Metamod::ForeignDataset->newFromFileAutocomplete($DataDir."exampleDIF");
isa_ok($fds, 'Metamod::ForeignDataset');
isa_ok(Metamod::DatasetTransformer::autodetect($fds), 'Metamod::DatasetTransformer::DIF');

my $isoFromDif = foreignDataset2iso19115($fds);
isa_ok($isoFromDif, 'Metamod::ForeignDataset');
my $dt = Metamod::DatasetTransformer::autodetect($isoFromDif);
isa_ok($dt, 'Metamod::DatasetTransformer::ISO19115');

 # mm2 -> dif
$fds = Metamod::ForeignDataset->newFromFileAutocomplete($DataDir."exampleMM2");
isa_ok($fds, 'Metamod::ForeignDataset');
isa_ok(Metamod::DatasetTransformer::autodetect($fds), 'Metamod::DatasetTransformer::MM2');

my $isoFromMM2 = foreignDataset2iso19115($fds);
isa_ok($isoFromMM2, 'Metamod::ForeignDataset');
my $dtm = Metamod::DatasetTransformer::autodetect($isoFromMM2);
isa_ok($dtm, 'Metamod::DatasetTransformer::ISO19115');
