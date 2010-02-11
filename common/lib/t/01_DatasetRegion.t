#! /usr/bin/perl
use strict;
use warnings;

use lib "..";
use Test::More tests => 22;
use Data::Dumper;

BEGIN {use_ok('Metamod::DatasetRegion')};

my $obj = new Metamod::DatasetRegion();
isa_ok($obj, 'Metamod::DatasetRegion');

my $xml = <<'EOT';
<?xml version="1.0" encoding="utf-8" ?>
<datasetRegion valid="true"
   xmlns="http://www.met.no/schema/metamod/datasetRegion"
   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
   xsi:schemaLocation="http://www.met.no/schema/metamod/datasetRegion https://wiki.met.no/_media/metamod/datasetRegion.xsd">
   <boundingBox north="90" south="60" east="30" west="-15" />
   <lonLatPoints>
   -10 0,-8 0, -6 0 
   </lonLatPoints>
   <lonLatPolygon>
   0 0, 0 1, 0 2, 0 3, 0 4, 0 5, 1 5, 2 5, 2 4, 2 3, 2 2, 2 1, 2 0, 1 0, 0 0 
   </lonLatPolygon>
</datasetRegion>
EOT

my $obj2 = new Metamod::DatasetRegion($xml);
isa_ok($obj2, 'Metamod::DatasetRegion');

my %bbox = $obj2->getBoundingBox;
is(scalar keys %bbox, 4, "boundingBox found");

is(scalar $obj2->getPoints, 3, "3 points added");
is(scalar $obj2->getPolygons,1, "1 polygon added");

$obj2->addPoint([-10, 0]);
$obj2->uniquePoints;
is(scalar $obj2->getPoints, 3, "3 points after add and unique");

$obj2->extendBoundingBox({north=>70, east=>40, west=>30, south=>-55});
my %bb = $obj2->getBoundingBox;
is_deeply(\%bb, {north=>90, east=>40, west=>-15, south=>-55}, "extendBoundingBox");

$obj2->addPolygon([[0,1],[0,3],[1,3],[1,1]]);
is(scalar $obj2->getPolygons, 2, "1 polygon added");
$obj2->uniquePolygons;
is(scalar $obj2->getPolygons, 2, "2 polygons even after unique");

ok($obj2->equals($obj2), "identity equals");

my $xmlOut = $obj2->toString;
ok($xmlOut =~ /\/lonLatPolygon/, "xml contains polygons");
ok($xmlOut =~ /\/lonLatPoints/, "xml contains points");

my $obj3 = new Metamod::DatasetRegion($xmlOut);
is($obj3->toString, $xmlOut, "double deserialization");
ok($obj3->equals($obj2), "serialized objects equals"); 

my $xml2 = <<'EOT';
<?xml version="1.0" encoding="utf-8" ?>
<otherDoc>
<datasetRegion
   xmlns="http://www.met.no/schema/metamod/datasetRegion"
   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
   xsi:schemaLocation="http://www.met.no/schema/metamod/datasetRegion https://wiki.met.no/_media/metamod/datasetRegion.xsd">
   <boundingBox north="90" south="60" east="30" west="-15" />
   <lonLatPoints>
   -10 0,-8 0, -6 0 
   </lonLatPoints>
   <lonLatPolygon>
   0 0, 0 1, 0 2, 0 3, 0 4, 0 5, 1 5, 2 5, 2 4, 2 3, 2 2, 2 1, 2 0, 1 0, 0 0 
   </lonLatPolygon>
</datasetRegion>
</otherDoc>
EOT

my $xmlDoc = XML::LibXML->new->parse_string($xml2);
my $obj4 = new Metamod::DatasetRegion($xmlDoc);
isa_ok($obj4, 'Metamod::DatasetRegion');
is(scalar $obj4->getPoints, 3, 'successfully intialized by xmldoc');

ok($obj4->valid, "valid");
$obj4->setInvalid;
ok(!$obj4->valid, "invalid");
ok($obj3->valid, "obj3 valid");
$obj3->addRegion($obj4);
ok(!$obj3->valid, "invalid propagates with addRegion");

my $obj5 = new Metamod::DatasetRegion(XML::LibXML->new->parse_string($obj4->toString));
ok(!$obj5->valid, "invalid to disk and back again"); 