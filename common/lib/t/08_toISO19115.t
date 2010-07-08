#! /usr/bin/perl
use strict;
use warnings;

use lib "..";
use Test::More tests => 6;
use Data::Dumper;

BEGIN {$ENV{METAMOD_XSLT_DIR} = '../../schema/';}

BEGIN {use_ok('Metamod::DatasetTransformer::ToISO19115', "foreignDataset2iso19115")};

Log::Log4perl::init( "log4perl_config.ini" );


my $fds = Metamod::ForeignDataset->newFromFileAutocomplete("exampleISO19115");
isa_ok($fds, 'Metamod::ForeignDataset');

my $isoFds = foreignDataset2iso19115($fds);
is($isoFds, $fds, "iso returns without conversion");

$fds = Metamod::ForeignDataset->newFromFileAutocomplete("exampleDIF");
isa_ok($fds, 'Metamod::ForeignDataset');

my $isoFromDif = foreignDataset2iso19115($fds);
isa_ok($isoFromDif, 'Metamod::ForeignDataset');
my $dt = Metamod::DatasetTransformer::autodetect($isoFromDif);
isa_ok($dt, 'Metamod::DatasetTransformer::ISO19115'); 