<?php
/*
 * Created on Jul 17, 2009
 *
 *---------------------------------------------------------------------------- 
 * METAMOD - Web portal for metadata search and upload 
 *
 * Copyright (C) 2009 met.no 
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
require_once('../funcs/mmConfig.inc');
require_once('../funcs/mmLogging.inc');
require_once('../funcs/mmFimex.inc');

/**
 * This page downloads a netcdf-file from an URL and reprojects it with
 * fimex projection parameters
 * 
 * The required parameters of the request (GET or POST) are
 * @param ncURL location of netcdf file, either local file:, ftp: or http:
 * @param interpolationMethod
 * @param projString
 * @param xAxisString
 * @param yAxisString
 * @param axisUnitIsMetric
 */
$errMsg = ''; # error message to put on screen
$params = array("ncURL", "interpolationMethod", "xAxisString", "yAxisString", "axisUnitIsMetric");
foreach ( $params as $param ) {
	if (strlen($_REQUEST[$param])) {
	   $params[$param] = $_REQUEST[$param];
	} else {
	   $errMsg .= "parameter $param missing in input ";
	}
}
$params["projString"] = $_REQUEST["projString"]; // may be empty
if ($params["axisUnitIsMetric"] == "true") {
   $params["axisUnitIsMetric"] = true;
} else if ($params["axisUnitIsMetric"] == "false") {
	$params["axisUnitIsMetric"] = false;
} else {
   $errMsg .= "parameter axisUnitIsMetric should be true/false, but is: ".$params['axisUnitIsMetric'];
}

$tempNcIn = tempnam(sys_get_temp_dir(), 'fimexNcInput');
if (mmRetrieveNcURL($params["ncURL"], $tempNcIn, $errMsg)) {
	$tempNcOut = tempnam(sys_get_temp_dir(), 'fimexNcOutput');
   if (mmFimexProjectFile($tempNcIn, "netcdf", $tempNcOut, "netcdf",
   	  				      $params["interpolationMethod"], $params["projString"],
   					      $params["xAxisString"], $params["yAxisString"],
   					      $params["axisUnitIsMetric"], $errMsg)) {
   	// send out the netcdf file
   	$projProj = preg_replace("/.*\+proj\=(\w+).*/", '$1', $params["projString"]);
   	if (strlen($projProj) == 0) {
   	   $projProj = "fimex";
   	}
   	$fileName = $projProj . '_'. basename($params["ncURL"]);
   	header('Content-Description: File Transfer');
		header('Content-Type: application/x-netcdf');
		header('Content-Length: ' . filesize($tempNcOut));
		header('Content-Disposition: attachment; filename=' . basename($fileName));
		readfile($tempNcOut);
		flush();
   } else {
      die($errMsg);
   }
   unlink($tempNcOut);
} else {
   die($errMsg);
}
unlink($tempNcIn);

if (strlen($errMsg)) {
   die($errMsg);
}





function printError($msg) {
   
}
?>