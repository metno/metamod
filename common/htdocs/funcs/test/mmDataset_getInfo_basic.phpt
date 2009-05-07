--TEST--
MM_Dataset getInfo function - basic test for MM_Dataset
--FILE--
<?php
require_once("../mmConfig.inc");
$mmConfig= MMConfig::getInstance('test_config.txt');
require_once("../mmDataset.inc");
$ds = new MM_Dataset();
$ds->addInfo(array('creationDate' => '1970-01-01T00:00:00Z','datestamp' => '1970-01-01T00:00:00Z'
));
$info = $ds->getInfo();
var_dump($info);
?>
--EXPECT--
array(6) {
  ["name"]=>
  string(0) ""
  ["status"]=>
  string(6) "active"
  ["creationDate"]=>
  string(20) "1970-01-01T00:00:00Z"
  ["datestamp"]=>
  string(20) "1970-01-01T00:00:00Z"
  ["ownertag"]=>
  string(0) ""
  ["metadataFormat"]=>
  string(3) "MM2"
}
