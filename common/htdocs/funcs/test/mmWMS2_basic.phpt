--TEST--
MM_WMSSetup class - basic test for FimexSetup
--FILE--
<?php
require_once("../mmConfig.inc");
$mmConfig = MMConfig::getInstance('test_config.txt');
require_once("../mmWMS2.inc");

$xml = '
<mm:ncWmsSetup xmlns:mm="http://www.met.no/schema/metamod/ncWmsSetup" url="http://thredds.met.no/wms/osisaf/ice_conc.nc"/>
';

$ws = new MM_WMSSetup2($xml, true);
if (!$ws instanceof MM_WMSSetup2) {
   die ("cannot init MM_WMSSetup2, got $ws");
}
if (strlen($ws->getUrl()) == 0) {
   echo ("no url set");
}
if ($ws->getUrl() != "wms.php?wmsurl=http%3A%2F%2Fthredds.met.no%2Fwms%2Fosisaf%2Fice_conc.nc") {
   echo ("incorrect url".$ws->getUrl());
}
if ($ws->getUrl("DAMOC/osisaf/test") != "wms.php?wmsurl=http%3A%2F%2Fthredds.met.no%2Fwms%2Fosisaf%2Ftest.nc") {
   echo ("incorrect url-replace for parent". $ws->getUrl("DAMOC/osisaf/test"));
}

$ws = new MM_WMSSetup2($xml, false);
if ($ws->getUrl("DAMOC/osisaf/test") != "wms.php?wmsurl=http%3A%2F%2Fthredds.met.no%2Fwms%2Fosisaf%2Fice_conc.nc") {
   echo ("incorrect url-replace for child". $ws->getUrl("DAMOC/osisaf/test"));
}


?>
--EXPECT--
