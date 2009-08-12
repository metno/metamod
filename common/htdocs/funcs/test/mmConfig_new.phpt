--TEST--
MMConfig new - basic test for MMConfig
--FILE--
<?php
require_once("../mmConfig.inc");
var_dump(MMConfig::getDefaultConfigFile());
$config = MMConfig::getInstance("test_config.txt");
#var_dump($config);
var_dump($config->getVar("TARGET_DIRECTORY"));
var_dump($config->getVar("TEST_SUBSTITUTION", 'htdocs/qst/quest.php', __FILE__));
?>
--EXPECT--
string(23) "../../master_config.txt"
string(8) "../../.."
string(4) "test"