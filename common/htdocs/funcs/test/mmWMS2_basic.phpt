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
if (strlen($ws->getClientQuery()) == 0) {
   echo ("no url set");
}
if ($ws->getClientQuery() != "wmsurl=http%3A%2F%2Fthredds.met.no%2Fwms%2Fosisaf%2Fice_conc.nc") {
   echo ("incorrect query".$ws->getClientQuery());
}
if ($ws->getClientQuery("DAMOC/osisaf/test") != "wmsurl=http%3A%2F%2Fthredds.met.no%2Fwms%2Fosisaf%2Ftest.nc") {
   echo ("incorrect query-replace for parent". $ws->getClientQuery("DAMOC/osisaf/test"));
}

$ws = new MM_WMSSetup2($xml, false);
if ($ws->getClientQuery("DAMOC/osisaf/test") != "wmsurl=http%3A%2F%2Fthredds.met.no%2Fwms%2Fosisaf%2Fice_conc.nc") {
   echo ("incorrect query-replace for child". $ws->getClientQuery("DAMOC/osisaf/test"));
}

$xml2 = file_get_contents("ncWmsSetupExample.xml");
$ws2 = new MM_WMSSetup2($xml2, false);
if ($ws2->getUrl("DAMOC/osisaf/test") != "http://dev-vm188/thredds/wms/osisaf/met.no/osisaf/test.nc") {
   echo ("incorrect url for dataset". $ws2->getUrl("DAMOC/osisaf/test"));
}
if (!$ws2->isComplex()) {
   echo "ncWmsSetupExample should be complex";
}
if (!preg_match("^osisaf/test^", $ws2->getDocument("DAMOC/osisaf/test"))) {
   echo ("incorrect url in wmsSetup.xml: " . $ws2->getDocument("DAMOC/osisaf/test"));
}

?>
--EXPECT--
