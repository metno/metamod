#! /usr/bin/perl
use strict;
use warnings;

use lib "..";
use Test::More tests => 9;
use Data::Dumper;

BEGIN {$ENV{METAMOD_XSLT_DIR} = '../../schema/';}

BEGIN {use_ok('Metamod::DatasetTransformer::ToDIF', "foreignDataset2Dif")};

Log::Log4perl::init( "log4perl_config.ini" );

my $fds = Metamod::ForeignDataset->newFromFileAutocomplete("exampleDIF");
isa_ok($fds, 'Metamod::ForeignDataset');

# dif -> dif
my $difFds = foreignDataset2Dif($fds);
is($difFds, $fds, "dif returns without conversion");

# iso -> dif
$fds = Metamod::ForeignDataset->newFromFileAutocomplete("exampleISO19115");
isa_ok($fds, 'Metamod::ForeignDataset');

my $difFromISO = foreignDataset2Dif($fds);
isa_ok($difFromISO, 'Metamod::ForeignDataset');
my $dti = Metamod::DatasetTransformer::autodetect($difFromISO);
isa_ok($dti, 'Metamod::DatasetTransformer::DIF'); 

# mm2 -> dif
$fds = Metamod::ForeignDataset->newFromFileAutocomplete("exampleMM2");
isa_ok($fds, 'Metamod::ForeignDataset');

my $difFromMM2 = foreignDataset2Dif($fds);
isa_ok($difFromMM2, 'Metamod::ForeignDataset');
my $dtm = Metamod::DatasetTransformer::autodetect($difFromMM2);
isa_ok($dtm, 'Metamod::DatasetTransformer::DIF'); 

