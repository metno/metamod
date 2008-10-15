--TEST--
readDataset() function - basic test for readDataset
--FILE--
<?php
require_once("../readDataset.inc");
list($ownertag,$ds) = mmReadEssentialDataset("dataset.xml");
var_dump($ds);
?>
--EXPECT--
array(2) {
  ["metadata"]=>
  array(1) {
    [0]=>
    string(6) "mvalue"
  }
  ["metadata2"]=>
  array(1) {
    [0]=>
    string(7) "m2value"
  }
}

