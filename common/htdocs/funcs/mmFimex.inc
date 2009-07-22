<?php
/*
 * Created on Jul 15, 2009
 *
 *---------------------------------------------------------------------------- 
 * METAMOD - Web portal for metadata search and upload 
 *
 * Copyright (C) 2008 met.no 
 *
 * Contact information: 
 * Norwegian Meteorological Institute 
 * Box 43 Blindern 
 * 0313 OSLO 
 * NORWAY 
 * email: heiko.klein@met.no 
 *  
 * This file is part of METAMOD 
 *
 * METAMOD is free software; you can redistribute it and/or modify 
 * it under the terms of the GNU General Public License as published by 
 * the Free Software Foundation; either version 2 of the License, or 
 * (at your option) any later version. 
 *
 * METAMOD is distributed in the hope that it will be useful, 
 * but WITHOUT ANY WARRANTY; without even the implied warranty of 
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the 
 * GNU General Public License for more details. 
 *  
 * You should have received a copy of the GNU General Public License 
 * along with METAMOD; if not, write to the Free Software 
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA 
 *--------------------------------------------------------------------------- 
 */

require_once("mmConfig.inc");
require_once("mmLogging.inc");
require_once("mmDataset.inc");

if ( !function_exists('sys_get_temp_dir')) { // first defined in php 5.2.1
	function sys_get_temp_dir() {
   	if (!empty($_ENV['TMP'])) { return realpath($_ENV['TMP']); }
    	if (!empty($_ENV['TMPDIR'])) { return realpath( $_ENV['TMPDIR']); }
    	if (!empty($_ENV['TEMP'])) { return realpath( $_ENV['TEMP']); }
    	$tempfile=tempnam(":\n\\/?><",''); // create tempfile in non-existing directory, will switch back to system-default temp
    	if (file_exists($tempfile)) {
    		unlink($tempfile);
    		return realpath(dirname($tempfile));
   	}
	}
}

/**
 * @param $input local input file
 * @param $inputType file-type, e.g. netcdf
 * @param $output local netcdf output file
 * @param $outputType file-type, e.g. netcdf
 * @param $method one of fimex interpolation methods: nearestneighbor, bilinear, bicubic, coord_nearestneighbor or coord_kdtree
 * @param $proj proj-string of output-projection, if left empty, no reprojection will occur
 * @param $xaxis xaxis-ticks, e.g. 10.5,11,...,29.5
 * @param $yaxis yaxis-ticks
 * @param $axisUnitIsMetric boolean flag to indicate metric or degree axes
 * @param @$errMsg optional reference to the error-message
 *
 * @return true on success, false on error
 */
function mmFimexProjectFile($input, $inputType, $output, $outputType, $method, $proj, $xaxis, $yaxis, $axisUnitIsMetric, &$errMsg = "") {
	global $mmConfig;
	$xUnit = $axisUnitIsMetric ? 'm' : 'degrees_east';
	$yUnit = $axisUnitIsMetric ? 'm' : 'degrees_north';
 	$fimexSetup = <<<EOT
[input]
file=$input
type=$inputType

[output]
file=$output
type=$outputType

[interpolate]
method = $method
xAxisValues = $xaxis
yAxisValues = $yaxis
xAxisUnit = $xUnit
yAxisUnit = $yUnit

EOT;
	if (strlen($proj)) {
	   $fimexSetup .= "projString = $proj\n";
	}
 	
   $fimexInput = tempnam(sys_get_temp_dir(), 'fimexInput');
   $fiFH = fopen($fimexInput, "w");
   fwrite($fiFH, $fimexSetup);
   fclose($fiFH);

	$fimexProg = $mmConfig->getVar('FIMEX_PROGRAM');
	if (strlen($fimexProg) == 0) {
	   $msg = "FIMEX_PROGRAM not set in setup";
   	$errMsg .= $msg . "\n";
      mm_log(MM_ERROR, $msg, __FILE__, __LINE__);
      return false;
	}
	$fimexExec = "$fimexProg --config $fimexInput";
	$err = 0;
	$output = system($fimexExec, $err);
   if ($err != 0) {
   	$msg = "cannot convert fimex-file using '$fimexExec'";
   	$errMsg .= $msg;
      mm_log(MM_ERROR, $msg, __FILE__, __LINE__);
      return false;
   }
	unlink($fimexInput);
	return true;
}


/**
 * retrieve an nc-file from an url to local file
 * @param $url the url of the netcdf-file
 * @param $outputNcFile the filename of the local output file
 * @param $errMsg optional error message
 * @return true on success, false on failure
 */
function mmRetrieveNcURL($url, $outputNcFile, &$errMsg = "") {
	// open the filehandle
	$tempNcFH = fopen($outputNcFile, "w+");
	if (!$tempNcFH) {
		$errMsg .= "Cannot open file $outputNcFile";
	   mm_log(MM_ERROR, $errMsg, __FILE__, __LINE__);
	   return false;
	}
	
	// download url to filehandle
	$curl = curl_init($url);
	curl_setopt($curl, CURLOPT_FILE, $tempNcFH);
	curl_setopt($curl, CURLOPT_HEADER, 0);
	$retVal = true;
	if (!curl_exec($curl)) {
	   $errMsg .= "cannot retrieve url $url";
	   mm_log(MM_WARNING, $errMsg, __FILE__, __LINE__);
	   $retVal = false;
	}
	curl_close($curl);
	
	// check for netcdf content
	fseek($tempNcFH, 0);
	$ncMagic = fread($tempNcFH, 3);
	if ($ncMagic != "CDF") {
	   $errMsg .= "file from $url not netcdf-3, but $ncMagic";
	   mm_log(MM_WARNING, $errMsg, __FILE__, __LINE__);
	   $retVal = false;
	}
	
	fclose($tempNcFH);
	return $retVal;
}


/**
 * Class for hiding the xml-structure and giving easy access to the FimexSetup string.
 * 
 * Example of fimex-setup string:
 * <fimexProjections xmlns="http://www.met.no/schema/metamod/fimexProjections">
 * <dataset urlRegex="" urlReplace=""/>
 * <!-- see fimex-interpolation for more info on options -->
 * <projection name="Lat/Long" method="nearestghbor" 
 *           projString="+proj=latlong +elips=sphere +a=6371000 +e=0" 
 *           xAxis="0,1,...,x;relativeStart=0" 
 *           yAxis="0,1,...,x;relativeStart=0" 
 *           toDegree="true"/>
 * <projection name="Stereo" method="coord_nearestneighbor"
 *           projString="+proj=stere +elips=sphere +lon_0=-32 +lat_0=90 +lat_ts=60 +a=6371000 +e=0" 
 *           xAxis="0,50000,...,x;relativeStart=0" 
 *           yAxis="0,50000,...,x;relativeStart=0" 
 *           toDegree="false" /> 
 * </fimexProjections>        
 */
class MM_FimexSetup {
   protected $urlRegex = false;
   protected $urlReplace = false;
   protected $projections = array(); # $projections contains projection-name => array(projString => ..., xAxis => ..., yAxis => ..., method => ..., toDegree => ...)
   static $fimexProjectionNS = "http://www.met.no/schema/metamod/fimexProjections";
   /**
    * create a new MM_FimexSetup from a string
    * @param $str xml-string
    * @throws MM_DatasetException if the string is not parseable
    */
   function __construct($str = "") {
      if (strlen($str)) {
         $dom = new DOMDocument();
         if (!$dom->loadXML($str)) {
         	mm_log(MM_ERROR, "unable to parse xml-string $str", __FILE__, __LINE__);
         	throw new MM_DatasetException("unable to parse xml-string $str");
         }
         $xpath = new DomXPath($dom);
         $xpath->registerNamespace('f', MM_FimexSetup::$fimexProjectionNS);
         
         foreach ($xpath->query('/f:fimexProjections/f:dataset') as $node) {
				foreach ($node->attributes as $att) {
				   if ($att->name == 'urlRegex') {
				      $this->urlRegex = $att->value;
				   } else if ($att->name == 'urlReplace') {
				      $this->urlReplace = $att->value;
				   }
				}            
         }
         
         foreach ($xpath->query('/f:fimexProjections/f:projection') as $node) {
         	$nodeArray = array();
         	foreach ($node->attributes as $att) {
         		$nodeArray[$att->name] = $att->value;
         	}
         	if ($nodeArray["name"]) {
         		$this->projections[$nodeArray["name"]] = $nodeArray;        	   
         	}
         }
      }
   }
   /**
    * @return array with names of projections
    */
   function getProjections() {
      return array_keys($this->projections);
   }
   /**
    * get the value of a projection property
    * @param $projName the projection's name
    * @param $property name of the property as projStr, method, xAxis, yAxis, toDegree
    * @return property-value of projection or ""
    */
   function getProjectionProperty($projName, $property) {
 		if (array_key_exists($projName, $this->projections)) {
      	return $this->projections[$projName][$property];
 		} else {
 		   return "";
 		}
   }
   
   /**
    * get the regex to match the url against 
    */
   function getURLRegex() {
      return $this->urlRegex;
   }
   /**
    * get the regex/replace to change the url with 
    */
   function getURLReplace() {
      return $this->urlReplace;
   }
   /**
    * Get the url parameters for e.g. sch/getFimexReprojectedURL.php
    * 
    * @param $projName the name of the projection
    * @param $dataURL the basic name of the data-url. This will be regex-replaced by urlRegex and urlReplace.
    * @return url-parameters as string i.e. ncURL=http://www.ncdata.com/file.nc&interpolationMethod=nearestneighbor&......
    */
   function getProjectionAsURLParameters($projName, $dataURL) {
   	$params = array();
      if ($this->getURLRegex() && $this->getURLReplace()) {
         $url = preg_replace($this->getURLRegex(), $this->getURLReplace(), $dataURL);
         $params[] = 'ncURL='.urlencode($url);
      } else {
         $params[] = 'ncURL='.urlencode($dataURL);
      }
      if (array_key_exists($projName, $this->projections)) {
			if ($this->getProjectionProperty($projName, 'method')) {
			   $params[] = 'interpolationMethod='.urlencode($this->getProjectionProperty($projName, 'method'));
			} else {
			   $params[] = 'interpolationMethod=nearestneighbor';
			}
			if ($this->getProjectionProperty($projName, 'toDegree') == 'true') {
				$params[] = 'axisUnitIsMetric=false';
			} else {
			   $params[] = 'axisUnitIsMetric=true';
			}
		   $params[] = 'projString='.urlencode($this->getProjectionProperty($projName, 'projString'));
			$params[] = 'xAxisString='.urlencode($this->getProjectionProperty($projName, 'xAxis'));
			$params[] = 'yAxisString='.urlencode($this->getProjectionProperty($projName, 'yAxis'));
			return join('&', $params);
      }
      return false;
   }
   
}
/**
 * retrieve a fimex-setup from the database
 * @param $pgDb postgres database connection
 * @param $datasetId id of an dataset to retrieve the setup
 * @return a MM_FimexSetup, or false
 */
function getFimexSetupFromDb($pgDb, $datasetId) {
	$sql = 
'SELECT PI_content FROM ProjectionInfo
   WHERE DS_id = $1 AND (PI_content IS NOT NULL OR PI_content != \'\')';

	$result = pg_query_params($pgDb, $sql, array($datasetId));
	if (!$result) {
	   mm_log(MM_ERROR, "Could not execute $sqlsentence", __FILE__, __LINE__);
      die("Internal Error");
	}
	if (pg_num_rows($result) != 1) {
		// try parent
		$sql = 
'SELECT PI_content FROM ProjectionInfo, Dataset ' .
' WHERE (PI_content IS NOT NULL OR PI_content != \'\') ' .
'   AND DS_parent = $1 ' .
'   AND ProjectionInfo.DS_id = Dataset.DS_id';
		$result = pg_query_params($pgDb, $sql, array($datasetId));
		if (!$result) {
		   mm_log(MM_ERROR, "Could not execute $sqlsentence", __FILE__, __LINE__);
	      die("Internal Error");
		}
	}
   $retVal = false;
	if (pg_num_rows($result) == 1) {
	   list($content) = pg_fetch_array($result);
		try {
		   $retVal = new MM_FimexSetup($content);
		} catch (MM_DatasetException $ex) {
		   mm_log(MM_WARNING, "Error in fimex setup of dataset $datasetId", __FILE__, __LINE__);
		}
	}
   return $retVal;
}

?>