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
?>

<?php
require_once("mmConfig.inc");
require_once("mmLogging.inc");

/**
 * @param $input local input file
 * @param $inputType file-type, e.g. netcdf
 * @param $output local netcdf output file
 * @param $outputType file-type, e.g. netcdf
 * @param $method one of fimex interpolation methods: nearestneighbor, bilinear, bicubic, coord_nearestneighbor or coord_kdtree
 * @param $proj proj-string of output-projection
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
projString = $proj
xAxisValues = $xaxis
yAxisValues = $yaxis
xAxisUnit = $xUnit
yAxisUnit = $yUnit
 	 
EOT;
 	
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



?>