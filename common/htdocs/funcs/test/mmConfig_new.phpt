--TEST--
MMConfig new - basic test for MMConfig
--FILE--
<?php
require_once("../mmConfig.inc");
var_dump(MMConfig::getDefaultConfigFile());
$config = MMConfig::getInstance("test_config.txt");
var_dump($config);
var_dump($config->getVar("TARGET_DIRECTORY"));
?>
--EXPECT--
string(23) "../../master_config.txt"
object(MMConfig)#1 (2) {
  ["filename:private"]=>
  string(78) "/home/heikok/Programme/MetSis/Metamod/common/htdocs/funcs/test/test_config.txt"
  ["vars:private"]=>
  array(7) {
    ["BASE_DIRECTORY"]=>
    string(14) "/home/someuser"
    ["WEBRUN_DIRECTORY"]=>
    string(1) "."
    ["TARGET_DIRECTORY"]=>
    string(28) "[==BASE_DIRECTORY==]/example"
    ["LOGFILE"]=>
    string(34) "[==WEBRUN_DIRECTORY==]/databaselog"
    ["PHPLOGFILE"]=>
    string(29) "[==WEBRUN_DIRECTORY==]/phplog"
    ["PHPLOGLEVEL"]=>
    string(5) "DEBUG"
    ["TEST_IMPORT_SPEEDUP"]=>
    string(0) ""
  }
}
string(22) "/home/someuser/example"