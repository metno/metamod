<?
/*
* +----------------------------------------------------------------------+
* | PHP Version 5                                                        |
* +----------------------------------------------------------------------+
* | Copyright (c) 2008 Egil Støren, met.no                               |
* |                                                                      |
* | get_exception.php -- Utilities for the OAI Data Provider             |
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
* | Written for METAMOD2 by Egil Støren, August 2008                     |
* |            egil.storen@met.no                                        |
* +----------------------------------------------------------------------+
*/
//
//

function get_exception($mtname, $exception, $value) {
   include 'var_topic.php'; // Includes arrays $topics, $areas and $topicCategories
   if ($mtname == 'variable') {
   	  $detail = $value;
      if (array_key_exists($value, $topics)) {
         $parts = explode(" > ",$topics[$value][0]);
      } else { // gcmd-string keywords, splitted by >, appended '> HIDDEN' at the end
      	$parts = preg_split('/\s*>\s*/', $value, -1, PREG_SPLIT_NO_EMPTY);
      	$last = array_pop($parts);
      	if ($last != 'HIDDEN') {
      		array_push($parts, $last);
      	}
      	$detail = join(' > ', $parts);
#      	$detail = FALSE; <--- Seems to be left here by a mistake? Egils
      }
      if ($exception < 0) {
      	 return $detail;
      } elseif ($exception <= count($parts)) {
         return $parts[$exception - 1];
      }
   }
   elseif ($mtname == "datacollection_period") {
      $parts = explode(" to ",$value);
      if (count($parts) >= $exception) {
         return $parts[$exception - 1];
      }
   }
   elseif ($mtname == "area") {
   	  $detail = $value;
      if (array_key_exists($value, $areas)) {
         $parts = explode(" > ",$areas[$value]);
         if (in_array($value, $parts)) {
         	$detail = FALSE;
         }
      } else {
      	 $parts = preg_split('/\s*>\s*/', $value, -1, PREG_SPLIT_NO_EMPTY);
		 if (count($parts) <= 3) {
		 	$detail = FALSE;
		 } else {
		 	echo "XXXX";
		    $detail = join(' > ', array_slice($parts, 3)); # only giving parts 1-3 as exceptions
		 }
      }
      if ($exception < 0) {
      	  return $detail;
      } elseif ($exception <= count($parts)) {
          return $parts[$exception - 1];
      }
   }
   elseif ($mtname == "bounding_box") {
   	  $parts = explode(',', $value);
   	  return "<Southernmost_Latitude>".htmlspecialchars($parts[1])."</Southernmost_Latitude>" .
   	  		"<Northernmost_Latitude>".htmlspecialchars($parts[3])."</Northernmost_Latitude>" .
   	  		"<Westernmost_Longitude>".htmlspecialchars($parts[2])."</Westernmost_Longitude>" .
   	  		"<Easternmost_Longitude>".htmlspecialchars($parts[0])."</Easternmost_Longitude>";

   }
   elseif ($mtname == "latitude_resolution" || $mtname == "longitude_resolution") {
      if ($exception == 1) {
         return "$value degrees";
      }
   }
   elseif ($mtname == "DS_ownertag") {
      if ($exception == 1) {
         if ($value == "DAM") {
            return "DAMOCLES";
         }
      }
   }
   elseif ($mtname == "DS_name") {
      if ($exception == 1) {
         return str_replace('/','_',$value);
      }
   }
   elseif ($mtname == "topiccategory") {
   	if (array_key_exists($value, $topicCategories)) {
   		return $topicCategories[$value];
   	} else {
   		return $value;
   	}
   }
   return FALSE;
}
?>
