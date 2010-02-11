<?php
/*
 * Created on Aug 21, 2009
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
/** Class for hiding the xml-structure and giving easy access to the WMSInfo string.
 * 
 * Example of WMCSetup string
 * <mm:wmcSetup xmlns:mm="http://www.met.no/schema/metamod/wmcSetup">
 *   <mm:datasetName regex="!!" replace=""/>
 *   <ViewContext xmlns="http://www.opengis.net/context">...</ViewContext>
 * </mm:wmcSetup>
 */
class MM_WMSSetup {
   protected $regex = false;
   protected $replace = false;
   const datasetReplace = '%DATASETNAME%';
   const onlineResourceReplace = '%WMS_ONLINE_RESOURCE%';
   private $wmcTemplate = "";
   const wmsInfoNS = "http://www.met.no/schema/metamod/wmcSetup";
   const wmcNS = "http://www.opengis.net/context";

	static function getWMCSetupSchema() {
		global $mmConfig;
		return $mmConfig->getVar("TARGET_DIRECTORY") . "/schema/wmcSetup.xsd"; 	   
	}
   
   /**
    * create a new MM_WMSSetup from a string
    * @param $str xml-string
    * @param $validate boolean flag, validate xml-string, default false
    * @throws MM_DatasetException if the string is not parseable
    */
   function __construct($str, $validate = false) {
      if (strlen($str)) {
                  $dom = new DOMDocument();
         if (!$dom->loadXML($str)) {
         	mm_log(MM_ERROR, "unable to parse xml-string $str", __FILE__, __LINE__);
         	throw new MM_DatasetException("unable to parse xml-string $str");
         }
         if ($validate) {
            if (! @$dom->schemaValidate($this->getWMCSetupSchema())) {
            	// PHP_ERRORMSG requires track_errors to be enabled
               throw new MM_DatasetException("invalid xml-file: ".$PHP_ERRORMSG);
            }
         }
         $xpath = new DomXPath($dom);
         $xpath->registerNamespace('wi', self::wmsInfoNS);
         $xpath->registerNamespace('wmc', self::wmcNS);
         
         foreach ($xpath->query('/wi:wmcSetup/wi:datasetName') as $node) {
				foreach ($node->attributes as $att) {
				   if ($att->name == 'regex') {
				      $this->regex = $att->value;
				   } else if ($att->name == 'replace') {
				      $this->replace = $att->value;
				   }
				}            
         }
         foreach ($xpath->query('/wi:wmcSetup/wmc:ViewContext') as $node) {
            $wcsDom = new DOMDocument();
            $node = $wcsDom->importNode($node, true);
				$wcsDom->appendChild($node);
				$this->wmcTemplate = $wcsDom->saveXML();
         }
      }
   }
   
   /**
    * get the regex to match the name against 
    */
   function getRegex() {
      return $this->regex;
   }
   /**
    * get the regex/replace to change the name with 
    */
   function getReplace() {
      return $this->replace;
   }
   
   /**
    * Get the wmc-file for the dataset with the name $datasetName.
    * The datasetName is required here since the constructor doesn't 
    * require it.
    * @param $datasetName name of the dataset, must be level 2
    */
   function getDatasetWMC($datasetName) {
		global $mmConfig;
      $dsName = preg_replace($this->getRegex(), $this->getReplace(), $datasetName);
      
      // modify the dataset-name
      $wmc = preg_replace("!".self::datasetReplace . "!", $dsName, $this->wmcTemplate);
      // and change the online-resource depending on the config
      $wmc = preg_replace("!".self::onlineResourceReplace."!", $mmConfig->getVar('WMS_ONLINE_RESOURCE'), $wmc);
      return $wmc;
   }
}

/**
 * get a MM_WMSSetup from the postgres database $dbh and the name $datasetName
 * @param $pgDB postgres database handle
 * @param $datasetName name of the dataset, may be level 1 or 2
 */
function getWMSSetupFromDb($pgDB, $datasetName) {
	if (strlen($datasetName) == 0) {
	   return false;
	}
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
		return new MM_WMSSetup($row[0]);
	}
	return false;
}

/**
 * check if a wms setups exist for the dsid or its parent
 * @param $pgDB database handle
 * @param $dsid datasetId or datasetId of parent
 */
function checkWMSSetupExistsInDb($pgDB, $dsid) {
   $sql = 'SELECT WMSInfo.DS_id FROM WMSInfo, Dataset '.
          ' WHERE WMSInfo.DS_id = Dataset.DS_id '.
	     	 '   AND (WI_content IS NOT NULL AND WI_content != \'\')'.          
          '   AND (Dataset.DS_id = $1 OR Dataset.DS_parent = $1 )';
	$result = pg_query_params($pgDB, $sql, array($dsid));
	if (!$result) {
	  	mm_log(MM_ERROR, "Could not execute $sqlsentence", __FILE__, __LINE__);
     	die("Internal Error");
	}
	return pg_num_rows($result) > 0;
}

?>
