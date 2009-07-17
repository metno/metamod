--TEST--
mmRetrieveNcURL() function - basic test for retrieval of nc-files via url
--FILE--
<?php
require_once("../mmConfig.inc");
$mmConfig = MMConfig::getInstance('test_config.txt');
require_once("../mmFimex.inc");
$input = "testInput.nc";
$output = "out.nc";
if (!mmRetrieveNcURL("file:$input", "$output", $errMsg)) {
   die("error $errMsg");
}
if (!file_exists($output)) {
   die("out.nc doesn't exists");
}
if (filesize($input) != filesize($output)) {
   die("filesize mismatch: input:".filesize($input)." <=> output:".filesize($output));
}
unlink($output);
?>
--EXPECT--
