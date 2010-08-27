#! /usr/bin/perl
use strict;
use warnings;

use lib "..";
use Test::More tests => 12;
use Data::Dumper;

BEGIN {$ENV{METAMOD_XSLT_DIR} = '../../schema/';}

BEGIN {use_ok('Metamod::DatasetTransformer::ToISO19115', "foreignDataset2iso19115")};

Log::Log4perl::init( "log4perl_config.ini" );

# iso -> iso
my $fds = Metamod::ForeignDataset->newFromFileAutocomplete("exampleISO19115");
isa_ok($fds, 'Metamod::ForeignDataset');
isa_ok(Metamod::DatasetTransformer::autodetect($fds), 'Metamod::DatasetTransformer::ISO19115');

my $isoFds = foreignDataset2iso19115($fds);
is($isoFds, $fds, "iso returns without conversion");

# dif -> iso
$fds = Metamod::ForeignDataset->newFromFileAutocomplete("exampleDIF");
isa_ok($fds, 'Metamod::ForeignDataset');
isa_ok(Metamod::DatasetTransformer::autodetect($fds), 'Metamod::DatasetTransformer::DIF');

my $isoFromDif = foreignDataset2iso19115($fds);
isa_ok($isoFromDif, 'Metamod::ForeignDataset');
my $dt = Metamod::DatasetTransformer::autodetect($isoFromDif);
isa_ok($dt, 'Metamod::DatasetTransformer::ISO19115');

 # mm2 -> dif
$fds = Metamod::ForeignDataset->newFromFileAutocomplete("exampleMM2");
isa_ok($fds, 'Metamod::ForeignDataset');
isa_ok(Metamod::DatasetTransformer::autodetect($fds), 'Metamod::DatasetTransformer::MM2');

my $isoFromMM2 = foreignDataset2iso19115($fds);
isa_ok($isoFromMM2, 'Metamod::ForeignDataset');
my $dtm = Metamod::DatasetTransformer::autodetect($isoFromMM2);
isa_ok($dtm, 'Metamod::DatasetTransformer::ISO19115'); 
 