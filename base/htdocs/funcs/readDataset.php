<?php
/*
 * Created on Oct 3, 2008
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

#
# read a dataset from an xml file
# remove the quadtree element and unify the datacollectionperiod
#
# return as array["metadata"] = [value1, value2, ...]
# throws DatasetException on error
#
function mmReadEssentialDataset($filename) {
	$ds = mmReadDataset($filename);
	return $ds;
}

#
# basic read of the dataset in tag => [value1, value2, ...] pairs
# return array[][]
# throws DatasetException on error
#
function mmReadDataset($filename) {
	if (! file_exists($filename)) {
		throw new DatasetException("file '$filename' not found");
	}
	$dom = new DOMDocument;
	$dom->load($filename);
	
	$output = array();
	if (! $dom) {
		throw new DatasetException("error parsing dataset file: '$filename'");
	}
	$root = $dom->getElementsByTagName('dataset')->item(0);
	if ($root->hasChildNodes()) {
    	$children = $root->childNodes;
    	for ($i=0;$i<$children->length;$i++) {
        	$child = $children->item($i);
			if ($child->nodeType == XML_ELEMENT_NODE) {
				if (! isset($output[$child->nodeName])) {
					$output[$child->nodeName] = array();					
				}
				if ($child->hasChildNodes()) {
					$grandChildren = $child->childNodes;
					$values = array();
					for ($j=0; $j<$grandChildren->length; $j++) {
						$valueNode = $grandChildren->item($j);
						if ($valueNode->nodeType == XML_TEXT_NODE) {
							$output[$child->nodeName][] = $valueNode->nodeValue;
						}
					}
				}
			}
    	}
	}
	return $output;
}

class DatasetException extends Exception {
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
