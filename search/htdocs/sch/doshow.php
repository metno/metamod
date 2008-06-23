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
$columns = array();
reset($mmSessionState->options);
$maxcol = 0;
foreach ($mmSessionState->options as $opt => $mtname) {
   if (substr($opt,0,4) == 'col=') {
      $j1 = substr($opt,4);
      if ($j1 > $maxcol) $maxcol = $j1;
      $columns[$j1] = array();
      $columns[$j1][0]= $mtname;
      $columns[$j1][1]= "";
      reset($mmColumns);
      foreach ($mmColumns as $col) {
         if ($col[0] == $mtname) {
            $columns[$j1][1]= $col[1];
         }
      }
   }
}
# echo "<pre>\ncolumns ---------\n";
# print_r($columns);
# echo "</pre>\n";
$mtnames = "";
for ($i1 = 1; $i1 <= $maxcol; $i1++) {
   if (array_key_exists($i1,$columns)) {
      $col = $columns[$i1];
      if ($col[0] != "DR") {
         if (strlen($mtnames) > 0) {
            $mtnames .= ", ";
         }
         $mtnames .= "'" . $col[0] . "'";
      }
   }
}
#
#  Compute arrays $dr_paths, $ds_arr. And comma-separated
#  string $ds_ids:
#
include 'getdslist.php';
#
if ($mmError == 0) {
   if (strlen($ds_ids) > 0) {
      if (strlen($mtnames) > 0) {
         $sqlsentence = "SELECT Metadata.MD_content, Metadata.MT_name, Dataset.DS_id \n" .
            "FROM Metadata, Dataset, DS_Has_MD \n" .
            "WHERE Dataset.DS_id in (" . $ds_ids . ") AND\n" .
            "Metadata.MT_name in (" . $mtnames . ") AND \n" .
            "Metadata.MD_id = DS_Has_MD.MD_id and Dataset.DS_id = DS_Has_MD.DS_id \n" .
            "ORDER BY Dataset.DS_id \n";
         $result = pg_query ($mmDbConnection, $sqlsentence);
         if (!$result) {
            mmPutLog(__FILE__ . __LINE__ . " Could not $sqlsentence");
            $mmErrorMessage = $msg_start . "Internal application error";
            $mmError = 1;
         }
         $use_only_ds = 0;
      } else {
         $use_only_ds = 1; # Use only arrays $ds_arr and $dr_paths computed from
                           # the first SQL sentence (giving $result1 above).
                           # Avoid accessing $result which is not set, since
                           # the second SQL-sentence was not executed.
      }
      if ($mmError == 0) {
         if ($use_only_ds == 0) {
            $num = pg_numrows($result);
         } else {
            $num = count($dr_paths);
         }
#         echo "Count: " . $num . "<br />\n";
         if ($num > 0) {
            $mdcontent = array();
            $fontsize = [==DEFAULT_FONTSIZE==];
            if (array_key_exists("fontsize",$mmSessionState->options)) {
               $fontsize = $mmSessionState->options["fontsize"];
            }
            echo '<div style="font-size: ' . $fontsize . '%">' . "\n";
            echo "<table border=\"0\" cellspacing=\"0\" cellpadding=\"3\" width=\"98%\">\n";
            $line = "<tr>";
            for ($i1 = 1; $i1 <= $maxcol; $i1++) {
               if (array_key_exists($i1,$columns)) {
                  $col = $columns[$i1];
                  $line .= "<th class=\"tdresult\" align=\"center\">" . $col[1] . "</th>";
                  $mdcontent[$col[0]] = "";
               }
            }
            $line .= "</tr>\n";
            echo $line;
            $current_ds = -1;
            for ($i1=0; $i1 <= $num;$i1++) {
               if ($i1 < $num) {
                  if ($use_only_ds == 0) {
                     $rowarr = pg_fetch_row($result,$i1);
                     $new_ds = $rowarr[2];
                  } else {
                     $new_ds = $ds_arr[$i1];
                  }
               }
               if ($i1 == $num || ($current_ds >= 0 && $new_ds != $current_ds)) {
                  $line = "<tr>";
                  for ($i2 = 1; $i2 <= $maxcol; $i2++) {
                     if (array_key_exists($i2,$columns)) {
                        $col = $columns[$i2];
                        if ($col[0] == "DR") {
                           $drpath = $dr_paths[$current_ds];
                           $line .= "<td class=\"tdresult\"><p>" . $drpath . "</p>\n</td>";
                        } else { # never reached if $use_only_ds == 0:
                           $displayval = $mdcontent[$col[0]];
                           $line .= "<td class=\"tdresult\">" . $displayval . "</td>";
                           $mdcontent[$col[0]] = "";
                        }
                     }
                  }
                  $line .= "</tr>\n";
                  echo $line;
               }
               if ($i1 < $num) {
                  $current_ds = $new_ds;
                  if ($use_only_ds == 0) {
                     $s1 = $rowarr[0];
                     $jpos = strpos($s1,' > HIDDEN');
                     if ($jpos !== false) {
                        $s1 = substr($s1,0,$jpos);
                     }
                     if ($rowarr[1] == "dataref" && substr($s1,0,7) == 'http://') {
                        if (preg_match (':/([^/]+)(/?)$:',$s1,$a1)) {
                           $nameshown = $a1[1];
                           if (strlen($a1[2]) == 0 && preg_match (':\.nc$:',$nameshown)) {
                              $s1 = '<a href="' . $s1 . '.html">' . $nameshown . '</a>';
                           } else {
                              $s1 = '<a href="' . $s1 . '">' . $nameshown . '</a>';
                           }
                        }
                     }
                     $mdcontent[$rowarr[1]] .= "<p>" . $s1 . "</p>\n";
                  }
               }
            }
            echo "</div>\n";
            echo "</table>\n";
         } else {
            echo "<p>Nothing found</p>\n";
         }
      }
   } else {
      echo "<p>Nothing found</p>\n";
   }
}
?>
