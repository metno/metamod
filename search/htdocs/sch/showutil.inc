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
function displayval($mtname, $value) {
   $s1 = $value;
   $jpos = strpos($s1,' > HIDDEN');
   if ($jpos !== false) {
      $s1 = substr($s1,0,$jpos);
   }
   if ($mtname == "dataref" && substr($s1,0,7) == 'http://') {
      if (preg_match (':/([^/]+)(/?)$:',$s1,$a1)) {
         $nameshown = $a1[1];
         if (strlen($a1[2]) == 0 && preg_match (':\.nc$:',$nameshown)) {
            $s1 = '<a href="' . $s1 . '.html">' . $nameshown . '</a>';
         } else {
            $s1 = '<a href="' . $s1 . '">' . $nameshown . '</a>';
         }
      }
   }
   return $s1;
}
function showlowerlevel($dsarr,$columns) {
   global $mmDbConnection, $mmColumns, $mmError, $mmErrorMessage;
   $prefcolumns = array();
   $lastcolnum = 0;
   $max_columns = [==SEARCH_APP_MAX_COLUMNS==];
   reset($columns);
   foreach ($columns as $cnum => $carr) {
      $prefcolumns[$carr[0]] = $cnum;
      if ($lastcolnum < $cnum) {
         $lastcolnum = $cnum;
      }
   }
   $dslist = implode(",",$dsarr);
   $sqlsentence = "SELECT Metadata.MD_content, Metadata.MT_name, Dataset.DS_id \n" .
      "FROM Metadata, Dataset, DS_Has_MD \n" .
      "WHERE Dataset.DS_id IN (" . $dslist . ") AND\n" .
      "Metadata.MD_id = DS_Has_MD.MD_id and Dataset.DS_id = DS_Has_MD.DS_id \n" .
      "ORDER BY Dataset.DS_id \n";
   $result = pg_query ($mmDbConnection, $sqlsentence);
   if (!$result) {
      mmPutLog(__FILE__ . __LINE__ . " Could not $sqlsentence");
      $mmErrorMessage = $msg_start . "Internal application error";
      $mmError = 1;
   }
   if ($mmError == 0) {
      $num = pg_numrows($result);
      $valuecounts = array();
      $dsidsfound = array();
      for ($i1=0; $i1 < $num;$i1++) {
         list($mdcontent,$mtname,$dsid) = pg_fetch_row($result,$i1);
         if (!array_key_exists($mtname, $valuecounts)) {
            $valuecounts[$mtname] = array();
         }
         if (!array_key_exists($mdcontent, $valuecounts[$mtname])) {
            $valuecounts[$mtname][$mdcontent] = 0;
         }
         $valuecounts[$mtname][$mdcontent]++;
         $dsidsfound[$dsid] = 1;
      }
      $dsidcount = count($dsidsfound);
      $usemtnames = array();
      $indexmtnames = array();
      $jindex = $lastcolnum + 1;
      $columncount = 0;
      reset($valuecounts);
      foreach ($valuecounts as $mtname => $mdcontarr) {
         if ($columncount >= $max_columns) {
            break;
         }
         $completecount = 0;
         $totalcount = 0;
         foreach ($mdcontarr as $mdcontent => $countval) {
            if ($countval == $dsidcount) {
               $completecount++;
            }
            $totalcount++;
         }
         if ($completecount < $totalcount) {
            if (array_key_exists($mtname, $prefcolumns)) {
               $ix = $prefcolumns[$mtname];
            } else {
               $ix = $jindex;
               $jindex++;
            }
            $usemtnames[$ix] = $mtname;
            $indexmtnames[$mtname] = $ix;
            if ($ix > $lastcolnum) {
               $lastcolnum = $ix;
            }
            $columncount++;
         }
      }
      $displaynames = array();
      reset($mmColumns);
      foreach ($mmColumns as $col) {
         $jkey = array_search($col[0],$usemtnames);
         if ($jkey !== FALSE) {
            $displaynames[$jkey] = $col[1];
         }
      }
      $colcount = count($usemtnames);
      echo '<table border="0" cellspacing="0" cellpadding="3" width="98%">' . "\n";
      $line = '<tr><th width="30">&nbsp;</th>';
      for ($i1 = 0; $i1 <= $lastcolnum; $i1++) {
         if (array_key_exists($i1,$usemtnames)) {
            if (array_key_exists($i1,$displaynames)) {
               $colname = $displaynames[$i1];
            } else {
               $colname = $usemtnames[$i1];
            }
            $line .= "<th class=\"tdresult\" align=\"center\">" . $colname . "</th>";
         }
      }
      $line .= "</tr>\n";
      echo $line;
      $mdcontentall = array();
      for ($i2=0; $i2 <= $lastcolnum;$i2++) {
         $mdcontentall[$i2] = "";
      }
      $current_ds = -1;
      for ($i1=0; $i1 <= $num;$i1++) {
         if ($i1 < $num) {
            list($mdcontent,$mtname,$dsid) = pg_fetch_row($result,$i1);
         }
         if ($i1 == $num || ($current_ds >= 0 && $dsid != $current_ds)) {
            $line = "<tr><td>&nbsp;</td>\n";
            for ($i2=0; $i2 <= $lastcolnum;$i2++) {
               if (array_key_exists($i2,$usemtnames)) {
                  $line .= '<td class="tdresult">' . $mdcontentall[$i2] . "</td>\n";
                  $mdcontentall[$i2] = "";
               }
            }
            $line .= "</tr>\n";
            echo $line;
         }
         if ($i1 < $num) {
            $jindex = $indexmtnames[$mtname];
            $s1 = displayval($mtname,$mdcontent);
            $mdcontentall[$jindex] .= "<p>" . $s1 . "</p>\n";
            $current_ds = $dsid;
         }
      }
      echo "</table>\n";
   }
}
?>
