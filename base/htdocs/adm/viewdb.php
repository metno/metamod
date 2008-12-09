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
<html>
<head>
</head><body>
<?php
include "gettables.php";
$mmDbConnection = @pg_Connect ("dbname=[==DATABASE_NAME==] user=[==PG_ADMIN_USER==] [==PG_CONNECTSTRING_PHP==]");
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
      $result = pg_query ($mmDbConnection, "select * from $dbtable");
   } else {
      $result = pg_query ($mmDbConnection, "select * from $dbtable where $refrow = '$refval'");
   }
   if ( !$result ) {
      echo "<p>Error: Could not get rows from table $dbtable<BR>";
   } else {
      $num = pg_numrows($result);
      echo "<table border=1>\n";
      echo "<tr>\n";
      $rowarr = $tables[$dbtable];
      echo "<th>" . implode("</th><th>",$rowarr) . "</th>\n";
      echo "<th>References</th>\n";
      $flipped_rownames = array_flip($rowarr);
      echo "</tr>\n";
      for ($i1=0; $i1<$num; $i1++) {
	 echo "<tr>\n";
         $rowarr = pg_fetch_row($result, $i1);
	 echo "<td>" . implode("</td><td>",$rowarr) . "</td>\n";
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
