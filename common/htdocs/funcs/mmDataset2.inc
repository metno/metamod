<?php
/*
 * Created on Oct 22, 2008
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
// TODO: switch to using DOM
require_once("mmLogging.inc");
class MM_Dataset2 {
	private $dom; // root-node of the dataset
	private $xpath;
	private $namespace = "http://www.met.no/schema/metamod/dataset2/";
	
	
	/**
	 * construct a MM_Dataset2
	 * 
	 * @param $input The input can be "", then a new dataset will be created (default);
	 *               input can be a DOMNode, then that node will be the source for the dataset
	 *               if (input_is_data), input is assumed to be an xml-string
	 *               otherwise, input is assumed to be a filename
	 * @param $input_is_data set true if input is a xml-string rather than a filename
	 * @throw MM_Dataset2Exception
	 */
	function __construct($input = "", $input_is_data = false) {
		if (!$input) {
			$data =
'<?xml version="1.0" encoding="iso8859-1"?>
<?xml-stylesheet href="dataset2View.xsl" type="text/xsl"?>
<dataset xmlns="http://www.met.no/schema/metamod/dataset2/" 
         xmlns:ns1="http://www.w3.org/2001/XMLSchema-instance"
         ns1:schemaLocation="http://www.met.no/schema/metamod/dataset2/ metamodDataset2.xsd">
  <info status="active" creationDate="1970-01-01T00:00:00Z" ownertag="" drpath=""/>
</dataset>';
		} elseif (is_object($input) && ($input instanceof DOMNode)) {
			$data = DOMDocument::saveXML($input);
		} elseif ($input_is_data) {
			$data = $input;
		} else {
			if (! file_exists($input)) {
				throw new MM_Dataset2Exception("file '$input' not found");
			}
			// file_get_contents does not support LOCK_SH, open and read manually
			$fh = fopen($input, "r");
			if (!$fh) {
				throw new MM_DatasetException("cannot read '$input'");
			}
			flock($fh, LOCK_SH);
			$data = fread($fh, filesize($input));
			fclose($fh); // fclose also unlocks
		}
		$this->dom = new DOMDocument();		
		if (!$this->dom->loadXML($data)) {
			mm_log(MM_ERROR, "unable to parse xml-string wit '$data'", __FILE__, __LINE__);
			throw new MM_Dataset2Exception("unable to construct dataset2 with '$data'");
		}
		$this->xpath = new DomXPath($this->dom);
		$this->xpath->registerNamespace('d', $this->namespace);
		if ($this->xpath->query('/d:dataset/d:info')->length != 1) {
			throw new MM_Dataset2Exception("failed to open xml: not a dataset2 document");
		}
	}


	/**
	 * read the info of the dataset
	 * @return array with info attribute - value pairs
	 */
	function getInfo() {
		$retVal = array();
		$info = $this->xpath->query('/d:dataset/d:info')->item(0);
		foreach ($info->attributes as $attr) {
			$retVal[$attr->name] = $attr->value;
		}
		return $retVal;
	}
	
	/**
	 * add new info to the dataset, overwriting existing items
	 * @param $info array with attribute - value pairs
	 */
	function addInfo(array $info) {
		$info = array_merge($this->getInfo(), $info);
		$dinfo = $this->xpath->query("/d:dataset/d:info")->item(0);
		foreach ($info as $name => $val) {
			$dinfo->setAttribute($name, $val);
		}
	}
	
	/**
	 * read the metadata from the dataset
	 * @return array with metadata_name -> [value] pairs. 
	 *         value is an array of values, one per element
	 * 
	 */
	function getMetadata() {
		$retVal = array();
		foreach ($this->xpath->query('/d:dataset/d:metadata') as $mdata) {
			$value = "";
			foreach ($mdata->childNodes as $child) {
				if ($child->nodeType == XML_TEXT_NODE) {
      				$value .= $child->nodeValue;
    			}
			} 
			$retVal[$mdata->getAttribute("name")][] = $value;
		}
		return $retVal;
	}
	
	/**
	 * Add a metadata-element, this will append, not overwrite existing metadata names.  
	 * 
	 * @param $metadata array with (name => [value]) pairs. value should be an array with values
	 */
	function addMetadata($metadata) {
		$node = $this->xpath->query('/d:dataset')->item(0);
		foreach ($metadata as $name => $values) {
			foreach ($values as $value) {
				$el = $this->dom->createElementNS($this->namespace,'metadata');
				$el->setAttribute("name", $name);
				$txt = $this->dom->createTextNode($value);
				$el->appendChild($txt);
				$node->appendChild($el);
			}
		}
	}
	
	/**
	 * Remove all metadata-elements with the names in $names
	 * @param $names array with metadata-names to remove
	 * 
	 */
	function removeMetadata($names) {
		foreach ($names as $name) {
			foreach ($this->xpath->query("/d:dataset/d:metadata[@name='$name']") as $node) {
				$node->parentNode->removeChild($node);
			}
		}
	}
	/**
	 * Retrieve datasetcollection_period from and to values.
	 * @return array(from, to), returns empty array if tag not found 
	 */
	function getPeriod() {
		$nodelist = $this->xpath->query("/d:dataset/d:datacollection_period");
		if ($nodelist->length == 1) {
			$node = $nodelist->item(0);
			$from = $node->getAttribute("from");
			$to = $node->getAttribute("to");
			return array($from, $to);
		}
		return array();
	}
	/**
	 * Set/overwrite the datacollection_period.
	 * @param $from time as string YYYY-MM-DDTHH:MM:SSZ, deletes datacollection_period if $to is not set
	 * @param $to time as string YYYY-MM-DDTHH:MM:SSZ
	 * @return array(oldFrom, oldTo) or array() if not existing
	 */
	function setPeriod($from, $to) {
		$oldVals = $this->getPeriod();
		if (count($oldVals) > 0) {
			// delete old item
			foreach ($this->xpath->query("/d:dataset/d:datacollection_period") as $node) {
				$node->parentNode->removeChild($node);
			}
		}
		$ds = $this->xpath->query("/d:dataset")->item(0);
		if ($from) {
			$period = $this->dom->createElementNS($this->namespace,'datacollection_period');
			$period->setAttribute('to', $to);
			$period->setAttribute('from', $from);
			$nodelist = $this->xpath->query("/d:dataset/*");
			$inserted = false;
			foreach ($nodelist as $node) {
				if ($node->nodeName != 'info' ) {
					$ds->insertBefore($period, $node);
					$inserted = true;
				}
			}
			if (!$inserted) {
				$ds->appendChild($period);
			}
		}
		return $oldVals;
	}

	/**
	 * Retrieve the quadtree-nodes as list.
	 * 
	 * @return array(1,11, ...)
	 */
	function getQuadtree() {
		$retVal = array();
		$nodelist = $this->xpath->query("/d:dataset/d:quadtree_nodes");
		if ($nodelist->length == 1) {
			$quadStr = "";
			foreach ($nodelist->item(0)->childNodes as $child) {
				if ($child->nodeType == XML_TEXT_NODE) {
					$quadStr .= $child->nodeValue;
				}	
			}
			$retVal = preg_split("/\s+/", $quadStr, -1, PREG_SPLIT_NO_EMPTY);
		}
		return $retVal;
	}
	/**
	 * Set/overwrite the quadtree_nodes.
	 * @param $quadtreeNodes array with quadtree nodes
	 * @return array($oldQuadtreeNodes)
	 */
	function setQuadtree($quadtreeNodes) {
		$oldVals = $this->getQuadtree();
		if (count($oldVals) > 0) {
			// delete old item
			foreach ($this->xpath->query("/d:dataset/d:quadtree_nodes") as $node) {
				$node->parentNode->removeChild($node);
			}
		}
		$ds = $this->xpath->query("/d:dataset")->item(0);
		if (count($quadtreeNodes)) {
			$nodeStr = "";
			foreach ($quadtreeNodes as $quadNode) {
				$nodeStr .= "$quadNode\n";
			}
			$quadtreeNode = $this->dom->createElementNS($this->namespace,'quadtree_nodes');
			$quadtreeNode->appendChild($this->dom->createTextNode($nodeStr));

			$nodelist = $this->xpath->query("/d:dataset/*");
			$inserted = false;
			foreach ($nodelist as $node) {
				if ($node->nodeName != 'info' && $node->nodeName != 'datacollection_period') {
					$ds->insertBefore($quadtreeNode, $node);
					$inserted = true;
					break;
				}
			}
			if (!$inserted) {
				$ds->appendChild($quadtreeNode);
			}
		}
		return $oldVals;
	}

	/**
	 * get a xml string of this metadata
	 * @return xml
	 */
	function getXML() {
		return $this->dom->saveXML();
	}
	
}

class MM_Dataset2Exception extends Exception {
	public function __construct($message, $code = 0) {
    	// make sure everything is assigned properly
   		parent::__construct($message, $code);
	}
	// overload the __toString() method to suppress any "normal" output
  	public function __toString() {
    	return $this->getMessage();
  	}
  	// static exception_handler for default exception handling
  	public static function exception_handler($exception) {
    	throw new DatasetException($exception);
  	}
}
?>
