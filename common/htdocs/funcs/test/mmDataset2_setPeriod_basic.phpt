--TEST--
MM_Dataset2 setPeriod function - basic test for MM_Dataset2 setPeriod
--FILE--
<?php
require_once("../mmDataset2.inc");
$ds2 = new MM_Dataset2();
$ds2->addMetadata(array("hallo" => array("world")));
$ds2->setPeriod("2008-11-01T00:00:00Z", "2009-11-01T00:00:00Z");
var_dump($ds2->getXML());
?>
--EXPECT--
string(513) "<?xml version="1.0" encoding="iso8859-1"?>
<?xml-stylesheet href="dataset2View.xsl" type="text/xsl"?>
<dataset xmlns="http://www.met.no/schema/metamod/dataset2/" xmlns:ns1="http://www.w3.org/2001/XMLSchema-instance" ns1:schemaLocation="http://www.met.no/schema/metamod/dataset2/ metamodDataset2.xsd">
  <info status="active" creationDate="1970-01-01T00:00:00Z" ownertag="" drpath=""/>
<datacollection_period to="2009-11-01T00:00:00Z" from="2008-11-01T00:00:00Z"/><metadata name="hallo">world</metadata></dataset>
"
