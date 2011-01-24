<?php
/*
 * Created on Aug 11, 2009
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
require_once("mmLogging.inc");

class MM_OaiPmh {
	private $dom;
	private $xpath;
	private $oaiNamespace = "http://www.openarchives.org/OAI/2.0/";

	/**
	 * retrieve a new object from a xml-string
	 */
	function __construct($inputXml) {
		$this->dom = new DOMDocument();
	   if (!$this->dom->loadXML($inputXml)) {
			mm_log(MM_ERROR, "unable to parse xml-string with '$inputXml'", __FILE__, __LINE__);
		   throw new Exception("unable to parse xml-string with '$inputXml'");
	  	}
	  	$this->xpath = new DomXPath($this->dom);
	  	$this->xpath->registerNamespace('oai', $this->oaiNamespace);
 	}
	
	/**
	 * @return the oai-pmh schema
	 */
	static function getOAI_PMH_Schema() {
		global $mmConfig;
		return $mmConfig->getVar("TARGET_DIRECTORY") . "/schema/OAI-PMH.xsd"; 	   
	}
	
	/**
	 * @return associated array with namespaces as keys and schema-files as values
	 */
	static function getKnownRecordSchemas() {
	   global $mmConfig;
	   return array(
			"http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/" => $mmConfig->getVar("TARGET_DIRECTORY") . "/schema/dif_v9.8.xsd",
	   	"http://purl.org/dc/elements/1.1/" => $mmConfig->getVar("TARGET_DIRECTORY") . "/schema/simpledc20021212.xsd",
	   	"http://www.openarchives.org/OAI/2.0/oai_dc/" => $mmConfig->getVar("TARGET_DIRECTORY") . "/schema/oai_dc.xsd"
	   );
	}
	
	/**
	 * validate the object for OAI-PMH
	 */
	function validateOAI() {
	   return $this->dom->schemaValidate($this->getOAI_PMH_Schema());
	}
	
	/** @return true if the node validates
	 *  text-node allways 'validate'
	 *  unknown nodes allways validate
	 */
	private function validateMetadata(DOMNode $metadataNode) {
		// detect the type/namespace of the metadata
		$md = $metadataNode;
	  	if ($md->nodeType == XML_ELEMENT_NODE) {
		  	$namespace = $md->namespaceURI;
        	$schemas = $this->getKnownRecordSchemas();
	      if (strlen($namespace) && array_key_exists($namespace, $schemas)) {
	      	$schema = $schemas[$namespace];
	         if (strlen($schema)) {
	         	$recordDom = new DOMDocument();
	            $recordDom->appendChild($recordDom->importNode($md, true));
	            if (!$recordDom->schemaValidate($schema)) {
	            	return false;
	            }
            }
         }
	  	}
	  	return true;
	} 
	
	/**
	 * validate all records of the OAI-PMH response, which have a known schema
	 * @return true if all records validate
	 */
	function validateRecords() {
		// get records metadata
	   foreach ($this->xpath->query('*/oai:record/oai:metadata/*') as $md) {
	      if (!$this->validateMetadata($md)) {
	         return false;
	      }
	   }
	   return true; // all records validate
	}
	
	/**
	 * remove all invalid records
	 * @return number of invalid records removed
	 */
	function removeInvalidRecords() {
		$count = 0;
		foreach ($this->xpath->query('*/oai:record') as $record) {
		   foreach ($this->xpath->query('oai:metadata/*', $record) as $md) {
		   	// should be 1 at maximum (not counting eventual text nodes)
		      if (!$this->validateMetadata($md)) {
		      	$meta = $this->xpath->query('oai:metadata', $record)->item(0);
		         $record->removeChild($meta);
		         $header = $this->xpath->query('oai:header', $record)->item(0);
		         $header->removeAttribute('status');
		         $header->setAttribute('status', 'deleted');
		         $count++;
		         break; // go to next record
		      }
		   }
		}
		return $count;
	}
	
	/**
	 * get the document as XML string
	 */
	function getOAI_XML() {
	   return $this->dom->saveXML();
	}
}

?>
