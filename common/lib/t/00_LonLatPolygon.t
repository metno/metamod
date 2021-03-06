#! /usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../";

use Test::More tests => 13;
use Data::Dumper;

BEGIN {use_ok('Metamod::LonLatPolygon')};

my $obj = new Metamod::LonLatPolygon([0,0],[0,0],[0,1],[0,1],[1,1],[1,0]);
isa_ok($obj, 'Metamod::LonLatPolygon');
is(scalar $obj->getPoints, 5, "two points removed, one added");

ok($obj->equals($obj), "equals identiy");
ok($obj == $obj, "equals overloaded");
my $obj2 = new Metamod::LonLatPolygon([0,0],[0,1],[1,1],[1,0],[0,0]);
ok($obj2 == $obj, "equals overloaded2");
ok(not($obj2 != $obj), "!=");

my $str = "0.00 0.00,0.00 1.00,1.00 1.00,1.00 0.00,0.00 0.00";
is($obj->toString, $str, "toString");
is("$obj", $str, "toString, overloaded");

my @points = $obj->getPoints;
isa_ok($points[0], 'Metamod::LonLatPoint');

my $projPol = $obj->toProjectablePolygon;
ok (scalar($projPol->getPoints) > scalar(@points), "toProjectablePolygon");

my $obj3 = new Metamod::LonLatPolygon([0,0],[0,1],[1,1],[1,0],[0.01,0.0]);
is($obj3->[0][0], $obj3->[-1][0], "first and last point are equal in first coordinate");
is($obj3->[0][1], $obj3->[-1][1], "first and last point are equal in second coordinate");
