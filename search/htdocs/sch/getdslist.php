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
$sqlsentence = "SELECT DS_id, DS_name \n" .
               "   FROM DataSet WHERE DS_ownertag IN ([==DATASET_TAGS==]) AND \n";
$j1 = 0;
#
# foreach value in an array
#
reset($mmCategorytype);
foreach ($mmCategorytype as $category => $type) {
   $bkids_from_hk = array();
   $s1 = $category . ',Y';
   if (count($mmSessionState->sitems[$s1]) > 0) {
      $hkids = array_keys($mmSessionState->sitems[$s1]);
      $sql1 = "SELECT DISTINCT BK_id FROM HK_Represents_BK WHERE HK_id IN (" .
         implode(', ',$hkids) . ")\n";
      $res1 = pg_query ($mmDbConnection, $sql1);
      if (!$res1) {
         mmPutLog(__FILE__ . __LINE__ . " Could not $sql1");
         $mmErrorMessage = $msg_start . "Internal application error";
         $mmError = 1;
      } else {
         $num = pg_numrows($res1);
         if ($num > 0) {
            for ($i1=0; $i1 < $num;$i1++) {
               $rowarr = pg_fetch_row($res1,$i1);
               $bkids_from_hk[] = $rowarr[0];
            }
         }
      }
   }
   $bkids_from_bk = array();
   $s1 = $category . ',X';
   if (count($mmSessionState->sitems[$s1]) > 0) {
      $bkids_from_bk = array_keys($mmSessionState->sitems[$s1]);
   }
   $bkids = array_merge($bkids_from_hk,$bkids_from_bk);
   $bkids = array_unique($bkids);
   if (count($bkids) > 0) {
      if ($j1 > 0) {
         $sqlsentence .= "      AND \n";
      }
      $sqlsentence .= "      DS_id IN (" .
         " SELECT DISTINCT DS_id FROM BK_describes_DS WHERE BK_id IN (" .
         implode(', ',$bkids) . ") )\n";
      $j1++;
   }
   $s1 = $category . ',NI';
   if (count($mmSessionState->sitems[$s1]) > 0) {
      if ($j1 > 0) {
         $sqlsentence .= "      AND \n";
      }
      $bkids = array_keys($mmSessionState->sitems[$s1]);
      $sqlsentence .= "      DS_id IN (" .
         " SELECT DISTINCT DS_id FROM NumberItem WHERE SC_id = " .
         $category . " AND NI_from <= " . $mmSessionState->sitems[$s1][1] . " AND " .
         " NI_to >= " . $mmSessionState->sitems[$s1][0] . ")\n";
      $j1++;
   }
   $s1 = $category . ',GA';
   if (count($mmSessionState->sitems[$s1]) > 7) {
      if ($j1 > 0) {
         $sqlsentence .= "      AND \n";
      }
      $drsearch = array_slice($mmSessionState->sitems[$s1],7);
      $sqlsentence .= "      DS_id IN (" . implode($drsearch,', ') . ")\n";
      $j1++;
   }
}
$dr_paths = array();
$ds_arr = array();
$ds_ids = "";
if ($j1 > 0) {
   $sqlsentence .= "ORDER BY DataSet.DS_id\n";
#   echo '<pre>' .$sqlsentence . '</pre>' . "\n";
   $result1 = pg_query ($mmDbConnection, $sqlsentence);
   if (!$result1) {
      mmPutLog(__FILE__ . __LINE__ . " Could not $sqlsentence");
      $mmErrorMessage = $msg_start . "Internal application error";
      $mmError = 1;
   } else {
      $num = pg_numrows($result1);
      if ($num > 0) {
         for ($i1=0; $i1 < $num;$i1++) {
            $rowarr = pg_fetch_row($result1,$i1);
            $dr_paths[$rowarr[0]] = $rowarr[1];
            $ds_arr[$i1] = $rowarr[0];
            if ($i1 > 0) {
               $ds_ids .= ',';
            }
            $ds_ids .= $rowarr[0];
         }
      }
   }
}
?>
