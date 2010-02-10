<?php
/*
 * Created on Jun 10, 2009
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
	require_once ("../funcs/mmDataset.inc");
	
	if (!strlen($_REQUEST['dsName'])) {
	   echo "dsName required";
	   exit(1);
	}
		
	// TODO: get a connection from a central function, instead of here
	$mmDbConnection = @pg_Connect ("dbname=".$mmConfig->getVar('DATABASE_NAME')." user=".$mmConfig->getVar('PG_WEB_USER')." ".$mmConfig->getVar('PG_CONNECTSTRING_PHP'));
   if ( !$mmDbConnection ) {
       mmPutLog("Error. Could not connect to database: $php_errormsg");
       $mmErrorMessage = "Error: Could not connect to database";
	    echo $mmErrorMessage;
		 exit(1);
   }
	$sqlsentence = "SELECT DS_filepath FROM DataSet WHERE DS_name = $1";
   $result = pg_query_params($mmDbConnection, $sqlsentence, array($_REQUEST['dsName']));
	if (!$result) {
	   echo "Dataset ".$_REQUEST['dsName']." not found in database";
	} else {
		header('Content-type: text/xml');
		list($filename) = pg_fetch_row($result);	
		list($xmdContent, $xml) = mmGetDatasetFileContent($filename);
		if (!strlen($xml)) {
			$xml = "<?xml version=\"1.0\" ?><error_no_file name=\"$filename\"\>";
		}
		echo $xml;
	}
?>