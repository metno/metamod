--TEST--
MM_Dataset2 getMetadata function - basic test for MM_Dataset2 getMetadata
--FILE--
<?php
require_once("../mmDataset2.inc");
$ds2 = new MM_Dataset2();
$ds2->addMetadata(array("hallo" => array("world")));
var_dump($ds2->getMetadata());
?>
--EXPECT--
array(1) {
  ["hallo"]=>
  array(1) {
    [0]=>
    string(5) "world"
  }
}
