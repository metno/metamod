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
require_once("mmLogging.inc");
require_once("mmTtime.inc");

/**
 * convert a filename of a xm[ld] file to a string without appendix
 * @param $file regular filename of any of the dataset xml or xmd file
 * @return $file without appendix
 */
function mmGetBasename($file) {
	return preg_replace("/\.xm[dl]$/", "", $file);
}

/**
 * convert a dataset-name, i.e. DAMOC/my-d&!ataset to a filename as done in harvester.pl/makesane
 * @param $datasetName name as returned by MM_dataset->getInfo()[name]
 * @return filename relative to WEBRUN/XML directory
 */
function mmDatasetName2FileName($datasetName) {
	$specials = array( ';','?',':','@','&','=','+','$',',','-','!','~','*','(',')','%'); #without / since this is used in dataset
	foreach ( $specials as $special ) {
		$convert[$special] = sprintf("-%02x", ord($special));
	}
	$filename = "";
	foreach (str_split($datasetName) as $char) {
		$filename .= array_key_exists($char, $convert) ? $convert[$char] : $char;
	}
	return $filename;
}

/**
 * get a dataset-header initialized with
 * actual datestamp and creationDate and
 * metadataFormat = ""
 * @return string with dataset content
 */
function mmGetDefaultDatasetHeader() {
	$sDate = gmstrftime("%Y-%m-%dT%H:%M:%SZ",mmTtime::ttime());
	return
'<?xml version="1.0" encoding="UTF-8" ?>
<dataset
   xmlns="http://www.met.no/schema/metamod/dataset"
   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
   xsi:schemaLocation="http://www.met.no/schema/metamod/dataset https://wiki.met.no/_media/metamod/dataset.xsd">
  <info name="" status="active" creationDate="'.$sDate.'" datestamp="'.$sDate.'" ownertag="" metadataFormat="Other"/>
</dataset>';
	
}

/**
 * load the content of xm[ld] files into a string, respect locking
 * @param $fileXMD filename of .xml or .xmd file
 * @param $fileXML optional filename when not using the xml/xmd combination 
 * @return [$xmdString, $xmlString]
 */
function mmGetDatasetFileContent($fileXMD, $fileXML = "") {
	if ($fileXML == "") {
		$basefile = mmGetBasename($fileXMD);
		$fileXML = "$basefile.xml";
		$fileXMD = "$basefile.xmd";
	}
	$dataXMD = "";
	$dataXML = "";
	// file_get_contents does not support LOCK_SH, open and read manually
	$xmdfh = @fopen($fileXMD, "rb");
	if ($xmdfh) {
		flock($xmdfh, LOCK_SH);
	}
	$xmlfh = @fopen($fileXML, "rb");
	if ($xmlfh) {
		flock($xmlfh, LOCK_SH);
		$dataXML = fread($xmlfh, filesize($fileXML));
	}
	if ($xmdfh) {
		$dataXMD = fread($xmdfh, filesize($fileXMD));
	}
	if ($xmlfh) {
		fclose($xmlfh); // close and unlock mm2
	}
	if ($xmdfh) {
		fclose($xmdfh); // fclose and unlock ds
	}

	return array($dataXMD, $dataXML);
}

/**
 * write the dataset (with flock-locking) to the output Basename.
 * The $xmlContent will be written $outputBasename.xml
 * The $xmdContent will be written to $outputBasename.xmd
 * 
 * @param $outputBasename Path to the output-files without appendix .xml or .xmd
 * @param $xmdConent string content for xmdFile
 * @param $xmlContent string content for xmlFile
 * @throws MM_DatasetException if file or lock has problems 
 * 
*/

function mmWriteDataset($outputBasename, $xmdContent, $xmlContent) {
		$dsfh = fopen($outputBasename . ".xmd", "ab");
		if (!$dsfh) {
			throw new MM_DatasetException("cannot write dataset-file '$outputBasename.xmd'");
		}
		if (!flock($dsfh, LOCK_EX)) {
			throw new MM_DatasetException("cannot lock dataset-file '$outputBasename.xmd'");
		}
		$mm2fh = fopen($outputBasename . ".xml", "ab");
		if (!$mm2fh) {
			throw new MM_DatasetException("cannot write metadata-file '$outputBasename.xml'");
		}
		if (!flock($mm2fh, LOCK_EX)) {
			flock($dsfh, LOCK_UN);
			throw new MM_DatasetException("cannot lock metadata-file '$outputBasename.xml'");			
		}
		if (!ftruncate($dsfh, 0)) {
			throw new MM_DatasetException("cannot truncate dataset-file '$outputBasename.xmd'");
		}
		if (!ftruncate($mm2fh, 0)) {
			throw new MM_DatasetException("cannot truncate metadata-file '$outputBasename.xml'");
		}
		fseek($dsfh, 0);
		fseek($mm2fh, 0);

		fwrite($dsfh, $xmdContent);
		fwrite($mm2fh, $xmlContent);

		// fclose include unlock
		fclose($mm2fh);
		fclose($dsfh);
	}


class MM_ForeignDataset {
	protected $domDS;
	protected $domOther;
	protected $xpathDS;
	protected $namespaceDS = "http://www.met.no/schema/metamod/dataset";
	const DATASET_SCHEMA = "[==TARGET_DIRECTORY==]/schema/dataset.xsd"; 
	/**
	 * construct a ForeignDataset (Dataset and XML-file)
	 * 
	 * @param $inputDS The input can be "", then a new dataset will be created (default);
	 *                 input can be a DOMNode, then that node will be the source for the dataset
	 *                 if (input_is_data), input is assumed to be an xml-string
	 *                 otherwise, input is assumed to be a filename
	 * @param $inputOther corresponding metadata, should be given in the same way, but cannot be ""
	 * @param $input_is_data set true if input is a xml-string rather than a filename
	 * @throw MM_Dataset2Exception
	 */
	function __construct($inputDS="", $inputOther, $input_is_data = false) {
		$dataDS = mmGetDefaultDatasetHeader();
		if (strlen($inputOther) == 0) {
			throw MM_DatasetException("cannot construct a foreign dataset without foreign data");
		}
		if (!$inputDS) {
			if (is_object($inputOther) && ($inputOther instanceof DOMNode)) {
				$dataOther = DOMDocument::saveXML($inputOther);
			} elseif ($input_is_data) {
				$dataOther = $inputOther;
			} else {
				list($noInterst, $dataOther) = mmGetDatasetFileContent($inputDS, $inputOther);
			}
		} elseif (is_object($inputDS) && ($inputDS instanceof DOMNode)) {
			$dataDS = DOMDocument::saveXML($inputDS);
			if (is_object($inputOther) && ($inputOther instanceof DOMNode)) {
				$dataOther = DOMDocument::saveXML($inputOther);
			} else {
				throw new MM_DatasetException("inputDS is DOMNode, but inputOther is not");
			}
		} elseif ($input_is_data) {
			$dataDS = $inputDS;
			$dataOther = $inputOther;
		} else {
			list($dataDS, $dataOther) = mmGetDatasetFileContent($inputDS, $inputOther);
			if (strlen($dataDS) == 0) {
				throw new MM_DatasetException("cannot read dataset-file '$inputDS'");
			}
			if (strlen($dataOther) == 0) {
				throw new MM_DatasetException("cannot read metadata-file '$inputOther'");
			}
		}
		$this->domDS = new DOMDocument();
		if (!$this->domDS->loadXML($dataDS)) {
			mm_log(MM_ERROR, "unable to parse xml-string wit '$dataDS'", __FILE__, __LINE__);
			throw new MM_DatasetException("unable to construct dataset with '$dataDS'");
		}
		$this->domOther = new DOMDocument();		
		if (!$this->domOther->loadXML($dataOther)) {
			mm_log(MM_ERROR, "unable to parse xml-string wit '$dataOther'", __FILE__, __LINE__);
			throw new MM_DatasetException("unable to construct metadata with '$dataOther'");
		}
		$this->xpathDS = new DomXPath($this->domDS);
		$this->xpathDS->registerNamespace('d', $this->namespaceDS);
		if ($this->xpathDS->query('/d:dataset/d:info')->length != 1) {
			throw new MM_DatasetException("failed to open xml: not a dataset document");
		}
	}
	/**
	 * read the info of the dataset
	 * @return array with info attribute - value pairs
	 */
	function getInfo() {
		$retVal = array();
		$info = $this->xpathDS->query('/d:dataset/d:info')->item(0);
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
		$dinfo = $this->xpathDS->query("/d:dataset/d:info")->item(0);
		foreach ($info as $name => $val) {
			$dinfo->setAttribute($name, $val);
		}
	}
	/**
	 * Retrieve the quadtree-nodes as list.
	 * 
	 * @return array(1,11, ...)
	 */
	function getQuadtree() {
		$retVal = array();
		$nodelist = $this->xpathDS->query("/d:dataset/d:quadtree_nodes");
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
			foreach ($this->xpathDS->query("/d:dataset/d:quadtree_nodes") as $node) {
				$node->parentNode->removeChild($node);
			}
		}
		$ds = $this->xpathDS->query("/d:dataset")->item(0);
		if (count($quadtreeNodes)) {
			$nodeStr = "";
			foreach ($quadtreeNodes as $quadNode) {
				$nodeStr .= "$quadNode\n";
			}
			$quadtreeNode = $this->domDS->createElementNS($this->namespaceDS,'quadtree_nodes');
			$quadtreeNode->appendChild($this->domDS->createTextNode($nodeStr));

			$nodelist = $this->xpathDS->query("/d:dataset/*");
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
	 * get a xml string of this dataset
	 * @return xml
	 */
	function getDS_XML() {
		return $this->domDS->saveXML();
	}

	/**
	 * get a xml string of this metadata
	 * @return xml
	 */
	function getOther_XML() {
		return $this->domOther->saveXML();
	}

	/**
	 * write the dataset (with flock-locking) to the output Basename.
	 * The MM2 metadata will be written to $outputBasename.xml
	 * The dataset will be written to $outputBasename.xmd
	 * 
	 * @param $outputBasename Path to the output-files without appendix .xml or .xmd
	 * @throws MM_DatasetException if file or lock has problems 
	 * 
	 */
	function write($outputBasename) {
		mmWriteDataset($outputBasename, $this->getDS_XML(), $this->getOther_XML());
	}
	/**
	 * validate the dataset (not the other)
	 * @return true on success
	 */
	function validate() {
		return $this->domDS->schemaValidate(self::DATASET_SCHEMA);
	}
}

class MM_Dataset extends MM_ForeignDataset {
	protected $xpathMM2;
	protected $namespaceMM2 = "http://www.met.no/schema/metamod/MM2";
	const MM2_SCHEMA = "[==TARGET_DIRECTORY==]/schema/MM2.xsd"; 
	
	
	/**
	 * construct a MM_Dataset2
	 * 
	 * @param $inputDS The input can be "", then a new dataset will be created (default);
	 *                 input can be a DOMNode, then that node will be the source for the dataset
	 *                 if (input_is_data), input is assumed to be an xml-string
	 *                 otherwise, input is assumed to be a filename
	 * @param $inputMM corresponding metadata, should be given in the same way
	 * @param $input_is_data set true if input is a xml-string rather than a filename
	 * @throw MM_Dataset2Exception
	 */
	function __construct($inputDS = "", $inputMM2 = "", $input_is_data = false) {
			$dataDS = mmGetDefaultDatasetHeader();
			$dataMM2 =
'<?xml version="1.0" encoding="UTF-8"?>
<MM2
   xmlns="http://www.met.no/schema/metamod/MM2"
   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
   xsi:schemaLocation="http://www.met.no/schema/metamod/MM2 https://wiki.met.no/_media/metamod/mm2.xsd">
</MM2>';
		if (!$inputDS) {
			// use defaults
		} elseif (is_object($inputDS) && ($inputDS instanceof DOMNode)) {
			$dataDS = DOMDocument::saveXML($inputDS);
			if (is_object($inputMM2) && ($inputMM2 instanceof DOMNode)) {
				$dataMM2 = DOMDocument::saveXML($inputMM2);
			} else {
				throw new MM_DatasetException("inputDS is DOMNode, but inputMM2 is not");
			}
		} elseif ($input_is_data) {
			$dataDS = $inputDS;
			$dataMM2 = $inputMM2;
		} else {
			list($dataDS, $dataMM2) = mmGetDatasetFileContent($inputDS, $inputMM2);
			if (strlen($dataDS) == 0) {
				throw new MM_DatasetException("cannot read dataset-file '$inputDS'");
			}
			if (strlen($dataMM2) == 0) {
				throw new MM_DatasetException("cannot read metadata-file '$inputMM2'");
			}
		}
		$this->domDS = new DOMDocument();
		if (!$this->domDS->loadXML($dataDS)) {
			mm_log(MM_ERROR, "unable to parse xml-string wit '$dataDS'", __FILE__, __LINE__);
			throw new MM_DatasetException("unable to construct dataset with '$dataDS'");
		}
		$this->domOther = new DOMDocument();		
		if (!$this->domOther->loadXML($dataMM2)) {
			mm_log(MM_ERROR, "unable to parse xml-string wit '$dataMM2'", __FILE__, __LINE__);
			throw new MM_DatasetException("unable to construct metadata with '$dataMM2'");
		}
		$this->xpathDS = new DomXPath($this->domDS);
		$this->xpathDS->registerNamespace('d', $this->namespaceDS);
		if ($this->xpathDS->query('/d:dataset/d:info')->length != 1) {
			throw new MM_DatasetException("failed to open xml: not a dataset document");
		}
		$this->xpathMM2 = new DomXPath($this->domOther);
		$this->xpathMM2->registerNamespace('m', $this->namespaceMM2);
		if ($this->xpathMM2->query('/m:MM2')->length != 1) {
			throw new MM_DatasetException("failed to open xml: not a metadata document");
		}
		$this->addInfo(array("metadataFormat" => "MM2"));
	}


	/**
	 * read the metadata from the dataset
	 * @return array with metadata_name -> [value] pairs. 
	 *         value is an array of values, one per element
	 * 
	 */
	function getMetadata() {
		$retVal = array();
		foreach ($this->xpathMM2->query('/m:MM2/m:metadata') as $mdata) {
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
		$node = $this->xpathMM2->query('/m:MM2')->item(0);
		foreach ($metadata as $name => $values) {
			foreach ($values as $value) {
				$el = $this->domOther->createElementNS($this->namespaceMM2,'metadata');
				$el->setAttribute("name", $name);
				$txt = $this->domOther->createTextNode($value);
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
			foreach ($this->xpathMM2->query("/m:MM2/m:metadata[@name='$name']") as $node) {
				$node->parentNode->removeChild($node);
			}
		}
	}
	
	/**
	 * get a xml string of this metadata
	 * @return xml
	 * @deprecated @see getOther_XML
	 */
	function getMM2_XML() {
		return $this->getOther_XML();
	}
	
	/**
	 * validate the dataset and the mm2
	 * @return true on success
	 */
	function validate() {
		return $this->domDS->schemaValidate(parent::DATASET_SCHEMA) &&
			$this->domOther->schemaValidate(self::MM2_SCHEMA);
		
	}
	
}

class MM_DatasetException extends Exception {
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
    	throw new MM_DatasetException($exception);
  	}
}
?>
