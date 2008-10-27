--TEST--
MM_Dataset2 setQuadtree function - basic test for MM_Dataset2 setQuadtree
--FILE--
<?php
require_once("../mmDataset2.inc");
$quadTree = array(11,112, 113);
$ds2 = new MM_Dataset2();
$ds2->addMetadata(array("hallo" => array("world")));
$ds2->setPeriod("2008-11-01T00:00:00Z", "2009-11-01T00:00:00Z");
$ds2->setQuadtree($quadTree);
var_dump($ds2->getXML());
var_dump(array_diff($ds2->getQuadtree(), $quadTree));
?>
--EXPECT--
string(557) "<?xml version="1.0" encoding="iso8859-1"?>
<?xml-stylesheet href="dataset2View.xsl" type="text/xsl"?>
<dataset xmlns="http://www.met.no/schema/metamod/dataset2/" xmlns:ns1="http://www.w3.org/2001/XMLSchema-instance" ns1:schemaLocation="http://www.met.no/schema/metamod/dataset2/ metamodDataset2.xsd">
  <info status="active" creationDate="1970-01-01T00:00:00Z" ownertag="" drpath=""/>
<datacollection_period to="2009-11-01T00:00:00Z" from="2008-11-01T00:00:00Z"/><quadtree_nodes>11
112
113
</quadtree_nodes><metadata name="hallo">world</metadata></dataset>
"
array(0) {
}
