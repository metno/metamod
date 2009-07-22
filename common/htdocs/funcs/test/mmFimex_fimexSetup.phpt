--TEST--
MM_FimexSetup class - basic test for FimexSetup
--FILE--
<?php
require_once("../mmConfig.inc");
$mmConfig = MMConfig::getInstance('test_config.txt');
require_once("../mmFimex.inc");

$xml = '
<fimexProjections xmlns="http://www.met.no/schema/metamod/fimexProjections">
<dataset urlRegex="^(.*/thredds).*dataset=(.*)^" urlReplace="$1/fileServer/data/$2"/>
<!-- see fimex-interpolation for more info on options -->
<projection name="Lat/Long" method="nearestghbor" 
            projString="+proj=latlong +ellps=sphere +a=6371000 +e=0" 
            xAxis="-180,-179,...,180" 
            yAxis="60,61,...,90" 
            toDegree="true"/>
<projection name="Stereo" method="bilinear"
            projString="+proj=stere +ellps=sphere +lon_0=-32 +lat_0=90 +lat_ts=60 +a=6371000 +e=0" 
            xAxis="0,50000,...,x;relativeStart=0" 
            yAxis="0,50000,...,x;relativeStart=0" 
            toDegree="false" /> 
</fimexProjections>';

$fs = new MM_FimexSetup($xml);
if (!$fs instanceof MM_FimexSetup) {
   die ("cannot init MM_FimexSetup, got $fs");
}
$projs = $fs->getProjections();
if (count($projs) != 2) {
   echo ("count should be 2, but is ". count($projs)."\n");
}

$stereoMethod = $fs->getProjectionProperty("Stereo", "method");
if ($stereoMethod != "bilinear") {
   echo ("error reading projection-property: $stereoMethod\n");
}

if (!$fs->getProjectionProperty("Lat/Long", "toDegree")) {
   echo ("error reading toDegree from Lat/Long\n");
}

$url = "http://damocles.met.no:8080/thredds/catalog/data/met.no/ecmwf/catalog.html?dataset=met.no/ecmwf/ecmwf_wave0_25_2008-07-02_12.nc";
$urlParams = "ncURL=http%3A%2F%2Fdamocles.met.no%3A8080%2Fthredds%2FfileServer%2Fdata%2Fmet.no%2Fecmwf%2Fecmwf_wave0_25_2008-07-02_12.nc&interpolationMethod=nearestghbor&axisUnitIsMetric=false&projString=%2Bproj%3Dlatlong+%2Bellps%3Dsphere+%2Ba%3D6371000+%2Be%3D0&xAxisString=-180%2C-179%2C...%2C180&yAxisString=60%2C61%2C...%2C90"; 
if ($fs->getProjectionAsURLParameters("Lat/Long", "$url") != $urlParams) {
	echo ("getProjectionAsURLParameters returns wrong value:\n". $fs->getProjectionAsURLParameters("Lat/Long", "$url") . "\nexpected:\n" . $urlParams);
}
//echo ("success");
?>
--EXPECT--
