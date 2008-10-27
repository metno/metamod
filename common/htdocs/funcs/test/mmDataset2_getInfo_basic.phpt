--TEST--
MM_Dataset2 getInfo function - basic test for MM_Dataset2
--FILE--
<?php
require_once("../mmDataset2.inc");
$ds2 = new MM_Dataset2();
$info = $ds2->getInfo();
var_dump($info);
?>
--EXPECT--
array(4) {
  ["status"]=>
  string(6) "active"
  ["creationDate"]=>
  string(20) "1970-01-01T00:00:00Z"
  ["ownertag"]=>
  string(0) ""
  ["drpath"]=>
  string(0) ""
}
