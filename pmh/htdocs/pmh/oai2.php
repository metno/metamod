<?php
/*
* +----------------------------------------------------------------------+
* | PHP Version 4                                                        |
* +----------------------------------------------------------------------+
* | Copyright (c) 2002 Heinrich Stamerjohanns                            |
* |                                                                      |
* | oai2.php -- An OAI Data Provider for version OAI v2.0                |
* |                                                                      |
* | This is free software; you can redistribute it and/or modify it under|
* | the terms of the GNU General Public License as published by the      |
* | Free Software Foundation; either version 2 of the License, or (at    |
* | your option) any later version.                                      |
* | This software is distributed in the hope that it will be useful, but |
* | WITHOUT  ANY WARRANTY; without even the implied warranty of          |
* | MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the         |
* | GNU General Public License for more details.                         |     
* | You should have received a copy of the GNU General Public License    |
* | along with  software; if not, write to the Free Software Foundation, |
* | Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA         |
* |                                                                      |
* +----------------------------------------------------------------------+
* | Derived from work by U. M�ller, HUB Berlin                           |
* |                                                                      |
* | Written by Heinrich Stamerjohanns, May 2002                          |
* |            stamer@uni-oldenburg.de                                   |
* |                                                                      |
* | Adapted to METAMOD2 by Egil St�ren, August 2008                      |
* |            egil.storen@met.no                                        |
* +----------------------------------------------------------------------+
*/
//
// $Id: oai2.php,v 1.11 2003/04/08 14:27:21 stamer Exp $
//
// Report all errors except E_NOTICE
// This is the default value set in php.ini
error_reporting (E_ALL ^ E_NOTICE);

$output = '';
$errors = '';

require_once('../funcs/mmConfig.inc');
require_once ("../funcs/mmDataset.inc");
require_once("../funcs/mmOAIPMH.inc");
require_once('oai2/oaidp-util.php');
require_once('oai2/buildxml.php');
require_once('oai2/get_exception.php');

// register_globals does not need to be set
if (!php_is_at_least('4.1.0')) {
	$_SERVER = $HTTP_SERVER_VARS;
	$_SERVER['REQUEST_METHOD'] = $REQUEST_METHOD;
	$_GET = $HTTP_GET_VARS;
	$_POST = $HTTP_POST_VARS;
}

if ($_SERVER['REQUEST_METHOD'] == 'GET') {
	$args = $_GET;
	$getarr = explode('&', $_SERVER['QUERY_STRING']);
} elseif ($_SERVER['REQUEST_METHOD'] == 'POST') {
	$args = $_POST;
} else {
	$errors .= oai_error('badRequestMethod', $_SERVER['REQUEST_METHOD']);
}

require_once('oai2/oaidp-config.php');

// and now we make the OAI Repository Explorer really happy
// I have not found any way to check this for POST requests.
if (isset($getarr)) {
	if (count($getarr) > 0 && count($args) > 0 && count($getarr) != count($args)) {
		$errors .= oai_error('sameArgument');
	}
}

$reqattr = '';
if (is_array($args)) {
	foreach ($args as $key => $val) {
		$reqattr .= ' '.$key.'="'.htmlspecialchars(stripslashes($val)).'"';
	}
}

// in case register_globals is on, clean up polluted global scope
$verbs = array ('from', 'identifier', 'metadataPrefix', 'set', 'resumptionToken', 'until');
foreach($verbs as $val) {
	unset($$val);
}

ini_set("track_errors",1);
$mmDbConnection = @pg_Connect ("dbname=".$mmConfig->getVar('DATABASE_NAME')." user=".$mmConfig->getVar('PG_WEB_USER')." ".$mmConfig->getVar('PG_CONNECTSTRING_PHP'));
if ( !$mmDbConnection ) {
   mmPutLog("Error. Could not connect to database: $php_errormsg");
   $errors .= oai_error('serviceUnavailable');
}

$request = ' <request'.$reqattr.'>'.$MY_URI."</request>\n";
$request_err = ' <request>'.$MY_URI."</request>\n";

if ($errors != '') {
	oai_exit();
}

if (is_array($compression)) {
	if (in_array('gzip', $compression)
		&& ini_get('output_buffering')) {
		$compress = TRUE;
	} else
		$compress = FALSE;
}

if (isset($args['verb'])) {
	switch ($args['verb']) {

		case 'GetRecord':
			unset($args['verb']);
			include 'oai2/getrecord.php';
			break;

		case 'Identify':
			unset($args['verb']);
			// we never use compression in Identify
			$compress = FALSE;
			include 'oai2/identify.php';
			break;

		case 'ListIdentifiers':
			unset($args['verb']);
			include 'oai2/listidentifiers.php';
			break;

		case 'ListMetadataFormats':
			unset($args['verb']);
			include 'oai2/listmetadataformats.php';
			break;

		case 'ListRecords':
			unset($args['verb']);
			include 'oai2/listrecords.php';
			break;

		case 'ListSets':
			unset($args['verb']);
			include 'oai2/listsets.php';
			break;

		default:
			// we never use compression with errors
			$compress = FALSE;
			$errors .= oai_error('badVerb', $args['verb']);
	} /*switch */

} else {
	$errors .= oai_error('noVerb');
}

if ($errors != '') {
	oai_exit();
}

$oaiStr = $xmlheader . $request . $output . "</OAI-PMH>\n";
$mmOAI = new MM_OaiPmh($oaiStr);
if (!$mmOAI->validateOAI()) {
	$errors = 'oai response does not validate';
   oai_exit();
}
// remove elements and check validity again
if ($mmOAI->removeInvalidRecords() > 0) {
   if (!$mmOAI->validateOAI()) {
   	$errors = 'oai response does not validate after removal of invalid records';
   	oai_exit();
   }
}

// output
if ($compress) {
	ob_start('ob_gzhandler');
}
header($CONTENT_TYPE);
echo $mmOAI->getOAI_XML();
if ($compress) {
   ob_end_flush();
}

?>
