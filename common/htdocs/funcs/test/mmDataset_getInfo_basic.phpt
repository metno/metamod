--TEST--
MM_Dataset getInfo function - basic test for MM_Dataset
--FILE--
<?php
require_once("../mmDataset.inc");
$ds = new MM_Dataset();
$info = $ds->getInfo();
var_dump($info);
?>
--EXPECT--
array(5) {
  ["name"]=>
  string(0) ""
  ["status"]=>
  string(6) "active"
  ["creationDate"]=>
  string(20) "1970-01-01T00:00:00Z"
  ["ownertag"]=>
  string(0) ""
  ["metadataFormat"]=>
  string(3) "MM2"
}
