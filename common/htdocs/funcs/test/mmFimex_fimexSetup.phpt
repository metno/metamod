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
            projString="+proj=latlong +elips=sphere +a=6371000 +e=0" 
            xAxis="0,1,...,x;relativeStart=0;unit=degree" 
            yAxis="0,1,...,x;relativeStart=0;unit=degree" 
            toDegree="true"/>
<projection name="Stereo" method="coord_nearestneighbor"
            projString="+proj=stere +elips=sphere +lon_0=0 +lat_0=90 +lat_ts=-32 +a=6371000 +e=0" 
            xAxis="0,50000,...,x;relativeStart=0;unit=m" 
            yAxis="0,50000,...,x;relativeStart=0;unit=m" 
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
if ($stereoMethod != "coord_nearestneighbor") {
   echo ("error reading projection-property: $steroMethod\n");
}

if (!$fs->getProjectionProperty("Lat/Long", "toDegree")) {
   echo ("error reading toDegree from Lat/Long\n");
}

$url = "http://damocles.met.no:8080/thredds/catalog/data/met.no/ecmwf/catalog.html?dataset=met.no/ecmwf/ecmwf_wave0_25_2008-07-02_12.nc";
$urlParams = "ncURL=http%3A%2F%2Fdamocles.met.no%3A8080%2Fthredds%2FfileServer%2Fdata%2Fmet.no%2Fecmwf%2Fecmwf_wave0_25_2008-07-02_12.nc&interpolationMethod=nearestghbor&axisUnitIsMetric=false&projString=%2Bproj%3Dlatlong+%2Belips%3Dsphere+%2Ba%3D6371000+%2Be%3D0&xAxisString=0%2C1%2C...%2Cx%3BrelativeStart%3D0%3Bunit%3Ddegree&yAxisString=0%2C1%2C...%2Cx%3BrelativeStart%3D0%3Bunit%3Ddegree"; 
if ($fs->getProjectionAsURLParameters("Lat/Long", "$url") != $urlParams) {
	echo ("getProjectionAsURLParameters returns wrong value:\n". $fs->getProjectionAsURLParameters("Lat/Long", "$url") . "\nexpected:\n" . $urlParams);
}
//echo ("success");
?>
--EXPECT--
