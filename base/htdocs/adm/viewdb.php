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
require_once('../funcs/mmConfig.inc');
?>
<html>
<head>
</head><body>
<?php
$path_to_createdb_script = "../../init/createdb.sh";
include "gettables.php";
$mmDbConnection = @pg_Connect ("dbname=".$mmConfig->getVar('DATABASE_NAME')." user=".$mmConfig->getVar('PG_ADMIN_USER')." ".$mmConfig->getVar('PG_CONNECTSTRING_PHP'));
if ( $mmDbConnection ) {
?>
<p>Connection OK</p>
<?php
//   echo "<pre>\n";
//   print_r($tablesrefs);
//   echo "</pre>\n";
   $refrow = '';
   $refval = '';
   if (array_key_exists("dbtable",$_POST)) {
      $dbtable = $_POST["dbtable"];
   } else {
      $dbtable = $_GET["dbtable"];
      $refrow = $_GET["refrow"];
      $refval = $_GET["refval"];
   }
   echo "<h2>The $dbtable table:</h2>\n";
   if ($refrow == '') {
      if ($dbtable == 'DataSet') {
         $result = pg_query ($mmDbConnection, "select * from $dbtable where DS_parent = 0");
      } else {
         $result = pg_query ($mmDbConnection, "select * from $dbtable");
      }
   } else {
      if ($dbtable == "DS_Has_MD") {
         $result = pg_query ($mmDbConnection,
                             "select DS_Has_MD.DS_id, DS_Has_MD.MD_id, MT_name, MD_content" .
                             " from DS_Has_MD, Metadata where DS_Has_MD.$refrow = '$refval'" .
                             " and DS_Has_MD.MD_id = Metadata.MD_id");
      } else {
         $result = pg_query ($mmDbConnection, "select * from $dbtable where $refrow = '$refval'");
      }
   }
   if ( !$result ) {
      echo "<p>Error: Could not get rows from table $dbtable<BR>";
   } else {
      $num = pg_numrows($result);
      echo "<table border=1>\n";
      echo "<tr>\n";
      if ($refrow != '' && $dbtable == "DS_Has_MD") {
         $rowarr = array('DS_id','MD_id','MT_name','MD_content');
      } else {
         $rowarr = $tables[$dbtable];
      }
      if ($refrow == '' && $dbtable == 'DataSet') {
         $children_html = '<th>Show</th>';
      } else {
         $children_html = '';
      }
      echo $children_html . "<th>" . implode("</th><th>",$rowarr) . "</th>\n";
      echo "<th>References</th>\n";
      $flipped_rownames = array_flip($rowarr);
      echo "</tr>\n";
      for ($i1=0; $i1<$num; $i1++) {
	 echo "<tr>\n";
         $rowarr = pg_fetch_row($result, $i1);
         if ($refrow == '' && $dbtable == 'DataSet') {
            $children_html = '<td><a href="viewdb.php?dbtable=DataSet&refrow=DS_parent&refval=' .
                             $rowarr[0] . '">Children</a></td>';
         } else {
            $children_html = '';
         }
	 echo $children_html;
	 foreach ( $rowarr as $colVal) {
        echo "<td><pre>". htmlspecialchars($colVal)."</pre></td>";   
    }
    echo "\n";
         echo "<td>";
         if (array_key_exists($dbtable,$tablesrefs)) {
            $items = explode(" ",$tablesrefs[$dbtable]);
            while (count($items) > 1) {
               $tb1 = array_shift($items);
               $col1 = array_shift($items);
               $refix = $flipped_rownames[$col1];
               $val1 = $rowarr[$refix];
               echo '<a href="viewdb.php?dbtable=' . $tb1 . '&refrow=' . $col1 . 
                    '&refval=' . $val1 . '">' . $tb1 . '</a> ';
            }
         }
         echo "</td>\n";
	 echo "</tr>\n";
      }
      echo "</table>\n";
   }
}
?>
</body>
</html>
