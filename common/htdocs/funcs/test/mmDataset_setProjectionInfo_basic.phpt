--TEST--
MM_Dataset setProjectionInfo function - basic test for MM_Dataset setProjectionInfo
--FILE--
<?php
require_once("../mmConfig.inc");
$mmConfig= MMConfig::getInstance('test_config.txt');
require_once("../mmDataset.inc");
$ds = new MM_Dataset();
$ds->addInfo(array('creationDate' => '1970-01-01T00:00:00Z', 'datestamp' => '1970-01-01T00:00:00Z'));
$ds->addMetadata(array("hallo" => array("world")));
$piInfo = "<myInfo type=\"1\">blabla</myInfo>";
$ds->setProjectionInfo($piInfo);
var_dump($ds->getDS_XML());
var_dump($ds->getProjectionInfo());
$piInfo = <<<EOT
<fimexProjections>
<projection name="Lat/Long" method="nearestghbor" urlRegex="">
<projString></projString>
<xAxis></xAxis>
<yAxis></yAxis>
</projection>
</fimexProjections>
EOT;
if (!$ds->setProjectionInfo($piInfo)) {
   echo $ds->getProjectionInfo();
}
?>
--EXPECT--
string(473) "<?xml version="1.0" encoding="UTF-8"?>
<dataset xmlns="http://www.met.no/schema/metamod/dataset" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.met.no/schema/metamod/dataset https://wiki.met.no/_media/metamod/dataset.xsd">
  <info name="" status="active" creationDate="1970-01-01T00:00:00Z" datestamp="1970-01-01T00:00:00Z" ownertag="" metadataFormat="MM2"/>
<projectionInfo><myInfo type="1">blabla</myInfo></projectionInfo></dataset>
"
string(32) "<myInfo type="1">blabla</myInfo>"