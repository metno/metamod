#! /usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../";

use Test::More tests => 11;
use Data::Dumper;

BEGIN {use_ok('Metamod::LonLatPoint')};

my $obj = new Metamod::LonLatPoint(179.123, 15.3);
isa_ok($obj, 'Metamod::LonLatPoint');

my @lonLat = (179.12345, 15.30005);
my $p2 = new Metamod::LonLatPoint(@lonLat);
is_deeply([$p2->getLonLat], \@lonLat, "getLonLat");

ok($obj->equals($p2), "equals");
ok($obj == $p2, "equals, overloaded");
my $p3 = new Metamod::LonLatPoint(123, -15);
ok(!$obj->equals($p3), "not equals");
ok($obj != $p3, "!= overloaded");

is($obj->toString, "179.12 15.30", "toString");
ok("$obj" eq "179.12 15.30", "\"\" overloaded"); 

eval {new Metamod::LonLatPoint(180.123, -91)};
if ($@) {
    ok(1, "fail outside range");
}
is(scalar Metamod::LonLatPoint::unique($obj, $p2, $p3, $obj), 2, "unique");