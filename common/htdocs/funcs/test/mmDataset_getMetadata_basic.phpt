--TEST--
MM_Dataset getMetadata function - basic test for MM_Dataset getMetadata
--FILE--
<?php
require_once("../mmConfig.inc");
$mmConfig= MMConfig::getInstance('test_config.txt');
require_once("../mmDataset.inc");
$ds = new MM_Dataset();
$ds->addMetadata(array("hallo" => array("world")));
var_dump($ds->getMetadata());
?>
--EXPECT--
array(1) {
  ["hallo"]=>
  array(1) {
    [0]=>
    string(5) "world"
  }
}
