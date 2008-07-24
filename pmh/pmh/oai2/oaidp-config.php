<?    
/*
* +----------------------------------------------------------------------+
* | PHP Version 4                                                        |
* +----------------------------------------------------------------------+
* | Copyright (c) 2002-2005 Heinrich Stamerjohanns                       |
* |                                                                      |
* | oaidp-config.php -- Configuration of the OAI Data Provider           |
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
* | Derived from work by U. Müller, HUB Berlin, 2002                     |
* |                                                                      |
* | Written by Heinrich Stamerjohanns, May 2002                          |
* |            stamer@uni-oldenburg.de                                   |
* +----------------------------------------------------------------------+
*/
//
// $Id: oaidp-config.php,v 1.07 2004/07/01 16:59:57 stamer Exp $
//

/* 
 * This is the configuration file for the PHP OAI Data-Provider.
 * Please read through the WHOLE file, there are several things, that 
 * need to be adjusted:

 - where to find the PEAR classes (look for PEAR SETUP)
 - parameters for your database connection (look for DATABASE SETUP)
 - the name of the table where you store your data
 - the encoding your data is stored (all below DATABASE SETUP)
*/

// To install, test and debug use this	
// If set to TRUE, will die and display query and database error message
// as soon as there is a problem. Do not set this to TRUE on a production site,
// since it will show error messages to everybody.
// If set FALSE, will create XML-output, no matter what happens.
$SHOW_QUERY_ERROR = FALSE;

// The content-type the WWW-server delivers back. For debug-puposes, "text/plain" 
// is easier to view. On a production site you should use "text/xml".
$CONTENT_TYPE = 'Content-Type: text/plain';

// If everything is running ok, you should use this
// $SHOW_QUERY_ERROR = FALSE;
//$CONTENT_TYPE = 'Content-Type: text/xml';

// PEAR SETUP
// use PEAR classes
//
// if you do not find PEAR, use something like this
// ini_set('include_path', '.:/usr/share/php:/www/oai/PEAR');
// Windows users might like to try this
// ini_set('include_path', '.;c:\php\pear');

// if there are problems with unknown 'numrows', then make sure
// to upgrade to a decent PEAR version. 
require_once('DB.php');

error_reporting(E_ALL & ~E_NOTICE);

// do not change
$MY_URI = 'http://'.$_SERVER['SERVER_NAME'].':8080'.$_SERVER['SCRIPT_NAME'];
# echo $MY_URI . '<BR />';

// MUST (only one)
// please adjust
$repositoryName       = 'Met.no OAI Repository';
$baseURL			  = $MY_URI;
// You can use a static URI as well.
// $baseURL 			= "http://my.server.org/oai/oai2.php";
// do not change
$protocolVersion      = '2.0';

// How your repository handles deletions
// no: 			The repository does not maintain status about deletions.
//				It MUST NOT reveal a deleted status.
// persistent:	The repository persistently keeps track about deletions 
//				with no time limit. It MUST consistently reveal the status
//				of a deleted record over time.
// transient:   The repository does not guarantee that a list of deletions is 
//				maintained. It MAY reveal a deleted status for records.
// 
// If your database keeps track of deleted records change accordingly.
// Currently if $record['deleted'] is set to 'true', $status_deleted is set.
// Some lines in listidentifiers.php, listrecords.php, getrecords.php  
// must be changed to fit the condition for your database.
$deletedRecord        = 'no'; 

// MAY (only one)
//granularity is days
//$granularity          = 'YYYY-MM-DD';
// granularity is seconds
$granularity          = 'YYYY-MM-DDThh:mm:ssZ';

// MUST (only one)
// the earliest datestamp in your repository,
// please adjust
$earliestDatestamp    = '2000-01-01';

// this is appended if your granularity is seconds.
// do not change
if ($granularity == 'YYYY-MM-DDThh:mm:ss:Z') {
	$earliestDatestamp .= 'T00:00:00Z';
}

// MUST (multiple)
// please adjust
$adminEmail			= array('mailto:egil.storen@met.no'); 

// MAY (multiple) 
// Comment out, if you do not want to use it.
// Currently only gzip is supported (you need output buffering turned on, 
// and php compiled with libgz). 
// The client MUST send "Accept-Encoding: gzip" to actually receive 
// compressed output.
$compression		= array('gzip');

// MUST (only one)
// should not be changed
$delimiter			= ':';

// MUST (only one)
// You may choose any name, but for repositories to comply with the oai 
// format for unique identifiers for items records. 
// see: http://www.openarchives.org/OAI/2.0/guidelines-oai-identifier.htm
// Basically use domainname-word.domainname
// please adjust
$repositoryIdentifier = 'met.no'; 


// description is defined in identify.php 
$show_identifier = false;

// You may include details about your community and friends (other
// data-providers).
// Please check identify.php for other possible containers 
// in the Identify response

// maximum mumber of the records to deliver
// (verb is ListRecords)
// If there are more records to deliver
// a ResumptionToken will be generated.
$MAXRECORDS = 50;

// maximum mumber of identifiers to deliver
// (verb is ListIdentifiers)
// If there are more identifiers to deliver
// a ResumptionToken will be generated.
$MAXIDS = 200;

// After 24 hours resumptionTokens become invalid.
$tokenValid = 24*3600;
$expirationdatetime = gmstrftime('%Y-%m-%dT%TZ', time()+$tokenValid); 

// define all supported sets in your repository
$SETS = 	array (
				// array('setSpec'=>'phdthesis', 'setName'=>'PHD Thesis', 'setDescription'=>'') //,
				// array('setSpec'=>'math', 'setName'=>'Mathematics') ,
				// array('setSpec'=>'phys', 'setName'=>'Physics') 
			);

// define all supported metadata formats

//
// myhandler is the name of the file that handles the request for the 
// specific metadata format.
// [record_prefix] describes an optional prefix for the metadata
// [record_namespace] describe the namespace for this prefix

$METADATAFORMATS = 	array (
						'oai_dc' => array('metadataPrefix'=>'oai_dc', 
							'schema'=>'http://www.openarchives.org/OAI/2.0/oai_dc.xsd',
							'metadataNamespace'=>'http://www.openarchives.org/OAI/2.0/oai_dc/',
							'myhandler'=>'record_dc.php',
							'record_prefix'=>'dc',
							'record_namespace' => 'http://purl.org/dc/elements/1.1/'
						) //,
						//array('metadataPrefix'=>'olac', 
						//	'schema'=>'http://www.language-archives.org/OLAC/olac-2.0.xsd',
						//	'metadataNamespace'=>'http://www.openarchives.org/OLAC/0.2/',
						//	'handler'=>'record_olac.php'
						//)
					);

// 
// DATABASE SETUP
//

// change according to your local DB setup.
$DB_HOST   = 'localhost';
$DB_USER   = 'admin';
$DB_PASSWD = '';
$DB_NAME   = 'oaipmh';												           

// Data Source Name: This is the universal connection string
// if you use something other than mysql edit accordingly.
// Example for MySQL
// $DSN = "mysql://$DB_USER:$DB_PASSWD@$DB_HOST/$DB_NAME";
// Example for Oracle
// $DSN = "oci8://$DB_USER:$DB_PASSWD@$DB_NAME";
$DSN = "pgsql://$DB_USER$DB_PASSWD@$DB_HOST/$DB_NAME";
# echo $DSN . '<BR />';

// the charset you store your metadata in your database
// currently only utf-8 and iso8859-1 are supported
$charset = "iso8859-1";

// if entities such as < > ' " in your metadata has already been escaped 
// then set this to true (e.g. you store < as &lt; in your DB)
$xmlescaped = false;

// We store multiple entries for one element in a single row 
// in the database. SQL['split'] ist the delimiter for these entries.
// If you do not do this, do not define $SQL['split']
$SQL['split'] = ';';

// the name of the table where your store your metadata
$SQL['table'] = 'oai_records';

// the name of the column where you store your sequence 
// (or autoincrement values).
$SQL['id_column'] = 'serial';

// the name of the column where you store the unique identifiers
// pointing to your item.
// this is your internal identifier for the item
$SQL['identifier'] = 'url';

// If you want to expand the internal identifier in some way
// use this (but not for OAI stuff, see next line)
$idPrefix = '';

// this is your external (OAI) identifier for the item
// this will be expanded to
// oai:$repositoryIdentifier:$idPrefix$SQL['identifier']
// should not be changed
$oaiprefix = "oai".$delimiter.$repositoryIdentifier.$delimiter.$idPrefix; 

// adjust anIdentifier with sample contents an identifier
$sampleIdentifier     = $oaiprefix.'anIdentifier';

// the name of the column where you store your datestamps
$SQL['datestamp'] = 'datestamp';

// the name of the column where you store information whether
// a record has been deleted. Leave it as it is if you do not use
// this feature.
$SQL['deleted'] = 'deleted';

// to be able to quickly retrieve the sets to which one item belongs,
// the setnames are stored for each item
// the name of the column where you store sets
$SQL['set'] = 'oai_set';

// Here are a couple of queries which might need to be adjusted to 
// your needs. Normally, if you have correctly named the columns above,
// this does not need to be done.

// this function should generate a query which will return
// all records
// the useless condition id_column = id_column is just there to ease
// further extensions to the query, please leave it as it is.
function selectallQuery ($id = '')
{
	global $SQL;
	$query = 'SELECT * FROM '.$SQL['table'].' WHERE ';
	if ($id == '') {
		$query .= $SQL['id_column'].' = '.$SQL['id_column'];
	}
	else {
		$query .= $SQL['identifier']." ='$id'";
	}
	return $query;
}

// this function will return identifier and datestamp for all records
function idQuery ($id = '')
{
	global $SQL;

	if ($SQL['set'] != '') {
		$query = 'select '.$SQL['identifier'].','.$SQL['datestamp'].','.$SQL['set'].' FROM '.$SQL['table'].' WHERE ';
	} else {
		$query = 'select '.$SQL['identifier'].','.$SQL['datestamp'].' FROM '.$SQL['table'].' WHERE ';
	}
	
	if ($id == '') {
		$query .= $SQL['id_column'].' = '.$SQL['id_column'];
	}
	else {
		$query .= $SQL['identifier']." = '$id'";
	}

	return $query;
}

// filter for until
function untilQuery($until) 
{
	global $SQL;

	return ' and '.$SQL['datestamp']." <= '$until'";
}

// filter for from
function fromQuery($from)
{
	global $SQL;

	return ' and '.$SQL['datestamp']." >= '$from'";
}

// filter for sets
function setQuery($set)
{
	global $SQL;

	return ' and '.$SQL['set']." LIKE '%$set%'";
}

// There is no need to change anything below.

// Current Date
$datetime = gmstrftime('%Y-%m-%dT%T');
$responseDate = $datetime.'Z';

// do not change
$XMLHEADER = 
'<?xml version="1.0" encoding="UTF-8"?>
<OAI-PMH xmlns="http://www.openarchives.org/OAI/2.0/"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/
         http://www.openarchives.org/OAI/2.0/OAI-PMH.xsd">'."\n";

$xmlheader = $XMLHEADER . 
			  ' <responseDate>'.$responseDate."</responseDate>\n";

// the xml schema namespace, do not change this
$XMLSCHEMA = 'http://www.w3.org/2001/XMLSchema-instance';




?>
