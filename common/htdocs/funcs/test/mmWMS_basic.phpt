--TEST--
MM_WMSSetup class - basic test for FimexSetup
--FILE--
<?php
require_once("../mmConfig.inc");
$mmConfig = MMConfig::getInstance('test_config.txt');
require_once("../mmWMS.inc");

$xml = '
<mm:wmcSetup xmlns:mm="http://www.met.no/schema/metamod/wmcSetup">
<mm:datasetName regex="!.*/ecmwf_wave0_25_(\d{4})-(\d{2})-(\d{2})_(\d{2})!" replace="ecmwf$1$2$3T$4."/>
<mm:wmsServerURL regex="!.*/ecmwf_wave0_25_(\d{4})-(\d{2})-(\d{2})_(\d{2})!" replace="http://my.wms.server.com/wms/dataset/ecmwf$1$2$3T$4?" />
<ViewContext xmlns="http://www.opengis.net/context" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="1.1.0" id="OpenLayers_Context_466" xsi:schemaLocation="http://www.opengis.net/context http://schemas.opengis.net/context/1.1.0/context.xsd">
  <General>
%DATASETNAME%
%DATASETNAME%
%WMS_ONLINE_RESOURCE%
  </General>
</ViewContext>
</mm:wmcSetup>
';

$ws = new MM_WMSSetup($xml);
if (!$ws instanceof MM_WMSSetup) {
   die ("cannot init MM_WMSSetup, got $ws");
}
if (strlen($ws->getDatasetRegex()) == 0) {
   echo ("no regex set");
}
if (strlen($ws->getDatasetReplace()) == 0) {
   echo ("no replace set");
}

if (strlen($ws->getWmsRegex()) == 0) {
   echo ("no regex set");
}
if (strlen($ws->getWmsReplace()) == 0) {
   echo ("no replace set");
}
if (!preg_match("!http://!", $ws->getWMSReplace())) {
   echo ("wrong wms replace: " . $ws->getWMSReplace());
}


$wmc = $ws->getDatasetWMC("blub/ecmwf_wave0_25_2009-08-10_12");
if (!preg_match("/20090810/", $wmc)) {
   echo ("wrong datasetname in wmc: ". $wmc);
}
if (!preg_match("!http://my.wms.server.com/wms/dataset/ecmwf20090810!", $wmc)) {
   echo ("wrong wmsurl in wmc: ". $wmc);
}

if ($ws->getClientUrl("bla/blub") != "wms.php?wmcurl=getWMC.php?datasetName=bla%2Fblub") {
   echo ("incorrect wmc url: " . $ws->getClientUrl("bla/blub"));
}

?>
--EXPECT--
