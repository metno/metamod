<?php 
#---------------------------------------------------------------------------- 
#  METAMOD - Web portal for metadata search and upload 
# 
#  Copyright (C) 2008 met.no 
# 
#  Contact information: 
#  Norwegian Meteorological Institute 
#  Box 43 Blindern 
#  0313 OSLO 
#  NORWAY 
#  email: egil.storen@met.no 
#   
#  This file is part of METAMOD 
# 
#  METAMOD is free software; you can redistribute it and/or modify 
#  it under the terms of the GNU General Public License as published by 
#  the Free Software Foundation; either version 2 of the License, or 
#  (at your option) any later version. 
# 
#  METAMOD is distributed in the hope that it will be useful, 
#  but WITHOUT ANY WARRANTY; without even the implied warranty of 
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the 
#  GNU General Public License for more details. 
#   
#  You should have received a copy of the GNU General Public License 
#  along with METAMOD; if not, write to the Free Software 
#  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA 
#---------------------------------------------------------------------------- 
?>
<?php
class SessionState {
   var $logintime;          // Text string of the form: "YYYY-MM-DD HH:MM:SS"

   var $sitems;             // Array using indices of the form: "category,detail"
                            // where category is a key in the SearchCategory table,
                            // and detail is dependent on the category type.

   var $state;              // Text string describing the current application
                            // state, i.e. which screen is currently shown to
                            // the user. 

   var $options;            // Array containing options set in the options
                            // dialogue.

   var $QueryResultOffset;  // When showing a large table of rows, it will be
                            // splitted up into smaller tables. This variable
			    			// represents the row number offset in the large
			    			// table corresponding to the current smaller table
   /**
    * count occurences of $category in $sitems
    * @param $category "category,detail" with category as key in SearchCategory table
    * @return count of $sitem[$category], or 0 if unset
    */		    			
   function countItems ( $category ) {
   		if ( isset($this->sitems) && 
   		     is_array($this->sitems[$category]) ) {
   			return count($this->sitems[$category]);	
   		} else {
   			return 0;
   		}
   }
			   
}

function mmEndSession() {
   global $mmSessionId, $mmDbConnection;
   if (isset($mmSessionId) && $mmDbConnection) {
      $sqlsentence = "DELETE FROM Sessions WHERE sessionid = '$mmSessionId'";
      $result = pg_exec ($mmDbConnection, $sqlsentence);
   }
}

function mmAnchor($URL,$Text,$type) {
//
// Unless the current page is a form, this routine returns an anchor
// tag with embedded text: 
//  <a class="..." href="$URL?mmSessionId=$mmSessionId">$Text</a> 
// The class is dependent on type. If $type = "main" the mm_item and 
// xmm_item classes are used. Otherwise, the m_item and xm_item 
// classes are used.
// This function must be used to implement all links to local pages.
// 
// If the current page is a form, a similar p-tag is returned.
//
    global $mmSessionId;
    if ($type == "main") {
       $class = "mm_item";
    } else if ($type == "oper") {
       $class = "om_item";
    } else {
       $class = "m_item";
    }
    if (mmCurrentPageIsForm() == 1) {
       if ($class == "om_item") {
          return $Text;
       } else {
          return '<p class="' . $class . '">' . $Text. '</p>';
       }
    } else {
       if (!isset($mmSessionId) || $mmSessionId == "" ) {
           // No Session ID to pass on
       } else {
           // In Session - append the mmSessionId 
           if ( strstr( $URL, "?" ) ) {
               // URL already contain arguments - append to end
               $URL .= "&";
           } else {
               // URL has no arguments - start new argument list
               $URL .= "?";
           }
           $URL .= "mmSessionId=$mmSessionId";
       }
       if ($class == "om_item") {
          return '<a href="' .$URL. '">' . $Text. '</a>';
       } else {
          return '<a class="' . $class . '" href="' .$URL. '">' . $Text. '</a>';
       }
    }
}

function mmHiddenSessionField() {
//
// This function returns a hidden field which can be incorporated into forms: 
//  <INPUT type="hidden" name="mmSessionId" value="$mmSessionId" />
//
    global $mmSessionId;
    if ( $mmSessionId == "" ) {
        // No Session ID to pass on
        return '<!-- Error in mmHiddenSessionField() : mmSessionId missing -->';
    }
    else {
        return '<input type="hidden" name="mmSessionId" value="' .$mmSessionId. '" />';
    }
}

function mmShowErrorMessage($string) {
   echo '<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">' . "\n" .
      '<html><head><title>Error</title>' . "\n" .
      '</head><body><center>' . "\n" .
      '<table border=1 cellpadding=20><tr><td align=center>' . "\n" .
      $string . "\n" .
      '</td></tr></table>' . "\n" .
      '</center></body></html>' . "\n";
}

function mmGetRunPath () {
   return '[==WEBRUN_DIRECTORY==]';
}

function mmPutLog($string) {
   $logfile = mmGetRunPath() . '/userlog';
   $fd = fopen($logfile,"a");
   fwrite($fd,date("Y-m-d H.i: ") . $string . "\n");
   fflush($fd);
   fclose($fd);
}

function mmInitCategories() {
//
// This routine reads the SearchCategory table from the database, and initialize the
// following global variables:
//
// $mmCategorytype[category]        The SC_type field for the category.
//                                The 'category' argument can be a number or a name
//                                (the value in a "name: value" string in the SC_fnc
//                                field).
// $mmCategoryFnc[$category . $name]   Value corresponding to name extracted from the
//                                SC_fnc field for the category.
//
    global $mmDbConnection, $mmCategorytype, $mmCategoryName, $mmCategoryFnc;
    $sqlsentence = "SELECT * FROM SearchCategory";
    $result = pg_exec ($mmDbConnection, $sqlsentence);
    if (!$result) {
       mmPutLog("E33 Could not $sqlsentence");
       return "Database error";
    } else {
       $num = pg_numrows($result);
       for ($i1=0; $i1 < $num;$i1++) {
          $rowarr = pg_fetch_row($result,$i1);
          $mmCategorytype[$rowarr[0]] = $rowarr[1];
          $a1 = explode(";",$rowarr[2]);
          foreach ($a1 as $s1) {
#
#               Extract subexpressions in RE:
#
             if (preg_match ('/^\s*(\w+)\s*:\s*(.*\S)\s*$/',$s1,$a2)) {
                $mmCategoryFnc[$rowarr[0] . $a2[1]] = $a2[2];
#                if ($a2[1] == "name") {
#                   $mmCategorytype[$a2[2]] = $rowarr[1];
#                }
             }
          }
       }
#       print_r($mmCategorytype);
    }
    return "OK";
}

function mmCurrentPageIsForm() {
    global $mmButtonName, $mmButtons;
    if (array_key_exists($mmButtonName, $mmButtons)) {
       if ($mmButtons[$mmButtonName][2] == "FORM") {
          return 1;
       } else {
          return 0;
       }
    }
}

function mmGetCategoryFncValue($category,$name) {
//
// This function returns the value of $mmCategoryFnc[$category . $name], if found.
// Othervise an empty string is returned.
//
    global $mmCategoryFnc;
    $k1 = $category . $name;
    if (array_key_exists($k1, $mmCategoryFnc)) {
       return $mmCategoryFnc[$k1];
    } else {
       return "";
    }
}

function mmUniqName ($start) {
//
// Returns a uniq name which is garanteed not to exist in other sessions
// running at the same time as this one.
//
   global $mmSessionId;
   return $start . $mmSessionId;
}

function mmIsSelectedBK($category,$id) {
   global $mmSessionState;
   return isset($mmSessionState->sitems["$category,X"][$id]);
}

function mmSelectbutton($category,$buttonvalue,$buttontext) {
   return "<input class=\"selectbutton\" type=\"submit\" name=\"mmSubmitButton_" .
          $buttonvalue . "_" . $category . "\" value=\"" . $buttontext . "\" />";
}

function mmGetBK($category) {
   global $mmErrorMessage, $mmError, $mmDbConnection;
   $retarr = array();
   if ( !$mmDbConnection ) {
      mmPutLog(__FILE__ . __LINE__ . "No database connection");
      $mmErrorMessage = "Internal application error";
      $mmError = 1;
   } else {
      $sqlsentence = "select BK_id,BK_name from BasicKey where (SC_id = $category)";
      $result = pg_exec ($mmDbConnection, $sqlsentence);
      if ( !$result ) {
         mmPutLog(__FILE__ . __LINE__ . "Could not $sqlsentence");
         $mmErrorMessage = "Internal database error";
         $mmError = 1;
      } else {
         $num = pg_numrows($result);
         for ($i1=0; $i1<$num; $i1++) {
            $rowarr = pg_fetch_row($result, $i1);
	    $bkid = $rowarr[0];
	    $retarr[$bkid] = $rowarr[1];
         }
      }
   }
   return $retarr;
}

function do_select($sqlsentence) {
   global $mmErrorMessage, $mmError, $mmDbConnection;
   $retarr = array();
   if ( !$mmDbConnection ) {
      mmPutLog(__FILE__ . __LINE__ . "No database connection");
      $mmErrorMessage = "Internal application error";
      $mmError = 1;
   } else {
      $result = pg_exec ($mmDbConnection, $sqlsentence);
      if ( !$result ) {
         mmPutLog(__FILE__ . __LINE__ . "Could not $sqlsentence");
         $mmErrorMessage = "Internal database error";
         $mmError = 1;
      } else {
         $num = pg_numrows($result);
         for ($i1=0; $i1<$num; $i1++) {
            $retarr[] = pg_fetch_row($result, $i1);
         }
      }
   }
   return $retarr;
}

function mmGetHK($category) {
   global $mmErrorMessage, $mmError, $mmDbConnection;
   $retarr = array();
   if ( !$mmDbConnection ) {
      mmPutLog(__FILE__ . __LINE__ . "No database connection");
      $mmErrorMessage = "Internal application error";
      $mmError = 1;
   } else {
      $sqlsentence = 
         "select HK_id,HK_name from HierarchicalKey where (SC_id = $category AND HK_level = 1)";
      $result = pg_exec ($mmDbConnection, $sqlsentence);
      if ( !$result ) {
         mmPutLog(__FILE__ . __LINE__ . "Could not $sqlsentence");
         $mmErrorMessage = "Internal database error";
         $mmError = 1;
      } else {
         $num = pg_numrows($result);
         for ($i1=0; $i1<$num; $i1++) {
            $rowarr = pg_fetch_row($result, $i1);
	    $hkid = $rowarr[0];
	    $retarr[$hkid] = $rowarr[1];
         }
      }
   }
   return $retarr;
}

function mmShowSelectedBK($category) {

   $name = mmGetCategoryFncValue($category,"name");
   echo mmAnchor("search.php?mmSubmitButton=bk_$category",$name,"search") . "\n";
   foreach (mmGetBK($category) as $bkid => $bktext) {
      if (mmIsSelectedBK($category,$bkid)) {
         $outstring = mmBreakLine($bktext,18,' -_');
         echo '<p class="indented">' . $outstring . '</p>' . "\n";
      }
   }
}

function mmGetSelectedNI($category,$numtype) {
   global $mmSessionState;
   $switch = 0;
   $retarr = array();
   if (isset($mmSessionState->sitems) && 
       array_key_exists("$category,NI",$mmSessionState->sitems)) {
      foreach ($mmSessionState->sitems["$category,NI"] as $num) {
         if ($switch == 0) {
            if ($numtype == 'date') {
               $from = substr($num,0,4);
               $month = substr($num,4,2);
               $day = substr($num,6,2);
               if ($month != '00') {
                  $from .= '-' . $month;
                  if ($day != '00') {
                     $from .= '-' . $day;
                  }
               }
            } else {
               $from = $num;
            }
            $switch = 1;
         } else {
            if ($numtype == 'date') {
               $to = substr($num,0,4);
               $month = substr($num,4,2);
               $day = substr($num,6,2);
               if ($month != '99') {
                  $to .= '-' . $month;
                  if ($day != '99') {
                     $to .= '-' . $day;
                  }
               }
            } else {
               $to = $num;
            }
            $retarr[] = $from . ' to ' . $to;
            $switch = 0;
         }
      }
   }
   return $retarr;
}

function mmShowSelectedNI($category) {
// Not finished

   $name = mmGetCategoryFncValue($category,"name");
   $numtype = mmGetCategoryFncValue($category,"numtype");
   echo mmAnchor("search.php?mmSubmitButton=ni_$category",$name,"search") . "\n";
   foreach (mmGetSelectedNI($category,$numtype) as $nitext) {
      echo '<p class="indented">' . $nitext . '</p>' . "\n";
   }
}

function mmShowSelectedGA($category) {
   global $mmSessionState, $mmSessionId;

   $name = mmGetCategoryFncValue($category,"name");
   echo mmAnchor("search.php?mmSubmitButton=ga_$category",$name,"search") . "\n";
   if (isset($mmSessionState->sitems) &&
            array_key_exists("$category,GA",$mmSessionState->sitems)) {
      $mmMapnum = $mmSessionState->sitems["$category,GA"][1];
      $tfname = 'maps/t' . $mmSessionId . _ . $mmMapnum . '.png';
      if (file_exists($tfname)) {
         echo '<p class="indented"> ' .
            '<img src="' . $tfname . '" width="150" height="150" /></p>' . "\n";
      }
   }
}

function mmBreakLine($string, $breaklength, $breakchars) {
   if (strlen($string) < $breaklength + 10) {
      $newstring = $string;
   } else {
#      
#        Get position in string of possible linebreak
#        $string: String
#        $breaklength: Minimum linebreak position
#        $pos: Retrieved linebreak position (starting from 0 in $string)
#      
      $pos = strcspn($string,$breakchars,$breaklength) + $breaklength;
      if ($pos < strlen($string)) {
#         
#           Return substring
#           Starting position: $start (counting from 0)
#           If $length is omitted, return the last part of the string
#         
         $rest = mmBreakLine(substr($string,$pos+1), $breaklength, $breakchars);
         $newstring = substr($string,0,$pos+1) . '<br />' . $rest;
      } else {
         $newstring = $string;
      }
   }
   return $newstring;
}

function mmShowSelectedHK($category) {
   global $mmSessionState, $mmError;

   $name = mmGetCategoryFncValue($category,"name");
   echo mmAnchor("search.php?mmSubmitButton=hkstart_$category",$name,"search") . "\n";
   $s1 = "$category,Y";
   if (isset($mmSessionState->sitems) && array_key_exists($s1, $mmSessionState->sitems)) {
      $hkids = implode(", ",array_keys($mmSessionState->sitems[$s1]));
      if (strlen($hkids) > 0) {
         $sqlsentence = 
            "select HK_name from HierarchicalKey where HK_id IN (" . $hkids . ")";
         $result = do_select($sqlsentence);
         if ($mmError == 0) {
            foreach ($result as $arr1) {
               $outstring = mmBreakLine($arr1[0],18,' -_');
               echo '<p class="indented">' . $outstring . '</p>' . "\n";
            }
         }
      }
   }
   $s1 = "$category,X";
   if (isset($mmSessionState->sitems) && array_key_exists($s1, $mmSessionState->sitems)) {
      $bkids = implode(", ",array_keys($mmSessionState->sitems[$s1]));
      if (strlen($bkids) > 0) {
         $sqlsentence = 
            "select BK_name from BasicKey where BK_id IN (" . $bkids . ")";
         $result = do_select($sqlsentence);
         if ($mmError == 0) {
            foreach ($result as $arr1) {
               $outstring = mmBreakLine($arr1[0],18,' -_');
               echo '<p class="indented">' . $outstring . '</p>' . "\n";
            }
         }
      }
   }
}

function mmCreate_mmColumns($s1) {
   global $mmColumns;
#
#  Create an empty array
#
   $mmColumns = array();
#
# foreach value in an array
#
   $i1 = 0;
   foreach (explode("\n",$s1) as $s2) {
      $s2 = trim($s2);
      if (strlen($s2) == 0) {
         continue;
      }
#      echo '===' . $s2 . '===' . "<br />\n";
      $mmColumns[$i1] = array();
#   
#     Split string using substring:
#   
      $a2 = explode(" ",$s2);
      $s4 = "";
      $j1 = 0;
#   
#    foreach value in an array
#   
      reset($a2);
      foreach ($a2 as $s3) {
#         echo '---' . $s3 . '---' . "<br />\n";
         if (substr($s3,0,1) == "'" && substr($s3,-1) == "'") {
            if ($j1 == 1) {
               $mmColumns[$i1][] = $s4;   # Next available integer key
               $mmColumns[$i1][] = substr($s3,1,-1);   # Next available integer key
               $s4 = "";
            } else {
               $mmColumns[$i1][] = substr($s3,1,-1);   # Next available integer key
            }
         } elseif (substr($s3,0,1) == "'") {
            if ($j1 == 1) {
               $mmColumns[$i1][] = $s4;   # Next available integer key
               $s4 = "";
               $j1 = 0;
            } else {
               $j1 = 1;
            }
            $s4 = substr($s3,1);
         } elseif (substr($s3,-1) == "'") {
            if ($j1 == 1) {
               $s4 .= " " . substr($s3,0,-1);
               $mmColumns[$i1][] = $s4;   # Next available integer key
               $s4 = "";
               $j1 = 0;
            } else {
               $mmColumns[$i1][] = substr($s3,0,-1);   # Next available integer key
               $j1 = 1;
               $s4 = "";
            }
         } else {
            if ($j1 == 1) {
               $s4 .= " " . $s3;
            } else {
               $mmColumns[$i1][] = $s3;   # Next available integer key
            }
         }
      }
      $i1++;
   }
}

function mmInitialiseOptions() {
   global $mmColumns;
   $retarr = array();
   reset($mmColumns);
   foreach ($mmColumns as $col) {
      foreach ($col as $value) {
         if (substr($value,0,4) == 'col=' || substr($value,0,7) == 'cross=h' ||
             substr($value,0,7) == 'cross=v') {
            $retarr[$value] = $col[0];
         }
      }
   }
   $retarr["fontsize"] = [==DEFAULT_FONTSIZE==];
   return $retarr;
}
?>
