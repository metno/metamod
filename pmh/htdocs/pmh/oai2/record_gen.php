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

$output .= metadataHeader($prefix);

$b1 = new buildxml(6,1);
$prev_mtname = '';
$keycount = count($key_conversion);
for ($i1=0; $i1 <= $keycount; $i1 += 3) {
   if ($i1 < $keycount) {
      $mtstring = $key_conversion[$i1];
      $xmlpath = $key_conversion[$i1+1];
      $constval = $key_conversion[$i1+2];
   } else {
      list($mtstring,$xmlpath,$constval) = array('LAST'.$prev_mtname,'','');
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
         foreach ($valueset as $value) {
            $outlist = array();
            foreach ($prev_keys as $keyrecord) {
               list($exception,$path,$const) = $keyrecord;
               if ($const != '') {
                  $outlist[] = array($path,htmlspecialchars($const));
               } else if ($exception != 0) {
                  $val = get_exception($prev_mtname,$exception,$value);
                  if ($val !== FALSE) {
                     $outlist[] = array($path,$val);
                  } else {
				     // simply skip this entry, go to the next
                  }
               } else {
                  $outlist[] = array($path,htmlspecialchars($value));
               }
            }
            reset($outlist);
            foreach ($outlist as $tupple) {
               $b1->add($tupple[0],xmlstr($tupple[1]));
            }
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
   $prev_keys[] = array($exception,$xmlpath,$constval);
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
$output .= 
'   </metadata>'."\n";
?>
