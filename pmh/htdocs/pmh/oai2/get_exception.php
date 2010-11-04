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
   global $topics;
   global $inverse_topics;
   global $areas;
   global $topicCategories;
   global $projectNames;
   if ($mtname == 'variable') {
   	  $detail = $value;
      if (array_key_exists($value, $topics)) {
         $parts = explode(" > ",$topics[$value][0]);
         if ($parts[0] == "Hydrosphere" && array_key_exists(1,$topics[$value])) {
#
#           Try to avoid "Hysrosphere" which is deprecated.
#
            $parts = explode(" > ",$topics[$value][1]);
         }
         if ($exception < 0) {
      	    return $detail;
         } elseif ($exception == 4) {
            return $value; # Hack. Return some non-false value. The actual value to be used is a constant
                           # not accessible from this function. Egils
         } elseif ($exception <= count($parts)) {
            return $parts[$exception - 1];
         }
      } else { // gcmd-string keywords, splitted by >, appended '> HIDDEN' at the end
      	$parts = preg_split('/\s*>\s*/', $value, -1, PREG_SPLIT_NO_EMPTY);
      	$last = array_pop($parts);
      	if ($last != 'HIDDEN') {
      		array_push($parts, $last);
      	}
        $detail = implode(" > ",$parts);
        if (array_key_exists($detail, $inverse_topics)) {
           if ($exception < 0) {
      	      return FALSE; # detail not required if full gcmd-keywords
           } elseif ($exception == 4) {
              return $value; # Hack. See above
           } elseif ($exception <= count($parts)) {
      	      $val = $parts[$exception - 1];
      	      if ($val == "Spectral Engineering") {
      	         $val = "Spectral/Engineering"; # fix bug in Metamod-data
      	      }
              return $val;
           }
        }
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
   elseif ($mtname == "project_name") {
   	  if (array_key_exists($value, $projectNames)) {
   		 return $projectNames[$value];
   	  } else {
   		 return $value;
   	  }
   }
   elseif ($mtname == "gtsInstancePattern") {
   	  return
            "<URL_Content_Type>\n".
   	      "  <Type>GTSInstancePattern</Type>\n".
            "</URL_Content_Type>\n".
				"<URL>$value</URL>\n".
            "<Description>Instance pattern connecting to Global Telecommunication System (GTS)</Description>\n";
   }
   elseif ($mtname == "gtsFileIdentifier") {
   	  return
            "<URL_Content_Type>\n".
   	      "  <Type>GTSFileIdentifier</Type>\n".
            "</URL_Content_Type>\n".
				"<URL>$value</URL>\n".
            "<Description>File-Identifier connecting to Global Telecommunication System (GTS)</Description>\n";
   }
   return FALSE;
}
?>
