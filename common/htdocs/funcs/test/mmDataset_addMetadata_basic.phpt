--TEST--
MM_Dataset getMetadata function - basic test for MM_Dataset getMetadata
--FILE--
<?php
require_once("../mmConfig.inc");
$mmConfig= MMConfig::getInstance('test_config.txt');
require_once("../mmDataset.inc");
$ds = new MM_Dataset();
$ds->addMetadata(array("hallo" => array("world")));
var_dump($ds->getMM2_XML());
?>
--EXPECT--
string(291) "<?xml version="1.0" encoding="UTF-8"?>
<MM2 xmlns="http://www.met.no/schema/metamod/MM2" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.met.no/schema/metamod/MM2 https://wiki.met.no/_media/metamod/mm2.xsd">
<metadata name="hallo">world</metadata></MM2>
"
