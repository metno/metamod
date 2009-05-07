--TEST--
MM_Dataset removeMetadata function - basic test for MM_Dataset removeMetadata
--FILE--
<?php
require_once("../mmConfig.inc");
$mmConfig= MMConfig::getInstance('test_config.txt');
require_once("../mmDataset.inc");
$ds2 = new MM_Dataset();
$ds2->addMetadata(array("hallo" => array("world")));
$ds2->removeMetadata(array("hallo"));
var_dump($ds2->getMM2_XML());
?>
--EXPECT--
string(252) "<?xml version="1.0" encoding="UTF-8"?>
<MM2 xmlns="http://www.met.no/schema/metamod/MM2" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.met.no/schema/metamod/MM2 https://wiki.met.no/_media/metamod/mm2.xsd">
</MM2>
"
