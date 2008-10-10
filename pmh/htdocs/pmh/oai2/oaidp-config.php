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
* |                                                                      |
* | Adapted to METAMOD2 by Egil Støren, August 2008                      |
* |            egil.storen@met.no                                        |
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
$CONTENT_TYPE = 'Content-Type: [==PMH_CONTENT_TYPE==]';

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
// require_once('DB.php');

error_reporting(E_ALL & ~E_NOTICE);

// do not change
$MY_URI = 'http://'.$_SERVER['SERVER_NAME'][==PMH_PORT_NUMBER==].$_SERVER['SCRIPT_NAME'];
# echo $MY_URI . '<BR />';

// MUST (only one)
// please adjust
$repositoryName       = '[==PMH_REPOSITORY_NAME==]';
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
$deletedRecord        = 'transient'; 

// MAY (only one)
//granularity is days
$granularity          = 'YYYY-MM-DD';
// granularity is seconds
// $granularity          = 'YYYY-MM-DDThh:mm:ssZ';

// MUST (only one)
// the earliest datestamp in your repository,
// please adjust
$earliestDatestamp    = '[==PMH_EARLIEST_DATESTAMP==]';

// this is appended if your granularity is seconds.
// do not change
if ($granularity == 'YYYY-MM-DDThh:mm:ss:Z') {
	$earliestDatestamp .= 'T00:00:00Z';
}

// MUST (multiple)
// please adjust
$adminEmail			= array('mailto:[==OPERATOR_EMAIL==]'); 

// MAY (multiple) 
// Comment out, if you do not want to use it.
// Currently only gzip is supported (you need output buffering turned on, 
// and php compiled with libgz). 
// The client MUST send "Accept-Encoding: gzip" to actually receive 
// compressed output.
//$compression		= array('gzip');
$compression		= '';

// MUST (only one)
// should not be changed
$delimiter			= ':';

// MUST (only one)
// You may choose any name, but for repositories to comply with the oai 
// format for unique identifiers for items records. 
// see: http://www.openarchives.org/OAI/2.0/guidelines-oai-identifier.htm
// Basically use domainname-word.domainname
// please adjust
$repositoryIdentifier = '[==PMH_REPOSITORY_IDENTIFIER==]'; 


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
$MAXRECORDS = [==PMH_MAXRECORDS==];

// maximum mumber of identifiers to deliver
// (verb is ListIdentifiers)
// If there are more identifiers to deliver
// a ResumptionToken will be generated.
$MAXIDS = [==PMH_MAXRECORDS==];

// After 24 hours resumptionTokens become invalid.
$tokenValid = 24*3600;
$expirationdatetime = gmstrftime('%Y-%m-%dT%TZ', time()+$tokenValid); 

// define all supported sets in your repository
//$SETS = 	array (); 
$SETS = 	''; 
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
					'myhandler'=>'record_gen.php',
					'record_prefix'=>'dc',
					'record_namespace' => 'http://purl.org/dc/elements/1.1/'
			                ),
				'dif' => array('metadataPrefix'=>'dif', 
					'schema'=>'http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/dif_v9.7.1.xsd',
					'metadataNamespace'=>'http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/',
					'myhandler'=>'record_gen.php',
					'record_namespace' => ''
			                )
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
// $DSN = "pgsql://$DB_USER$DB_PASSWD@$DB_HOST/$DB_NAME";
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
// $SQL['split'] = ';';

// the name of the table where your store your metadata
$SQL['table'] = 'DataSet';

// the name of the column where you store your sequence 
// (or autoincrement values).
$SQL['id_column'] = 'DS_id';

// the name of the column where you store the unique identifiers
// pointing to your item.
// this is your internal identifier for the item
$SQL['identifier'] = 'DS_name';

// If you want to expand the internal identifier in some way
// use this (but not for OAI stuff, see next line)
$idPrefix = 'metamod/';

// this is your external (OAI) identifier for the item
// this will be expanded to
// oai:$repositoryIdentifier:$idPrefix$SQL['identifier']
// should not be changed
$oaiprefix = "oai".$delimiter.$repositoryIdentifier.$delimiter.$idPrefix; 

// adjust anIdentifier with sample contents an identifier
$sampleIdentifier     = $oaiprefix.'anIdentifier';

// the name of the column where you store your datestamps
$SQL['datestamp'] = 'DS_datestamp';

// the name of the column where you store information whether
// a record has been deleted. Leave it as it is if you do not use
// this feature.
$SQL['deleted'] = 'DS_status';

// to be able to quickly retrieve the sets to which one item belongs,
// the setnames are stored for each item
// the name of the column where you store sets
// NOTE: This implementation does not support sets. The DS_set element
// is set to an empty string for all records.
$SQL['set'] = '';

// Here are a couple of queries which might need to be adjusted to 
// your needs. Normally, if you have correctly named the columns above,
// this does not need to be done.

// this function should generate a query which will return
// all records
// the useless condition id_column = id_column is just there to ease
// further extensions to the query, please leave it as it is.

function mmPutLog($string) {
   $logfile = '[==WEBRUN_DIRECTORY==]' . '/oaipmhlog';
   $fd = fopen($logfile,"a");
   fwrite($fd,date("Y-m-d H.i: ") . $string . "\n");
   fflush($fd);
   fclose($fd);
}

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
function getRecords ($id = '', $from = '', $until = '') {
   global $mmDbConnection;
   global $metadataPrefix;
   global $key_conversion;
   if ($metadataPrefix == 'oai_dc') {
      $key_conversion = array(
         'title', 'dc:title','',
         'institution', 'dc:creator','',
         'topic', 'dc:subject','',
         'keywords', 'dc:subject','',
         'variable', 'dc:subject','',
         'topiccategory', 'dc:subject','',
         'abstract', 'dc:description','',
         'dataref', 'dc:identifier','',
         'datacollection_period', 'dc:coverage','',
         'area', 'dc:coverage','',
         'distribution_statement', 'dc:rights',''
         );
   } else if ($metadataPrefix == 'dif') {
      $key_conversion = array(
         '!DS_name 1', 'Entry_ID', '',
         'title', 'Entry_Title', '',
         'PI_name', 'Data_Set_Citation Dataset_Creator', '',
         'title', 'Data_Set_Citation Dataset_Title', '',
         'institution', 'Data_Set_Citation Dataset_Publisher', '',
         'dataref', 'Data_Set_Citation Online_Resource', '',
         'variable', '*Parameters Category', 'EARTH SCIENCE',
         'variable 1', 'Parameters Topic', '',
         'variable 2', 'Parameters Term', '',
         'variable 3', 'Parameters Variable_Level_1', '',
         'variable', 'Parameters Detailed_Variable', '',
         'topiccategory', 'ISO_Topic_Category', '',
         'keywords', 'Keyword', '',
         'datacollection_period 1', 'Temporal_Coverage Start_Date', '',
         'datacollection_period 2', 'Temporal_Coverage Stop_Date', '',
         'southernmost_latitude', 'Spatial_Coverage Southernmost_Latitude', '',
         'northernmost_latitude', 'Spatial_Coverage Northernmost_Latitude', '',
         'westernmost_longitude', 'Spatial_Coverage Westernmost_Longitude', '',
         'easternmost_longitude', 'Spatial_Coverage Easternmost_Longitude', '',
         'area 1', '*Location Location_Category', '',
         'area 2', 'Location Location_Type', '',
         'area 3', 'Location Location_Subregion1', '',
         'area 4', 'Location Detailed_Location', '',
         'latitude_resolution 1', 'Data_Resolution Latitude_Resolution', '',
         'longitude_resolution 1', 'Data_Resolution Longitude_Resolution', '',
         '!DS_ownertag 1', 'Project Short_Name', '',
         'distribution_statement', 'Access_Constraints', '',
         'institution', 'Originating_Center', '',
         '', 'Data_Center Data_Center_Name Short_Name', 'met.no',
         '', 'Data_Center Data_Center_Name Long_Name', 'Norwegian Meteorological Institute',
         '', 'Data_Center Data_Center_URL', 'http://met.no/',
         '', 'Data_Center Personnel Role', 'DATA CENTER CONTACT',
         '', 'Data_Center Personnel First_Name', 'Egil',
         '', 'Data_Center Personnel Last_Name', 'Støren',
         '', 'Data_Center Personnel Phone', '+4722963000',
         '', 'Data_Center Personnel Contact_Address Address', "Norwegian Meteorological Institute\nP.O. Box 43\nBlindern",
         '', 'Data_Center Personnel Contact_Address City', 'Oslo',
         '', 'Data_Center Personnel Contact_Address Postal_Code', 'N-0313',
         '', 'Data_Center Personnel Contact_Address Country', 'Norway',
         'references', 'Reference', '',
         'abstract', 'Summary', '',
         '', 'Metadata_Name', 'CEOS IDN DIF',
         '', 'Metadata_Version', '9.7',
         '!DS_datestamp', 'Last_DIF_Revision_Date', '',
         '', 'Private', 'False',
      );
   }
   $query = 'SELECT DS_id, DS_name, DS_status, DS_datestamp, DS_ownertag FROM DataSet WHERE ' .
            "DS_status <= 2 AND DS_ownertag IN ([==DATASET_TAGS==]) ";
   if ($id != '') {
      $query .= "AND DS_name = '$id' ";
   }
   if ($from != '') {
      $query .= "AND DS_datestamp >= '$from' ";
   }
   if ($until != '') {
      $query .= "AND DS_datestamp <= '$until' ";
   }
   $result1 = pg_query ($mmDbConnection, $query);
   $dsids = array();
   $allresults = array();
   if (!$result1) {
      mmPutLog(__FILE__ . __LINE__ . " Could not $query");
      return FALSE;
   } else {
      $num = pg_numrows($result1);
      if ($num > 0) {
         for ($i1=0; $i1 < $num;$i1++) {
            $rowarr = pg_fetch_row($result1,$i1);
            $dsid = $rowarr[0];
            $dsids[$i1] = $dsid;
            $allresults[$dsid]['DS_name'] = $rowarr[1];
            if ($rowarr[2] == 1) {
               $allresults[$dsid]['DS_status'] = 'false';
            } else {
               $allresults[$dsid]['DS_status'] = 'true';
            }
            $allresults[$dsid]['DS_datestamp'] = $rowarr[3];
            $allresults[$dsid]['DS_ownertag'] = $rowarr[4];
            $allresults[$dsid]['DS_set'] = '';
         }
         $mtnames = array();
         for ($i1=0; $i1 < count($key_conversion); $i1 += 3) {
            if ($key_conversion[$i1] != '') {
               $mtparts = explode(" ",$key_conversion[$i1]);
               $mtstring = $mtparts[0];
               if (substr($mtstring,0,1) != '!') {
                  $mtnames[$mtstring] = 1;
               }
            }
         }
         $query = "SELECT DS_id, MT_name, MD_content FROM DS_Has_MD, Metadata WHERE " .
                  "DS_Has_MD.MD_id = Metadata.MD_id AND DS_id IN (" .
                  implode(', ',$dsids) . ") AND MT_name IN ('" .
                  implode("', '",array_keys($mtnames)) . "' )\n";
         $result1 = pg_query ($mmDbConnection, $query);
         if (!$result1) {
            mmPutLog(__FILE__ . __LINE__ . " Could not $query");
            return FALSE;
         } else {
            $num2 = pg_numrows($result1);
            if ($num2 > 0) {
               for ($i1=0; $i1 < $num2;$i1++) {
                  $rowarr = pg_fetch_row($result1,$i1);
                  $dsid = $rowarr[0];
                  $mtname = $rowarr[1];
                  $mdcontent = html_entity_decode($rowarr[2]);
                  if ($mtname == "keywords") {
                     foreach (explode(" ",$mdcontent) as $w1) {
                        if (strlen($w1) > 1) {
                           $allresults[$dsid][$mtname][] = $w1;
                        }
                     }
                  } else {
                     $allresults[$dsid][$mtname][] = $mdcontent;
                  }
               }
            }
         }
      }
   }
   return $allresults;
}

// this function will return identifier and datestamp for all records
function idQuery ($id = '')
{
	global $SQL;

	if ($SQL['set'] != '') {
		$query = 'select distinct '.$SQL['identifier'].','.$SQL['datestamp'].','.
                         $SQL['deleted'].','.$SQL['set'].' FROM '.$SQL['table'];
	} else {
		$query = 'select distinct '.$SQL['identifier'].','.$SQL['datestamp'].','.
                         $SQL['deleted'].' FROM '.$SQL['table'];
	}
        $query .= " WHERE DS_status <= 2 AND DS_ownertag IN ([==DATASET_TAGS==])";
	
	if ($id != '') {
		$query .= ' AND '.$SQL['identifier']." = '$id'";
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
