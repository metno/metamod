<?php
/*
 * Created on Apr 6, 2010
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
require_once('../funcs/mmWMS2.inc');

/**
 * This page retrieve the WMC information from a dataset (level2)
 * 
 * The required parameters of the request (GET or POST) are
 * @param datasetName (level2)
 */
$params = array("datasetName");
foreach ( $params as $param ) {
	if (strlen($_REQUEST[$param])) {
	   $params[$param] = $_REQUEST[$param];
	} else {
	   notFound($param);
	}
}
$dsName = $params["datasetName"];


$dbh = @pg_Connect ("dbname=".$mmConfig->getVar('DATABASE_NAME')." user=".$mmConfig->getVar('PG_WEB_USER')." ".$mmConfig->getVar('PG_CONNECTSTRING_PHP'));
if ( !$dbh ) {
	mmPutLog("Error. Could not connect to database: $php_errormsg");
	serverError("Error. Could not connect to database");
}

$wmsSetup = getWMSSetup2FromDb($dbh, $dsName);
if (!$wmsSetup) {
   notFound($dsName);
}
$xml = $wmsSetup->getDocument($dsName);
if (strlen($xml < 0)) {
   notFound($dsName);
} else {
   header("Content-type: text/xml");
   echo $xml;
}


function notFound($datasetName) {
			// no WMSInfo for dataset, throw a http page not found error
			header("HTTP/1.0 404 Not Found");	
			echo("<html><head><title>ERROR 404: Page not found</title></head><body><h1>ERROR 404: Page not found</h1>No WMC setup for $datasetName</body></html>");
			exit(1);

}

function serverError($msg) {
	// no WMSInfo for dataset, throw a http page not found error
	header("HTTP/1.0 500 Internal Server Error");	
	echo("<html><head><title>ERROR 500: Internal Server Error</title></head><body><h1>Error 500: Internal Server Error</h1>$msg</body></html>");
	exit(1);
}


if (strlen($errMsg)) {
   die($errMsg);
}

?>