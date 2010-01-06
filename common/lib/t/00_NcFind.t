#! -*- perl -*-
use strict;
use warnings;

use lib "..";
use Test::More tests => 13;

BEGIN {use_ok('MetNo::NcFind')};

my $nc = new MetNo::NcFind('test.nc');
isa_ok($nc, 'MetNo::NcFind');

my $ncX = new MetNo::NcFind($nc->{NCOBJ});
isa_ok($ncX, 'MetNo::NcFind');

my @globalAttributes = $nc->globatt_names;
is($globalAttributes[0], 'Conventions', "globatt_names");
my $globAttValue = $nc->globatt_value($globalAttributes[0]);
is($globAttValue, 'CF-1.0', "globatt_value");

my @variables = sort($nc->variables);
ok(eq_array(\@variables, ["lat","lon","test","time"]), "variables");
my $attValue = $nc->att_value("lat", "units");
is($attValue, "degree_north", "att_value");

my @latlons = sort $nc->findVariablesByAttributeValue("units", qr/degrees?_(north|south|east|west)/);
ok(eq_array(\@latlons, ["lat", "lon"]), "findVariablesByAttributeValue");

my @dimensions = $nc->dimensions("test");
is(scalar @dimensions, 3, "dimensions");
  
my ($longRef, $latRef) = $nc->get_lonlats('lon', 'lat');
ok(eq_array($longRef,[-180,0]), "longitude values");
ok(eq_array($latRef, [60,90]), "latitude values");

my @borderVals = sort {$a <=> $b} $nc->get_bordervalues("test");
ok(eq_array(\@borderVals, [1,1,2,2,3,3,4,4]), "border-values including corners twice");
my @vals = sort {$a <=> $b} $nc->get_values("test");
ok(eq_array(\@vals, [1,2,3,4]), "values");

