--TEST--
mmFimexProjectFile() function - test for reprojection by fimex
--FILE--
<?php
require_once("../mmConfig.inc");
$mmConfig = MMConfig::getInstance('test_config.txt');
require_once("../mmFimex.inc");
$output = "testOutput.nc";
if (! mmFimexProjectFile("testInput.nc", "netcdf",
                         $output, "netcdf",
                         "nearestneighbor", "+proj=latlong +elips=sphere +a=6371000 +e=0",
                         "-60,-59,-58,...,-30", "50,51,52,...,70", false, $errMsg)) {
	die("error reprojecting: $errMsg");                            
}

if (!file_exists($output) || filesize($output) < 1000) {
   die("outputfile wrong: $output");
}
#die("generate a dummy error");
unlink($output);
?>
--EXPECT--
