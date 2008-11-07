--TEST--
MM_Dataset setQuadtree function - basic test for MM_Dataset setQuadtree
--FILE--
<?php
require_once("../mmDataset.inc");
$quadTree = array(11,112, 113);
$ds = new MM_Dataset();
$ds->addInfo(array('creationDate' => '1970-01-01T00:00:00Z'));
$ds->addMetadata(array("hallo" => array("world")));
$ds->setQuadtree($quadTree);
var_dump($ds->getDS_XML());
var_dump(array_diff($ds->getQuadtree(), $quadTree));
?>
--EXPECT--
string(477) "<?xml version="1.0" encoding="iso8859-1"?>
<?xml-stylesheet href="dataset.xsl" type="text/xsl"?>
<dataset xmlns="http://www.met.no/schema/metamod/dataset" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.met.no/schema/metamod/dataset https://wiki.met.no/_media/metamod/dataset.xsd">
  <info name="" status="active" creationDate="1970-01-01T00:00:00Z" ownertag="" metadataFormat="MM2"/>
<quadtree_nodes>11
112
113
</quadtree_nodes></dataset>
"
array(0) {
}
