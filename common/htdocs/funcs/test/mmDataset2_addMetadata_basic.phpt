--TEST--
MM_Dataset2 getMetadata function - basic test for MM_Dataset2 getMetadata
--FILE--
<?php
require_once("../mmDataset2.inc");
$ds2 = new MM_Dataset2();
$ds2->addMetadata(array("hallo" => array("world")));
var_dump($ds2->getXML());
?>
--EXPECT--
string(435) "<?xml version="1.0" encoding="iso8859-1"?>
<?xml-stylesheet href="dataset2View.xsl" type="text/xsl"?>
<dataset xmlns="http://www.met.no/schema/metamod/dataset2/" xmlns:ns1="http://www.w3.org/2001/XMLSchema-instance" ns1:schemaLocation="http://www.met.no/schema/metamod/dataset2/ metamodDataset2.xsd">
  <info status="active" creationDate="1970-01-01T00:00:00Z" ownertag="" drpath=""/>
<metadata name="hallo">world</metadata></dataset>
"
