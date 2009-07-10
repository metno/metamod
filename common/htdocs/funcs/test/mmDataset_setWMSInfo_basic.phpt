--TEST--
MM_Dataset setWMSInfo function - basic test for MM_Dataset setWMSInfo
--FILE--
<?php
require_once("../mmConfig.inc");
$mmConfig= MMConfig::getInstance('test_config.txt');
require_once("../mmDataset.inc");
$ds = new MM_Dataset();
$ds->addInfo(array('creationDate' => '1970-01-01T00:00:00Z', 'datestamp' => '1970-01-01T00:00:00Z'));
$ds->addMetadata(array("hallo" => array("world")));
$wmsInfo = "<myInfo type=\"1\">blabla</myInfo>";
$ds->setWMSInfo($wmsInfo);
var_dump($ds->getDS_XML());
var_dump($ds->getWMSInfo());
?>
--EXPECT--
string(459) "<?xml version="1.0" encoding="UTF-8"?>
<dataset xmlns="http://www.met.no/schema/metamod/dataset" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.met.no/schema/metamod/dataset https://wiki.met.no/_media/metamod/dataset.xsd">
  <info name="" status="active" creationDate="1970-01-01T00:00:00Z" datestamp="1970-01-01T00:00:00Z" ownertag="" metadataFormat="MM2"/>
<wmsInfo><myInfo type="1">blabla</myInfo></wmsInfo></dataset>
"
string(32) "<myInfo type="1">blabla</myInfo>"