--TEST--
MM_Dataset setInfo function - basic test for MM_Dataset
--FILE--
<?php
require_once("../mmDataset.inc");
$basename = mmGetBasename("dataset.xml");
var_dump($basename);
list($xmdContent, $xmlContent) = mmGetDatasetFileContent($basename);
var_dump(strlen($xmdContent));
var_dump(strlen($xmlContent));
$ds = new MM_Dataset("dataset.xmd", "dataset.xml");
$info = $ds->getInfo();
var_dump($info["name"]);
$ds2 = new MM_Dataset($xmdContent, $xmlContent,true);
$info2 = $ds2->getInfo();
var_dump($info2["name"]);
?>
--EXPECT--
string(7) "dataset"
int(621)
int(291)
string(10) "DAMOC/test"
string(10) "DAMOC/test"