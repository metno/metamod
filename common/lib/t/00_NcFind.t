#! -*- perl -*-
use strict;
use warnings;

use lib "..";
use Test::More tests => 23;

BEGIN {use_ok('MetNo::NcFind')};

my $nc = new MetNo::NcFind('test.nc');
isa_ok($nc, 'MetNo::NcFind');

my $ncX = new MetNo::NcFind($nc->{NCOBJ});
isa_ok($ncX, 'MetNo::NcFind');

my @globalAttributes = $nc->globatt_names;
is($globalAttributes[0], 'Conventions', "globatt_names");
my $globAttValue = $nc->globatt_value($globalAttributes[0]);
is($globAttValue, 'CF-1.0', "globatt_value");
my $voidGlobAtt = $nc->globatt_value('void');
ok(!defined $voidGlobAtt, "reading undefined global attribute");

my @variables = sort($nc->variables);
ok(eq_array(\@variables, ["lat","lon","test","test2","time"]), "variables");
my $attValue = $nc->att_value("lat", "units");
is($attValue, "degree_north", "att_value");

my $voidAtt = $nc->att_value("lat", "void");
ok(!defined $voidAtt, "reading undefined attribute");
$voidAtt = $nc->att_value("void", "void");
ok(!defined $voidAtt, "reading attribute ov undefined variable");


my @latlons = sort $nc->findVariablesByAttributeValue("units", qr/degrees?_(north|south|east|west)/);
ok(eq_array(\@latlons, ["lat", "lon"]), "findVariablesByAttributeValue");

my @test = $nc->findVariablesByAttributeValue("xxx", qr/degrees?_(north|south|east|west)/);
ok(@test == 0, "searching for non-existing attribute");

my @latLonVars = $nc->findVariablesByDimensions(['lat','lon']);
ok(eq_array(\@latLonVars, ['test','test2']), "finding var(lat,lon,??) variables");
my @lonVars = sort $nc->findVariablesByDimensions(['lon']);
ok(eq_array(\@lonVars, ['lon', 'test', 'test2']), "finding var('lon') variables");

my @dimensions = $nc->dimensions("test2");
is(scalar @dimensions, 2, "dimensions");

my @allDims = $nc->dimensions();
is(scalar @allDims, 3, "all dimensions");

is($nc->dimensionSize('lat'), 2, "lat dimsize");
is($nc->dimensionSize('time'), 1, "time dimsize"); 

my ($longRef, $latRef) = $nc->get_lonlats('lon', 'lat');
ok(eq_array($longRef,[-180,0]), "longitude values");
ok(eq_array($latRef, [60,90]), "latitude values");

($longRef, $latRef) = $nc->get_lonlats('falselons', 'falselats');
ok((@$longRef + @$latRef) == 0, "lons and lats empty on erroneous parameter");

my @borderVals = sort {$a <=> $b} $nc->get_bordervalues("test2");
ok(eq_array(\@borderVals, [1,1,2,2,3,3,4,4]), "border-values including corners twice");
my @vals = sort {$a <=> $b} $nc->get_values("test2");
ok(eq_array(\@vals, [1,2,3,4]), "values");

