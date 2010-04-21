<?php
/*
 * Created on Feb 10, 2010
 *
 *---------------------------------------------------------------------------- 
 * METAMOD - Web portal for metadata search and upload 
 *
 * Copyright (C) 2010 met.no 
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

include_once "mmWMS.inc";
include_once "mmConfig.inc"

?>
<?php
/** Class for hiding the xml-structure and giving easy access to the WMSInfo string.
 * 
 * Example of WMSInfo string
 * <mm:ncWmsSetup xmlns:mm="http://www.met.no/schema/metamod/ncWmsSetup" url="http://thredds.met.no/wms/osisaf/ice_conc.nc"/>
 *
 */
class MM_WMSSetup2 {
   private $wmsTemplate = "";
   const wmsSetupNS = "http://www.met.no/schema/metamod/ncWmsSetup";

	static function getSchema() {
		global $mmConfig;
		return $mmConfig->getVar("TARGET_DIRECTORY") . "/schema/ncWmsSetup.xsd"; 	   
	}
   
   /**
    * create a new MM_WMSSetup2 from a string
    * @param $str xml-string
    * @param $isParent true if initialized from a parent (catalog) dataset
    * @param $validate boolean flag, validate xml-string, default false
    * @throws MM_DatasetException if the string is not parseable
    */
   function __construct($str, $isParent = true, $validate = false) {
   	// contains attributes: isParent, isComplex, dom, xpath, rul
   	$this->isParent = $isParent;
      if (strlen($str)) {
         $this->dom = new DOMDocument();
         if (!$this->dom->loadXML($str)) {
         	mm_log(MM_ERROR, "unable to parse xml-string $str", __FILE__, __LINE__);
         	throw new MM_DatasetException("unable to parse xml-string $str");
         }
         if ($validate) {
            if (! @$this->dom->schemaValidate($this->getSchema())) {
            	// PHP_ERRORMSG requires track_errors to be enabled
               throw new MM_DatasetException("invalid xml-file: ".$PHP_ERRORMSG);
            }
         }
         $this->xpath = new DomXPath($this->dom);
         $this->xpath->registerNamespace('wi', self::wmsSetupNS);
         
       }
   }
   
   /**
    * get the real url, (replacing %DATASET_PARENT% and %DATASET% with the $datasetName)
    * change the url of this if required
    */
   function getUrl($datasetName = '') {
      $url = "";
      foreach ($this->xpath->query('/wi:ncWmsSetup') as $node) {
         foreach ($node->attributes as $att) {
            if ($att->name == 'url') {
               $url = $att->value;
               if (strlen($datasetName)) {
               	list($tag, $parent, $dataset) = preg_split('^/^', $datasetName);
               	if (strlen($dataset) == 0) {
               		// no parent
               	   $dataset = $parent;
               	}
               	$url = preg_replace('/%DATASET%/', $dataset, $url);
               	$url = preg_replace('/%DATASET_PARENT%/', $parent, $url);
                  $att->nodeValue = $url;
               }
				}
         }          
      }
      return $url;
   }
   
   function isComplex() {
   	if ($this->xpath->query('/wi:ncWmsSetup/wi:displayArea')->length > 0) {
   		return true;
   	}
   	return false;
   }
   
   /**
    * get the url
    * if 'isParent', replaced by datasetName as project/parent/datasetFile, i.e.
    * http://wms.met.no/my/path/file.nc to
    * http://wms.met.no/my/path/datasetFile.nc
    */
   function getClientUrl($datasetName = '') {
   	global $mmConfig;
   	if ($this->isComplex()) {
   		if (strlen($datasetName) == 0) {
   		   echo "internal error, require dataset for getClientUrl: ".$this->xpath->query('/wi:displayArea')->length;
   		}
       // Fix by Egil: If LOCAL_URL contains http://servername, remove it before appending to $wmssetupUrl:
       $localurl = $mmConfig->getVar('LOCAL_URL');
       if (preg_match ('/^https?\/\/[^\/:]+:?\d*(\/.*)$/',$localurl,$localurl_matches)) {
          $localurl = $localurl_matches[1];
       }
       // deliver as wmssetup
       $wmssetupUrl = ($_SERVER['HTTPS'] ? 'https://': 'http://') . $_SERVER['SERVER_NAME'].
        ($_SERVER['SERVER_PORT'] == 80 ? '' : ':'.$_SERVER['SERVER_PORT']) . $localurl;
   		$wmssetupUrl .= '/sch/getWMSSetup.php?datasetName='.$datasetName;
   		return "wms.php?wmssetup=". urlencode($wmssetupUrl);
   	} else {
   		// deliver server-url only
	   	$wmsServerUrl = '';
   		if (!$this->isParent) {
   		   $wmsServerUrl = $this->getUrl();
   		} else {
	   		if (strlen($datasetName) == 0) {
   	   		$wmsServerUrl = $this->getUrl();
   			} else {
   				if (preg_match(':/([^/]+)$:', $datasetName, $matches)) {
   	   			$wmsServerUrl = preg_replace(':/[^/]+.nc$:', '/'. $matches[1] . '.nc', $this->getUrl());
   				} else {
	   				echo "doesn't match";
   			   	$wmsServerUrl = $this->getUrl();
   				}
   			}
   		}
   		$wmsServerUrl = urlencode($wmsServerUrl);
   		return "wms.php?wmsurl=".$wmsServerUrl;
   	}
   }
   
   /**
    * isParent: check if the wmsSetup is derived from a parent dataset or a child
    */

	/**
	 * return the xml-document refering to this dataset
	 * @param dataset (optional dataset name)
	 */
	 function getDocument($dataset = "") {
	 	 if (strlen($dataset) > 0) {
	 	    $this->getUrl($dataset);
	 	 }
	    return $this->dom->saveXML();
	 }
}

/**
 * get a MM_WMSSetup from the postgres database $dbh and the name $datasetName
 * @param $pgDB postgres database handle
 * @param $datasetName name of the dataset, may be level 1 or 2
 */
function getWMSSetup2FromDb($pgDB, $datasetName) {
	if (strlen($datasetName) == 0) {
	   return false;
	}
	$isParent = false;
   // retrieve WMSInfo from database
	$sql = 'SELECT WI_content FROM WMSInfo, Dataset '.
		    ' WHERE DS_name = $1 '.
	     	 '   AND WMSInfo.DS_id = Dataset.DS_id '.
	     	 '   AND (WI_content IS NOT NULL AND WI_content != \'\')';
	$result = pg_query_params($pgDB, $sql, array($datasetName));
	if (!$result) {
	  	mm_log(MM_ERROR, "Could not execute $sqlsentence", __FILE__, __LINE__);
     	die("Internal Error");
	}
	if (pg_num_rows($result) != 1) {
		// try parent
		$isParent = true;
		$sql = 
'SELECT WI_content FROM WMSInfo ' .
' WHERE (WI_content IS NOT NULL AND WI_content != \'\') ' .
'   AND DS_id IN (SELECT DS_parent FROM Dataset WHERE DS_name = $1) ';
		$result = pg_query_params($pgDB, $sql, array($datasetName));
		if (!$result) {
   		mm_log(MM_ERROR, "Could not execute $sql", __FILE__, __LINE__);
     		die("Internal Error");
		}
	}
	if ($row = pg_fetch_row($result)) {
		return new MM_WMSSetup2($row[0], $isParent);
	}
	return false;
}

/**
 * get a MM_WMSSetup2 from the postgres database $dbh and the id $datasetId
 * @param $pgDB postgres database handle
 * @param $datasetId of the dataset, may be level 1 or 2
 */
function getWMSSetup2FromDbById($pgDB, $datasetId) {
	if (strlen($datasetId) == 0) {
	   return false;
	}
	$isParent = false;
   // retrieve WMSInfo from database
	$sql = 'SELECT WI_content FROM WMSInfo'.
		    ' WHERE WMSInfo.DS_id = $1 '.
	     	 '   AND (WI_content IS NOT NULL AND WI_content != \'\')';
	$result = pg_query_params($pgDB, $sql, array($datasetId));
	if (!$result) {
	  	mm_log(MM_ERROR, "Could not execute $sqlsentence", __FILE__, __LINE__);
     	die("Internal Error");
	}
	if (pg_num_rows($result) != 1) {
		// try parent
		$isParent = true;
		$sql = 
'SELECT WI_content FROM WMSInfo ' .
' WHERE (WI_content IS NOT NULL AND WI_content != \'\') ' .
'   AND DS_id IN (SELECT DS_parent FROM Dataset WHERE DS_id = $1) ';
		$result = pg_query_params($pgDB, $sql, array($datasetId));
		if (!$result) {
   		mm_log(MM_ERROR, "Could not execute $sql", __FILE__, __LINE__);
     		die("Internal Error");
		}
	}
	if ($row = pg_fetch_row($result)) {
		return new MM_WMSSetup2($row[0], $isParent);
	}
	return false;
}

/**
 * get a MM_WMSSetup2 or a MM_WMSSetup from the postgres database $dbh and the id $datasetId
 * @param $pgDB postgres database handle
 * @param $datasetId of the dataset, may be level 1 or 2
 */
function getGeneralWMSSetupFromDbById($pgDB, $datasetId) {
	if (strlen($datasetId) == 0) {
	   return false;
	}
	$isParent = false;
   // retrieve WMSInfo from database
	$sql = 'SELECT WI_content FROM WMSInfo'.
		    ' WHERE WMSInfo.DS_id = $1 '.
	     	 '   AND (WI_content IS NOT NULL AND WI_content != \'\')';
	$result = pg_query_params($pgDB, $sql, array($datasetId));
	if (!$result) {
	  	mm_log(MM_ERROR, "Could not execute $sqlsentence", __FILE__, __LINE__);
     	die("Internal Error");
	}
	if (pg_num_rows($result) != 1) {
		// try parent
		$isParent = true;
		$sql = 
'SELECT WI_content FROM WMSInfo ' .
' WHERE (WI_content IS NOT NULL AND WI_content != \'\') ' .
'   AND DS_id IN (SELECT DS_parent FROM Dataset WHERE DS_id = $1) ';
		$result = pg_query_params($pgDB, $sql, array($datasetId));
		if (!$result) {
   		mm_log(MM_ERROR, "Could not execute $sql", __FILE__, __LINE__);
     		die("Internal Error");
		}
	}
	if ($row = pg_fetch_row($result)) {
		if (preg_match('!ncWmsSetup!', $row[0])) {
			return new MM_WMSSetup2($row[0], $isParent);
		} elseif (preg_match('!wmcSetup!', $row[0])){
		   return new MM_WMSSetup($row[0]);
		}
	}
	return false;
}



?>
