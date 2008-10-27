--TEST--
MM_Dataset2 setInfo function - basic test for MM_Dataset2
--FILE--
<?php
require_once("../mmDataset2.inc");
$ds2 = new MM_Dataset2();
$ds2->addInfo(array(
					"creationDate" => "1973-06-26T09:51:00Z",
					"ownertag" => "DAM",
					"drpath" => "DAM/ecmwf"));
var_dump($ds2->getInfo());
?>
--EXPECT--
array(4) {
  ["status"]=>
  string(6) "active"
  ["creationDate"]=>
  string(20) "1973-06-26T09:51:00Z"
  ["ownertag"]=>
  string(3) "DAM"
  ["drpath"]=>
  string(9) "DAM/ecmwf"
}