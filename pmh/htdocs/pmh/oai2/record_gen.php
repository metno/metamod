<?
/*
* +----------------------------------------------------------------------+
* | PHP Version 4                                                        |
* +----------------------------------------------------------------------+
* | Copyright (c) 2002-2005 Heinrich Stamerjohanns                       |
* |                                                                      |
* | dc_record.php -- Utilities for the OAI Data Provider                 |
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
* /            stamer@uni-oldenburg.de                                   |
* |                                                                      |
* | Adapted to METAMOD2 by Egil Støren, August 2008                      |
* |            egil.storen@met.no                                        |
* +----------------------------------------------------------------------+
*/
//
//

// please change to the according metadata prefix you use
// $prefix = 'oai_dc';

// you do need to change anything in the namespace and schema stuff
// the correct headers should be created automatically

$prefix = $metadataPrefix;
if (($metadataPrefix == 'iso19115') ||
    ($metadataPrefix == 'iso19139')) {
   $prefix = 'dif'; # iso19115 read as dif and converted afterwards
}
$output .=
'   <metadata>'."\n";

$gotFile = 0;
if ((($metadataPrefix == 'dif') && ($record[$SQL['metadataFormat']] == 'DIF')) ||
    (($metadataPrefix == 'iso19115') && ($record[$SQL['metdataFormat']]) == 'ISO19115') ||
    (($metadataPrefix == 'iso19139') && ($record[$SQL['metdataFormat']]) == 'ISO19115')) {
	# read original record from file, don't create from database
	# $output .= $mmConfig->getVar("WEBRUN_DIRECTORY").'/XML/'.mmDatasetName2FileName($record[$SQL['identifier']]);
	$filename = $mmConfig->getVar("WEBRUN_DIRECTORY").'/XML/'.mmDatasetName2FileName($record[$SQL['identifier']]);
	list($xmdContent, $xmlContent) = mmGetDatasetFileContent($filename);
	if (strlen($xmlContent)) {
		try {
			$ds = new MM_ForeignDataset($xmdContent, $xmlContent, 1);
			$xml =  $ds->getOther_XML();
			$xml = substr($xml, strpos($xml, "\n")); # remove first line, <?xml
			$output .= $xml;
			$gotFile = 1;
		} catch (MM_DatasetException $mde) {
			mm_log(MM_WARNING,"unparsable xml in $filename",__FILE__, __LINE__);
		}
	}
}

if (!$gotFile) {

	$outRecord = metadataHeader($prefix);

	$b1 = new buildxml(6,1);
	$prev_mtname = '';
	$keycount = count($key_conversion);
    $last_mainelement = ""; # This variable is used to remember the first element in $xmlpath.
                            # If the new $xmlpath has the same first element, and both $xmlpath
                            # (old and new) have an initial '*', this initial '*' is removed
                            # from the new $xmlpath. This is done to allow optional items
                            # to trig the production of a complex XML element. The first item
                            # encountered will trig this production (by keeping the '*'), while
                            # subsequent items will be included in the complex XML element
                            # (and not start a new complex element - since the '*' is removed).
	for ($i1=0; $i1 <= $keycount; $i1 += 4) {
   	    if ($i1 < $keycount) {
          	$mtstring = $key_conversion[$i1];
      	    $xmlpath = $key_conversion[$i1+1];
	        $constval = $key_conversion[$i1+2];
   	        $defaultval = $key_conversion[$i1+3];
   	    } else {
      	    list($mtstring,$xmlpath,$constval,$defaultval) = array('LAST'.$prev_mtname,'','','');
   	    }
   	    $mtparts = array();
	    $mtname = '';
   	    if ($mtstring != '') {
	        $mtparts = explode(" ",$mtstring);
   	        $mtname = $mtparts[0];
      	    if (substr($mtname,0,1) == '!') {
	            $mtname = substr($mtname,1);
   	        }
   	    }
   	    if ($mtname != $prev_mtname && $prev_mtname != '') {
      	    if (array_key_exists($prev_mtname, $record)) {
         	    if (is_array($record[$prev_mtname])) {
                    $valueset = $record[$prev_mtname];
	            } else {
   	                $valueset = array($record[$prev_mtname]);
      	        }
	        } else {
   	            $valueset = array("USE_DEFAULT");
      	    }
            $found_patterns = array(); # Used to avoid multiple XML elements with same content
                                       # due to invalid data.
            $default_outlist = array();
            $normal_value_count = 0; # Counts the number of values originating from real data
                                     # i.e. not default or constants. Used to avoid output of
                                     # default values when real data exists.
	        foreach ($valueset as $value) {
   	            $outlist = array();
                $count_of_defaultvalues = 0; # Some XML elements are mandatory. If no items are found
                                  # with real data, exactly one element should be output using
                                  # the default value.
      	        foreach ($prev_keys as $keyrecord) {
         	        list($excpt,$path,$const,$dfltval) = $keyrecord;
            	    if ($const != '') {
               	        $outlist[] = array($path,htmlspecialchars($const));
                        $count_of_defaultvalues++;
	                } else if ($value == "USE_DEFAULT") {
   	                    if ($dfltval != '') {
      	                    $outlist[] = array($path,$dfltval);
         	            }
                        $count_of_defaultvalues++;
            	    } else if ($excpt != 0) {
               	        $val = get_exception($prev_mtname,$excpt,$value);
	                    if ($val !== FALSE) {
                            if ($excpt == 99) {
                                $outlist[] = array($path,htmlspecialchars($const));
                                $count_of_defaultvalues++;
                            } else {
   	                            $outlist[] = array($path,$val);
                            }
      	                } else {
         	                if ($dfltval != '')  { # && $count_of_values == 0
            	                $outlist[] = array($path,$dfltval);
               	            }
                            $count_of_defaultvalues++;
	                    }
   	                } else {
      	                $outlist[] = array($path,htmlspecialchars($value));
         	        }
	            }
                $new_pattern = "";
                if ($count_of_defaultvalues == count($prev_keys)) {
                   $new_pattern .= "ONLY_DEFAULT:";
                }
   	            reset($outlist);
      	        foreach ($outlist as $tupple) {
                   $new_pattern .= $tupple[0] . $tupple[1];
                }
                if (! in_array($new_pattern, $found_patterns)) {
                   $found_patterns[] = $new_pattern;
                   if (substr($new_pattern,0,13) == "ONLY_DEFAULT:") {
                      $default_outlist = $outlist;
                   } else {
   	                  reset($outlist);
      	              foreach ($outlist as $tupple) {
                          $path_parts = explode(" ",$tupple[0]);
                          if ($path_parts[0] == $last_mainelement && substr($last_mainelement,0,1) == "*") {
                              $newxmlpath = substr($tupple[0],1); # Remove initial '*'
                          } else {
                              $newxmlpath = $tupple[0];
                          }
                          $b1->add($newxmlpath,xmlstr($tupple[1], $metadataCharset));
                          $last_mainelement = $path_parts[0];
	                  }
                      $normal_value_count++;
                   }
                }
   	        }
            if (count($default_outlist) > 0 && $normal_value_count == 0) {
                reset($default_outlist);
                foreach ($default_outlist as $tupple) {
                    $path_parts = explode(" ",$tupple[0]);
                    if ($path_parts[0] == $last_mainelement && substr($last_mainelement,0,1) == "*") {
                        $newxmlpath = substr($tupple[0],1); # Remove initial '*'
                    } else {
                        $newxmlpath = $tupple[0];
                    }
                    $b1->add($newxmlpath,xmlstr($tupple[1], $metadataCharset));
                    $last_mainelement = $path_parts[0];
                }
            }
   	    }
	    if ($mtname == '') {
   	        $b1->add($xmlpath,xmlstr($constval));
   	    }
	    if ($mtname != $prev_mtname) {
   	        $prev_keys = array();
	    }
   	    $exception = 0;
	    if (count($mtparts) > 1) {
   	        $exception = $mtparts[1];
	    }
   	    $prev_keys[] = array($exception,$xmlpath,$constval,$defaultval);
	    $prev_mtname = $mtname;
	}
	$outRecord .= $b1->get();

	// Here, no changes need to be done
	$outRecord .=
	'     </'.$METADATAFORMATS[$prefix]['metadataPrefix'];
	if (isset($METADATAFORMATS[$prefix]['record_prefix'])) {
		$outRecord .= ':'.$METADATAFORMATS[$prefix]['record_prefix'];
	}
	$outRecord .= ">\n";
	if (($metadataPrefix == 'iso19115') ||
	    ($metadataPrefix == 'iso19139')) {
      # translate from dif to iso19115
	   # convert dif record to DOM
      $xmlDoc = new DOMDocument();
      $xmlDoc->loadXML($outRecord );

      # load stylesheet
      $xslDoc = new DOMDocument();
      $xslDoc->load($METADATAFORMATS[$metadataPrefix]['dif2isoXslt']);
      $xslt = new XSLTProcessor();
      $xslt->importStylesheet( $xslDoc );
      $xslt->setParameter('', 'REPOSITORY_IDENTIFIER', $repositoryIdentifier);
      $oldGranularity = $granularity;
      $granularity = 'YYYY-MM-DDThh:mm:ssZ'; #global $granularity needed by formatDatestamp
      $xslt->setParameter('', 'DATASET_TIMESTAMP', formatDatestamp($record['OAI_datestamp']));
      $granularity = $oldGranularity;
      # return to string
      $xml = $xslt->transformToXML( $xmlDoc );
      # remove xml declaration and return to outRecord
      $outRecord = substr($xml, strpos($xml, "\n")); # remove first line, <?xml
   }
}

$output .= $outRecord .'   </metadata>'."\n";
?>
