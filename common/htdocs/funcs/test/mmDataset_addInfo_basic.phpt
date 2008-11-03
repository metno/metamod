--TEST--
MM_Dataset setInfo function - basic test for MM_Dataset
--FILE--
<?php
require_once("../mmDataset.inc");
$ds = new MM_Dataset();
$ds->addInfo(array(
					"creationDate" => "1973-06-26T09:51:00Z",
					"ownertag" => "DAM",
					"name" => "DAM/ecmwf"));
var_dump($ds->getInfo());
?>
--EXPECT--
array(5) {
  ["name"]=>
  string(9) "DAM/ecmwf"
  ["status"]=>
  string(6) "active"
  ["creationDate"]=>
  string(20) "1973-06-26T09:51:00Z"
  ["ownertag"]=>
  string(3) "DAM"
  ["metadataFormat"]=>
  string(3) "MM2"
}
