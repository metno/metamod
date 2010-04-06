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
if (strlen($ws->getClientUrl()) == 0) {
   echo ("no url set");
}
if ($ws->getClientUrl() != "wms.php?wmsurl=http%3A%2F%2Fthredds.met.no%2Fwms%2Fosisaf%2Fice_conc.nc") {
   echo ("incorrect url".$ws->getClientUrl());
}
if ($ws->getClientUrl("DAMOC/osisaf/test") != "wms.php?wmsurl=http%3A%2F%2Fthredds.met.no%2Fwms%2Fosisaf%2Ftest.nc") {
   echo ("incorrect url-replace for parent". $ws->getClientUrl("DAMOC/osisaf/test"));
}

$ws = new MM_WMSSetup2($xml, false);
if ($ws->getClientUrl("DAMOC/osisaf/test") != "wms.php?wmsurl=http%3A%2F%2Fthredds.met.no%2Fwms%2Fosisaf%2Fice_conc.nc") {
   echo ("incorrect url-replace for child". $ws->getClientUrl("DAMOC/osisaf/test"));
}

$xml2 = file_get_contents("ncWmsSetupExample.xml");
$ws2 = new MM_WMSSetup2($xml2, false);
if ($ws2->getUrl("DAMOC/osisaf/test") != "http://tempuri.org/wms/osisaf/test.nc") {
   echo ("incorrect url for dataset". $ws2->getUrl("DAMOC/osisaf/test"));
}
if (!preg_match("^osisaf/test^", $ws2->getDocument("DAMOC/osisaf/test"))) {
   echo ("incorrect url in wmsSetup.xml: " . $ws2->getDocument("DAMOC/osisaf/test"));
}

?>
--EXPECT--
