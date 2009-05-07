--TEST--
MM_Dataset setInfo function - basic test for MM_Dataset
--FILE--
<?php
require_once("../mmConfig.inc");
$mmConfig= MMConfig::getInstance('test_config.txt');
require_once("../mmDataset.inc");
$ds = new MM_Dataset();
$ds->addInfo(array(
					"creationDate" => "1973-06-26T09:51:00Z",
					"datestamp" => "2009-01-12T13:32:39Z",
					"ownertag" => "DAM",
					"name" => "DAM/ecmwf"));
var_dump($ds->getInfo());
?>
--EXPECT--
array(6) {
  ["name"]=>
  string(9) "DAM/ecmwf"
  ["status"]=>
  string(6) "active"
  ["creationDate"]=>
  string(20) "1973-06-26T09:51:00Z"
  ["datestamp"]=>
  string(20) "2009-01-12T13:32:39Z"
  ["ownertag"]=>
  string(3) "DAM"
  ["metadataFormat"]=>
  string(3) "MM2"
}
