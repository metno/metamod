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
include_once 'gautil.inc';
require_once("../funcs/mmFimex.inc");
require_once("../funcs/mmWMS.inc");

function displayval($mtname, $value, $dsName, $fimexSetup = false, $wmsExists = false) {
	global $mmConfig;
   $s1 = $value;
   $jpos = strpos($s1,' > HIDDEN');
   if ($jpos !== false) {
      $s1 = substr($s1,0,$jpos);
   }
   if ($mtname == "dataref") {
   	$dataUrl = $s1;
      if ((substr($s1,0,7) == 'http://') && (preg_match (':/([^/]+)(/?)$:',$s1,$a1))) {
         $nameshown = $a1[1];
         $s1 = '<a href="' . $dataUrl . '"><b>' . $nameshown . '</b></a>';
      }
      $s1 .= "<div class=\"btns\">";
      $s1 .= " <a class=\"btn\" href=\"xmlShow.php?dsName=$dsName\" target=\"_new\"><span>Show xml</span></a> ";
      $s1 .= "</div>";
      if ($wmsExists && strlen($mmConfig->getVar("WMS_URL"))) {
      	$s1 .= "<div class=\"btns\">";
      	$wmcUrl = $mmConfig->getVar("WMS_URL").
      		urlencode($mmConfig->getVar("BASE_PART_OF_EXTERNAL_URL").$mmConfig->getVar("LOCAL_URL")."/sch/getWMC.php?datasetName=$dsName");
         $s1 .= "<a class=\"btn\" href=\"$wmcUrl\" ><span>Visualize</span></a>";
         $s1 .= "</div>";
      }
      if ($fimexSetup && strlen($mmConfig->getVar("FIMEX_PROGRAM"))) {
      	$s1 .= "<div class=\"btns\">";
         foreach ($fimexSetup->getProjections() as $projName) {
         	$urlParams = $fimexSetup->getProjectionAsURLParameters($projName, $dataUrl);
         	if ($urlParams) {
            	$s1 .= '<a class=\"btn\" href="getFimexReprojectedURL.php?'.$urlParams.'" target="_new"><span>'.$projName.'</span></a>';
         	}
         }
         $s1 .= "<\div>";
      }
   }
   return $s1;
}
function showlowerlevel($parentds,$startrow,$columns,$sqlpart,$sqlPartParams) {
#
#  Show table of file level datasets (children of one directory level dataset) 
#  selected by the search criteria.
#
#  $parentds     - DS_id of the directory level dataset
#  $startrow     - The whole table may be too large to display in one part. If this
#                  is the case, $startrow represents the row number of the first row
#                  to display in the current invocation of this function (row numbers
#                  starts from 1). The number of rows allowed to show in one invocation
#                  is defined by the constant $max_secondlevel_rows below.
#  $columns      - Column names (see doshow.php)
#  $sqlpart      - Part of WHERE-clause in SQL sentence corresponding to the selected 
#                  search criteria.
# $sqlPartParams - list of parameters connected to the $sqlpart, e.g. WHERE DS_id = $1 AND DS_name = $2
#
   global $mmDbConnection, $mmColumns, $mmError, $mmErrorMessage, $mmDebug, $mmSessionState, $mmConfig;
   $prefcolumns = array();
   $max_secondlevel_rows = $mmConfig->getVar('SEARCH_APP_MAXROWS_SCNDLEV');
   $lastcolnum = 0;
   $max_columns = $mmConfig->getVar('SEARCH_APP_MAX_COLUMNS');
   reset($columns);
   $mandatory_mtname = "NOT_USED";
   foreach ($columns as $cnum => $carr) {
      $prefcolumns[$carr[0]] = $cnum;
      if ($lastcolnum < $cnum) {
         $lastcolnum = $cnum;
      }
      if ($cnum == 1) {
         $mandatory_mtname = $carr[0];
      }
   }
   $fimexSetup = getFimexSetupFromDb($mmDbConnection, $parentds);
   $wmsExists = checkWMSSetupExistsInDb($mmDbConnection, $parentds);
   $dsarr = array();
   $dbug = strpos($mmDebug,"secondlevel");
   $tmpSqlPartParams = $sqlPartParams;
   $sqlsentence = "SELECT DS_id FROM DataSet WHERE DS_parent = ". addSQLParameter($parentds, $tmpSqlPartParams);
   if ($sqlpart != "") {
      $sqlsentence .= " AND " . $sqlpart;
   }
   $sqlsentence .= " ORDER BY DataSet.DS_id\n";
   if ($dbug !== FALSE) {echo '<pre>' .$sqlsentence . ' with params ' . join(',', $tmpSqlPartParams) .'</pre>' . "\n";}
   $result1 = pg_query_params($mmDbConnection, $sqlsentence, $tmpSqlPartParams);
   if (!$result1) {
      mmPutLog(__FILE__ . __LINE__ . " Could not $sqlsentence");
      $mmErrorMessage = $msg_start . "Internal application error";
      $mmError = 1;
   } else {
      $num = pg_numrows($result1);
      if ($num > 0) {
         if ($dbug !== FALSE) {echo "<pre>Result count = $num</pre>\n";}
         for ($i1=0; $i1 < $num;$i1++) {
            list($dsid) = pg_fetch_row($result1,$i1);
            array_push($dsarr,$dsid);
         }
      }
   }
   if ($mmSessionState->countItems('9,GA') > 7) {
      $dsarr = mmGetqtnodes(7,$parentds,$dsarr);
   }
   $tmpInList = array_slice($dsarr, $startrow-1, $max_secondlevel_rows);
   if (count($tmpInList) > 0) {
		$tmpSqlParams = array();
		array_unshift($tmpInList, $parentds);
      $sqlsentence = "SELECT Metadata.MD_content, Metadata.MT_name, Dataset.DS_id, Dataset.DS_name \n" .
         " FROM Metadata, Dataset, DS_Has_MD \n" .
         " WHERE Dataset.DS_id IN " . createSQL_IN_list($tmpInList, $tmpSqlParams) . " AND\n" .
         " Metadata.MD_id = DS_Has_MD.MD_id and Dataset.DS_id = DS_Has_MD.DS_id \n" .
         " ORDER BY Dataset.DS_id ";
      if (strpos($mmDebug,"secondlevel") !== false) {
         echo "<pre>sqlsentence = $sqlsentence</pre>\n";
      }
      $result = pg_query_params($mmDbConnection, $sqlsentence, $tmpSqlParams);
      if (!$result) {
         mmPutLog(__FILE__ . __LINE__ . " Could not $sqlsentence");
         $mmErrorMessage = $msg_start . "Internal application error";
         $mmError = 1;
      }
      if ($mmError == 0) {
         $num = pg_numrows($result);
#
#  $valuecounts  - Array indexed by MT_name. Each value is an array indexed by MD_content.
#                  The parent dataset and all its children datasets are investigated.
#                  $valuecounts[mtname][mdcontent] is increased by one for each 
#                  dataset having metadata of type mtname with value mdcontent.
#                  This array is used to find columns with values equal to the parent
#                  value for all rows. Such columns are not displayed.
#
         $valuecounts = array();
         $not_empty = array();
         $dsidsfound = array();
         $dsidslast = array();
         $dsidsrows = array();
         $mtname_sort_values = array();
         $mtname_sort = $mmConfig->getVar('SEARCH_APP_SORT_COLUMN');
         $rowcounter = 0;
         for ($i1=0; $i1 < $num;$i1++) {
            list($mdcontent,$mtname,$dsid) = pg_fetch_row($result,$i1);
            if ($mtname_sort == $mtname && $dsid != $parentds) {
               $key1 = $mdcontent . sprintf('%010d',$dsid);
               if (!array_key_exists($key1,$mtname_sort_values)) {
                  $mtname_sort_values[$key1] = $dsid;
               }
            }
            if (!array_key_exists($mtname, $valuecounts)) {
               $valuecounts[$mtname] = array();
            }
            if (!array_key_exists($mdcontent, $valuecounts[$mtname])) {
               $valuecounts[$mtname][$mdcontent] = 0;
            }
            $valuecounts[$mtname][$mdcontent]++;
            if ($dsid != $parentds) {
               $not_empty[$mtname] = 1;
               if (!array_key_exists($dsid,$dsidsfound)) {
                  $rowcounter++;
                  $dsidsfound[$dsid] = $i1;
                  $dsidsrows[$rowcounter] = $dsid;
               }
               $dsidslast[$dsid] = $i1;
            }
         }
         $dsidcount = count($dsidsfound);
         if (count($mtname_sort_values) > 0) {
            ksort($mtname_sort_values);
            $dsidsrows = array();
            $rowcounter = 0;
            reset($mtname_sort_values);
            foreach ($mtname_sort_values as $dsid) {
               $rowcounter++;
               $dsidsrows[$rowcounter] = $dsid;
            }
            if (count($mtname_sort_values) < $dsidcount) {
               $arr1 = $dsidsfound;
               reset($mtname_sort_values);
               foreach ($mtname_sort_values as $dsid) {
                  if (array_key_exists($dsid, $dsidsfound)) {
                     unset ($arr1[$dsid]);
                  }
               }
               reset($arr1);
               foreach ($arr1 as $dsid => $i1) {
                  $rowcounter++;
                  $dsidsrows[$rowcounter] = $dsid;
               }
            }
         }
         if (strpos($mmDebug,"secondlevel") !== false) {
            echo "<pre>dsidcount = $dsidcount</pre>";
         }
         $usemtnames = array();
         $indexmtnames = array();
         $jindex = $lastcolnum + 1;
         reset($valuecounts);
         foreach ($valuecounts as $mtname => $mdcontarr) {
            $completecount = 0;
            $totalcount = 0;
            foreach ($mdcontarr as $mdcontent => $countval) {
               if ($countval == $dsidcount + 1) {
                  $completecount++;
               }
               $totalcount++;
            }
            if (array_key_exists($mtname, $not_empty)) {
               if ($completecount < $totalcount || $mtname == $mandatory_mtname) {
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
               }
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
         $colcount = 0;
         $jlast = 0;
         for ($i1 = 0; $i1 <= $lastcolnum; $i1++) {
            if ($colcount >= $max_columns) {
               break;
            }
            if (array_key_exists($i1,$usemtnames)) {
               $jlast = $i1;
               $colcount++;
            }
         }
         $lastcolnum = $jlast;
         $dsarrCount = count($dsarr);
         if ($dsarrCount > $max_secondlevel_rows) {
            $rowdisplayfirst = $startrow;
            $rowdisplaylast = $startrow + $max_secondlevel_rows - 1;
            if ($rowdisplaylast > $dsarrCount) {
               $rowdisplaylast = $dsarrCount;
            }
            $navigate = "<br />Rows: $rowdisplayfirst - $rowdisplaylast of $dsarrCount\n";
            if ($startrow > 1) {
               $navigate .= '<input class="exnextprev" type="submit" ' .
                            'name="mmSubmitButton_showex' . $parentds . '" value="Prev" />' . "\n";
            }
            if ($rowdisplaylast < count($dsarr)) {
               $navigate .= '<input class="exnextprev" type="submit" ' .
                            'name="mmSubmitButton_showex' . $parentds . '" value="Next" />' . "\n";
#            $newrownum = (int)(($dsidcount-0.9)/$max_secondlevel_rows);
#            $newrownum = $newrownum*$max_secondlevel_rows + 1;
#            $navigate .= '<input class="exnextprev" type="submit" ' .
#                         'name="mmSubmitButton_showex' . $parentds . '" value="' .
#                         $newrownum . '" />' . "\n";
            }
         } else {
            $navigate = "";
         }
         echo '<table border="0" cellspacing="0" cellpadding="3" width="98%">' . "\n";
         $line = '<tr><th width="30">&nbsp;</th>';
         for ($i1 = 0; $i1 <= $lastcolnum; $i1++) {
            if (array_key_exists($i1,$usemtnames)) {
               if (array_key_exists($i1,$displaynames)) {
                  $colname = $displaynames[$i1];
               } else {
                  $colname = $usemtnames[$i1];
               }
               $line .= "<th class=\"tdresult\" align=\"center\">" . $colname . $navigate . "</th>";
               $navigate = "";
            }
         }
         $line .= "</tr>\n";
         echo $line;
         $mdcontentall = array();
         for ($i2=0; $i2 <= $lastcolnum;$i2++) {
            $mdcontentall[$i2] = "";
         }
         for ($irow=1; $irow <= $dsidcount;$irow++) {
            $ifirst = $dsidsfound[$dsidsrows[$irow]];
            $ilast = $dsidslast[$dsidsrows[$irow]];
            for ($i1=$ifirst; $i1 <= $ilast;$i1++) {
               list($mdcontent,$mtname,$dsid,$dsname) = pg_fetch_row($result,$i1);
               $jindex = $indexmtnames[$mtname];
               $s1 = displayval($mtname,$mdcontent,$dsname,$fimexSetup, $wmsExists);
               $mdcontentall[$jindex] .= "<p>" . $s1 . "</p>\n";
            }
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
         echo "</table>\n";
      }
   }
}

?>
