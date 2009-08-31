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
<ViewContext xmlns="http://www.opengis.net/context" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="1.1.0" id="OpenLayers_Context_466" xsi:schemaLocation="http://www.opengis.net/context http://schemas.opengis.net/context/1.1.0/context.xsd">
  <General>
%DATASETNAME%
%DATASETNAME%
  </General>
</ViewContext>
</mm:wmcSetup>
';

$ws = new MM_WMSSetup($xml);
if (!$ws instanceof MM_WMSSetup) {
   die ("cannot init MM_WMSSetup, got $ws");
}
if (strlen($ws->getRegex()) == 0) {
   echo ("no regex set");
}
if (strlen($ws->getReplace()) == 0) {
   echo ("no replace set");
}

$wmc = $ws->getDatasetWMC("blub/ecmwf_wave0_25_2009-08-10_12");
if (!preg_match("/20090810/", $wmc)) {
   echo ("wrong datasetname in wmc: ". $wmc);
}
?>
--EXPECT--