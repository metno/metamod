#! /usr/bin/perl
use strict;
use warnings;


use FindBin;
use lib "$FindBin::Bin/../..";

use Test::More tests => 5;
use Data::Dumper;

BEGIN {use_ok('MetNo::Fimex')};

$MetNo::Fimex::DEBUG = 2;

my %args = (
    'input.file' => 'input.nc',
    'output.file' => 'output.nc',
    'interpolate.projString' => 'proj=stere lat_0=90 lon_0=-32 lat_ts=60',
    'interpolate.metricAxes' => 1,
    'interpolate.xAxisValues' => '300000,350000,...,700000',
    'interpolate.yAxisValues' => '300000,350000,...,700000',
);

my $command = MetNo::Fimex::projectFile(%args);
my $expected = 'fimex --input.file input.nc --input.type nc --interpolate.method nearestneighbor --interpolate.projString proj=stere lat_0=90 lon_0=-32 lat_ts=60 --interpolate.xAxisUnit m --interpolate.xAxisValues 300000,350000,...,700000 --interpolate.yAxisUnit m --interpolate.yAxisValues 300000,350000,...,700000 --output.file output.nc --output.type nc';
is($command, $expected, 'call projectFile');

my $obj = new MetNo::Fimex();
isa_ok($obj, 'MetNo::Fimex');

$obj->inputFile('input.nc');
is ($obj->inputFile, 'input.nc', 'inputFile');
$obj->outputFile('output.nc');
$obj->outputDirectory(''); # current
$obj->projString('proj=stere lat_0=90 lon_0=-32 lat_ts=60');
$obj->metricAxes(1);
$obj->xAxisValues('300000,350000,...,700000');
$obj->yAxisValues('300000,350000,...,700000');

my $fiCommand = $obj->doWork;
is($fiCommand, $expected, 'call doWork');