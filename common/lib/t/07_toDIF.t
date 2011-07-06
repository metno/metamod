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

use_ok('Metamod::DatasetTransformer::ToDIF', "foreignDataset2Dif");

my $DataDir = $FindBin::Bin.'/data/XML/';
my $fds = Metamod::ForeignDataset->newFromFileAutocomplete($DataDir."exampleDIF");
isa_ok($fds, 'Metamod::ForeignDataset');
isa_ok(Metamod::DatasetTransformer::autodetect($fds), 'Metamod::DatasetTransformer::DIF');

# dif -> dif
my $difFds = foreignDataset2Dif($fds);
is($difFds, $fds, "dif returns without conversion");

# iso -> dif
$fds = Metamod::ForeignDataset->newFromFileAutocomplete($DataDir."exampleISO19115");
isa_ok($fds, 'Metamod::ForeignDataset');
isa_ok(Metamod::DatasetTransformer::autodetect($fds), 'Metamod::DatasetTransformer::ISO19115');

my $difFromISO = foreignDataset2Dif($fds);
isa_ok($difFromISO, 'Metamod::ForeignDataset');
my $dti = Metamod::DatasetTransformer::autodetect($difFromISO);
isa_ok($dti, 'Metamod::DatasetTransformer::DIF');

# mm2 -> dif
$fds = Metamod::ForeignDataset->newFromFileAutocomplete($DataDir."exampleMM2");
isa_ok($fds, 'Metamod::ForeignDataset');
isa_ok(Metamod::DatasetTransformer::autodetect($fds), 'Metamod::DatasetTransformer::MM2');

my $difFromMM2 = foreignDataset2Dif($fds);
isa_ok($difFromMM2, 'Metamod::ForeignDataset');
my $dtm = Metamod::DatasetTransformer::autodetect($difFromMM2);
isa_ok($dtm, 'Metamod::DatasetTransformer::DIF');

