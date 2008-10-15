--TEST--
readDataset() function - basic test for readDataset
--FILE--
<?php
require_once("../mmLogging.inc");
mm_log(MM_DEBUG, "test-log", __FILE__, __LINE__);
var_dump(0);
?>
--EXPECT--
int(0)