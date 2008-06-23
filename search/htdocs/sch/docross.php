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
# print_r($mmSessionState->options);
reset($mmSessionState->options);
foreach ($mmSessionState->options as $opt => $mtname) {
   if (substr($opt,0,6) == 'cross=') {
      $hv = substr($opt,6);
      if (! in_array($hv, array('v','h'))) {
         mmPutLog(__FILE__ . __LINE__ . " Illegal option: $opt");
         $mmErrorMessage = $msg_start . "Internal application error";
         $mmError = 1;
         break;
      }
      $columns[$hv] = array();
      $columns[$hv][0]= $mtname;
      $columns[$hv][1]= "";
      reset($mmColumns);
      foreach ($mmColumns as $col) {
         if ($col[0] == $mtname) {
            $columns[$hv][1]= $col[1];
         }
      }
   }
}
if ($mmError == 0) {
# echo "<pre>\ncolumns ---------\n";
# print_r($columns);
# echo "</pre>\n";
#
#   Compute array $ds_arr and comma-separated string $ds_ids containing all
#   dataset ids satisfying the current search criteria:
#
   include 'getdslist.php';
}
if ($mmError == 0 && strlen($ds_ids) > 0 && count($columns) > 0) {
   $vert_arr = array();
   $hor_arr = array();
   foreach (array('v','h') as $hv) {
      if (array_key_exists($hv, $columns)) {
         $mtname = $columns[$hv][0];
         $sqlsentence = "SELECT Metadata.MD_content, Dataset.DS_id \n" .
            "FROM Metadata, Dataset, DS_Has_MD \n" .
            "WHERE Dataset.DS_id in (" . $ds_ids . ") AND\n" .
            "Metadata.MT_name = '" . $mtname . "' AND \n" .
            "Metadata.MD_id = DS_Has_MD.MD_id and Dataset.DS_id = DS_Has_MD.DS_id \n" .
            "ORDER BY Dataset.DS_id \n";
         $result = pg_query ($mmDbConnection, $sqlsentence);
         if (!$result) {
            mmPutLog(__FILE__ . __LINE__ . " Could not $sqlsentence");
            $mmErrorMessage = $msg_start . "Internal application error";
            $mmError = 1;
            break;
         } else {
            $num = pg_numrows($result);
#           echo "Count: " . $num . "<br />\n";
            if ($num > 0) {
               for ($i1=0; $i1 < $num;$i1++) {
                  $rowarr = pg_fetch_row($result,$i1);
                  $s1 = $rowarr[0];
                  $jpos = strpos($s1,' > HIDDEN');
                  if ($jpos !== false) {
                     $s1 = substr($s1,0,$jpos);
                  }
                  if ($hv == 'v') {
                     if (! array_key_exists($s1, $vert_arr)) {
                        $vert_arr[$s1] = array();
                     }
                     $vert_arr[$s1][] = $rowarr[1];
                  } else {
                     if (! array_key_exists($s1, $hor_arr)) {
                        $hor_arr[$s1] = array();
                     }
                     $hor_arr[$s1][] = $rowarr[1];
                  }
               }
            }
         }
      }
   }
   if ($mmError == 0) {
      $fontsize = [==DEFAULT_FONTSIZE==];
      if (array_key_exists("fontsize",$mmSessionState->options)) {
         $fontsize = $mmSessionState->options["fontsize"];
      }
      echo '<div style="font-size: ' . $fontsize . '%">' . "\n";
      echo "<table border=\"0\" cellspacing=\"0\" cellpadding=\"3\" width=\"98%\">\n";
      $line = "<tr><th class=\"tdresult\">&nbsp;</th>";
      if (count($hor_arr) > 0) {
         foreach ($hor_arr as $colname => $dshor) {
            $line .= "<th class=\"tdresult\" align=\"center\">" . $colname . "</th>";
         }
      } else {
         $line .= "<th class=\"tdresult\">Total:</th>";
      }
      $line .= "</tr>\n";
      echo $line;
      if (count($vert_arr) > 0) {
         foreach ($vert_arr as $rowname => $dsvert) {
            $line = "<tr><th class=\"tdresult\">" . $rowname . "</th>";
            if (count($hor_arr) > 0) {
               foreach ($hor_arr as $dshor) {
                  $n1 = count(array_intersect($dsvert,$dshor));
                  $line .= "<td class=\"tdresult\">" . $n1 . "</td>";
               }
            } else {
               $n1 = count($dsvert);
               $line .= "<td class=\"tdresult\">" . $n1 . "</td>";
            }
            $line .= "</tr>\n";
            echo $line;
         }
      } else {
         $line = "<tr><th class=\"tdresult\">Total:</th>";
         if (count($hor_arr) > 0) {
            foreach ($hor_arr as $dshor) {
               $n1 = count($dshor);
               $line .= "<td class=\"tdresult\">" . $n1 . "</td>";
            }
         } else {
            $n1 = count($ds_arr);
            $line .= "<td class=\"tdresult\">$n1</td>";
         }
         $line .= "</tr>\n";
         echo $line;
      }
      echo "</table>\n";
      echo "</div>\n";
   }
}
?>
