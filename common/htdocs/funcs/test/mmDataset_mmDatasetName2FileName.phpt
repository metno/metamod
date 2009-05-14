--TEST--
MM_Dataset getInfo function - basic test for MM_Dataset
--FILE--
<?php
require_once("../mmConfig.inc");
$mmConfig= MMConfig::getInstance('test_config.txt');
require_once("../mmDataset.inc");
var_dump(mmDatasetName2FileName("DAMOC/test-xx-xx&xx"));
?>
--EXPECT--
string(25) "DAMOC/test-2dxx-2dxx-26xx"