#! /usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../";

use Test::More tests => 1 + 26*2;
use Data::Dumper;

BEGIN {use_ok('MetNo::NcFind')};

my $DataDir = $FindBin::Bin . '/data/';

for my $file (qw(test.nc test.nc4)) {

    my $nc = new MetNo::NcFind($DataDir.$file);
    isa_ok($nc, 'MetNo::NcFind');

    my $ncX = new MetNo::NcFind($nc->{NCOBJ});
    isa_ok($ncX, 'MetNo::NcFind');

    my @globalAttributes = $nc->globatt_names;
    ok(scalar(grep {$_ eq 'Conventions'} @globalAttributes), "globatt_names");
    my $globAttValue = $nc->globatt_value('Conventions');
    is($globAttValue, 'CF-1.0', "globatt_value");
    my $voidGlobAtt = $nc->globatt_value('void');
    ok(!defined $voidGlobAtt, "reading undefined global attribute");

    my @variables = sort($nc->variables);
    is_deeply(\@variables, ["lat","lon","test","test2","time"], "variables");
    my $attValue = $nc->att_value("lat", "units");
    is($attValue, "degree_north", "att_value");

    my $voidAtt = $nc->att_value("lat", "void");
    ok(!defined $voidAtt, "reading undefined attribute");
    $voidAtt = $nc->att_value("void", "void");
    ok(!defined $voidAtt, "reading attribute ov undefined variable");


    my @latlons = sort $nc->findVariablesByAttributeValue("units", qr/degrees?_(north|south|east|west)/);
    is_deeply(\@latlons, ["lat", "lon"], "findVariablesByAttributeValue");

    my @test = $nc->findVariablesByAttributeValue("xxx", qr/degrees?_(north|south|east|west)/);
    ok(@test == 0, "searching for non-existing attribute");

    my @latLonVars = $nc->findVariablesByDimensions(['lat','lon']);
    is_deeply(\@latLonVars, ['test','test2'], "finding var(lat,lon,??) variables");
    my @lonVars = sort $nc->findVariablesByDimensions(['lon']);
    is_deeply(\@lonVars, ['lon', 'test', 'test2'], "finding var('lon') variables");

    my @dimensions = $nc->dimensions("test2");
    is(scalar @dimensions, 2, "dimensions");

    my @allDims = $nc->dimensions();
    is(scalar @allDims, 3, "all dimensions");

    is($nc->dimensionSize('lat'), 2, "lat dimsize");
    is($nc->dimensionSize('time'), 1, "time dimsize");

    my ($longRef, $latRef) = $nc->get_lonlats('lon', 'lat');
    is_deeply($longRef,[-180,0], "longitude values");
    is_deeply($latRef, [60,90], "latitude values");

    ($longRef, $latRef) = $nc->get_lonlats('falselons', 'falselats');
    ok((@$longRef + @$latRef) == 0, "lons and lats empty on erroneous parameter");

    my @borderVals = sort {$a <=> $b} $nc->get_bordervalues("test2");
    is_deeply(\@borderVals, [1,1,2,2,3,3,4,4], "border-values including corners twice");
    my @vals = sort {$a <=> $b} $nc->get_values("test2");
    is_deeply(\@vals, [1,2,3,4], "get_values");

    #$MetNo::NcFind::DEBUG = 1;
    my %bb = $nc->findBoundingBoxByGlobalAttributes(qw(northernmost_latitude southernmost_latitude easternmost_longitude westernmost_longitude));
    ok(4 == keys %bb, "findBoundinbBoxByGlobalAttributes found");
    is_deeply(\%bb, {north => 80, south => 60, east => 20, west => -10}, "findBoundingBoxByGlobalAttributes values");

    my %lonLat = $nc->extractCFLonLat();
    ok((0 == @{$lonLat{errors}}), "no errors with extractCFLonLat");
    my $expArray = [[-180,60],[0,60],[0,60],[0,90],[0,90],[-180,90],[-180,90],[-180,60]];
    is_deeply($lonLat{polygons}[0], $expArray, "extractCFLonLat for polygons");

}
