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
$output .= 
'   <metadata>'."\n";

$gotFile = 0;
if (($metadataPrefix == 'dif') && ($record[$SQL['metadataFormat']] == 'DIF')) {
	# read original record from file, don't create from database
	# $output .= $mmConfig->getVar("WEBRUN_DIRECTORY").'/XML/'.mmDatasetName2FileName($record[$SQL['identifier']]);
	$filename = $mmConfig->getVar("WEBRUN_DIRECTORY").'/XML/'.mmDatasetName2FileName($record[$SQL['identifier']]);
	list($xmdContent, $xmlContent) = mmGetDatasetFileContent($filename);
	if (strlen($xmlContent)) {
		try {
			$ds = new MM_ForeignDataset($xmdContent, $xmlContent, 1);
			$xml =  $ds->getOther_XML();
			$xmlArray = explode("\n", $xml);
			$xmlArray = array_slice($xmlArray, 1); # remove first line, <?xml 
			$output .= implode("\n", $xmlArray);
			$gotFile = 1;
		} catch (MM_DatasetException $mde) {
			mm_log(MM_WARNING,"unparsable xml in $filename",__FILE__, __LINE__);
		}
	}
}

if (!$gotFile) {

	$output .= metadataHeader($prefix);

	$b1 = new buildxml(6,1);
	$prev_mtname = '';
	$keycount = count($key_conversion);
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
	      foreach ($valueset as $value) {
   	      $outlist = array();
      	   foreach ($prev_keys as $keyrecord) {
         	   list($excpt,$path,$const,$dfltval) = $keyrecord;
            	if ($const != '') {
               	$outlist[] = array($path,htmlspecialchars($const));
	            } else if ($value == "USE_DEFAULT") {
   	            if ($dfltval != '') {
      	            $outlist[] = array($path,$dfltval);
         	      }
            	} else if ($excpt != 0) {
               	$val = get_exception($prev_mtname,$excpt,$value);
	               if ($val !== FALSE) {
                  if ($excpt == 4) {
                     $outlist[] = array($path,htmlspecialchars($const));
                  } else {
   	               $outlist[] = array($path,$val);
                  }
      	         } else {
         	         if ($dfltval != '') {
            	         $outlist[] = array($path,$dfltval);
               	   }
	               }
   	         } else {
      	         $outlist[] = array($path,htmlspecialchars($value));
         	   }
	         }
   	      reset($outlist);
      	   foreach ($outlist as $tupple) {
         	   $b1->add($tupple[0],xmlstr($tupple[1], $metadataCharset));
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
	$output .= $b1->get();

	// Here, no changes need to be done
	$output .=           
	'     </'.$METADATAFORMATS[$prefix]['metadataPrefix'];
	if (isset($METADATAFORMATS[$prefix]['record_prefix'])) {
		$output .= ':'.$METADATAFORMATS[$prefix]['record_prefix'];
	}
	$output .= ">\n";
}

$output .= 
'   </metadata>'."\n";
?>
