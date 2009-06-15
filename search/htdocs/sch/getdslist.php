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
function getdslist() {
   global $mmError, $mmDbConnection, $mmCategorytype, $mmSessionState, $mmDebug, $mmConfig;
#
#  This script computes arrays:
#
#     $ds_arr    - Contains DS_id for all top level datasets matching the search
#                  criteria. Indexed from 0 and up.
#     $dr_paths  - Contains DS_name for all top level datasets in $ds_arr.
#                  Indexed by DS_id.
#     $ds_with_children
#                - Array with DS_ids as key. Set to 1 for each DS_id representing
#                  a dataset having children.
#
#  and a character string:
#
#     $sqlpart   - Part of SQL WHERE clause corresponding to the selected search
#                  criteria (apart from the map search criteria).
#
   $sqlpart = "";
   $sql_gapart = "";
   $j1 = 0;
#
# foreach value in an array
#
   reset($mmCategorytype);
   foreach ($mmCategorytype as $category => $type) {
      $bkids_from_hk = array();
      $s1 = $category . ',Y';
      if ($mmSessionState->countItems($s1) > 0) {
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
      if ($mmSessionState->countItems($s1) > 0) {
         $bkids_from_bk = array_keys($mmSessionState->sitems[$s1]);
      }
      $bkids = array_merge($bkids_from_hk,$bkids_from_bk);
      $bkids = array_unique($bkids);
      if (count($bkids) > 0) {
         if ($j1 > 0) {
            $sqlpart .= "      AND \n";
         }
         $sqlpart .= "      DS_id IN (" .
            " SELECT DISTINCT DS_id FROM BK_describes_DS WHERE BK_id IN (" .
            implode(', ',$bkids) . ") )\n";
         $j1++;
      }
      $s1 = $category . ',NI';
      if ($mmSessionState->countItems($s1) > 0) {
         if ($j1 > 0) {
            $sqlpart .= "      AND \n";
         }
         $bkids = array_keys($mmSessionState->sitems[$s1]);
         $sqlpart .= "      DS_id IN (" .
            " SELECT DISTINCT DS_id FROM NumberItem WHERE SC_id = " .
            $category . " AND NI_from <= " . $mmSessionState->sitems[$s1][1] . " AND " .
            " NI_to >= " . $mmSessionState->sitems[$s1][0] . ")\n";
         $j1++;
      }
      $s1 = $category . ',GA';
      if ($mmSessionState->countItems($s1) > 7) {
         $drsearch = array_slice($mmSessionState->sitems[$s1],7);
         $sql_gapart .= "      (DS_id IN (" . implode(', ',$drsearch) . "))\n";
      }
   }
   if (strlen($mmSessionState->fullTextQuery) > 0) {
   	// TODO have syntax for compount query, currently only single words
   	$ftQuery = pg_escape_string($mmSessionState->fullTextQuery);
      if ($j1 > 0) {
         $sqlpart .= "      AND \n";
      }
		$j1++;
   	$sqlpart .=  <<<EOFT
      DS_id IN (
       SELECT DISTINCT(DataSet.DS_id) FROM DS_Has_MD, Metadata, DataSet
        WHERE DataSet.DS_id  = DS_Has_MD.DS_id
          AND Metadata.MD_id = DS_HAS_MD.MD_id
          AND MD_content_vector @@ to_mmDefault_tsquery('$ftQuery')
      )
      
EOFT;
   	
   }
   
   $dbug = strpos($mmDebug,"getdslist");
   $dr_paths = array();
   $ds_arr = array();
   $ds_with_children = array();
   if (($sqlpart != "" || $sql_gapart != "") && $mmError == 0) {
      $sqlsentence = "SELECT DISTINCT DS_parent FROM DataSet ORDER BY DS_parent";
      if ($dbug !== FALSE) {echo '<pre>' .$sqlsentence . '</pre>' . "\n";}
      $result1 = pg_query ($mmDbConnection, $sqlsentence);
      if (!$result1) {
         mmPutLog(__FILE__ . __LINE__ . " Could not $sqlsentence");
         $mmErrorMessage = $msg_start . "Internal application error";
         $mmError = 1;
      } else {
         $num = pg_numrows($result1);
         if ($dbug !== FALSE) {echo '<pre>Result count = ' . $num . '</pre>' . "\n";}
         if ($num > 0) {
            for ($i1=0; $i1 < $num;$i1++) {
               list($dsid) = pg_fetch_row($result1,$i1);
               if ($dsid > 0) {
                  $ds_with_children[$dsid] = 1;
               }
            }
         }
      }
   }
   if (($sqlpart != "" || $sql_gapart != "") && $mmError == 0) {
      $sqlsentence = "SELECT DS_id, DS_name FROM DataSet WHERE\n" .
                  "DS_parent = 0 AND DS_ownertag IN (".$mmConfig->getVar('DATASET_TAGS').") \n";
                  $sqlpart . $sql_gapart . "ORDER BY DataSet.DS_id\n";
      if ($sqlpart != "") {
         $sqlsentence .= " AND " . $sqlpart;
      }
      if ($sql_gapart != "") {
         $sqlsentence .= " AND " . $sql_gapart;
      }
      $sqlsentence .= "ORDER BY DataSet.DS_id\n";
      if ($dbug !== FALSE) {echo '<pre>' .$sqlsentence . '</pre>' . "\n";}
      $result1 = pg_query ($mmDbConnection, $sqlsentence);
      if (!$result1) {
         mmPutLog(__FILE__ . __LINE__ . " Could not $sqlsentence");
         $mmErrorMessage = $msg_start . "Internal application error";
         $mmError = 1;
      } else {
         $num = pg_numrows($result1);
         if ($num > 0) {
            if ($dbug !== FALSE) {echo "<pre>dsid, dsname, dsparent:\n";}
            for ($i1=0; $i1 < $num;$i1++) {
               list($dsid, $dsname) = pg_fetch_row($result1,$i1);
               if ($dbug !== FALSE) {echo "$dsid, $dsname\n";}
               $dr_paths[$dsid] = $dsname;
               array_push($ds_arr,$dsid);
            }
            if ($dbug !== FALSE) {echo "</pre>\n";}
         }
      }
   }
   return array($ds_arr,$dr_paths,$ds_with_children,$sqlpart);
}
?>
