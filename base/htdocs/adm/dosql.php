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
if (array_key_exists("sqlsentence", $_POST)) {
   $mmDbConnection = @pg_Connect ("dbname=[==DATABASE_NAME==] user=admin [==PG_CONNECTSTRING_PHP==]");
   if ( $mmDbConnection ) {
      $sqlsentence = stripslashes($_POST["sqlsentence"]);
      echo "<p>Connection OK</p>\n";
      echo "<p>SQL Sentence:</p>\n";
      echo "<pre>\n" . $sqlsentence . "\n</pre>\n";
      echo "<p>Result:</p>\n";
      $result = pg_query ($mmDbConnection, $sqlsentence);
      if ( !$result ) {
         echo "<p>Error: Could not execute:<br />\n" . $sqlsentence . "<br />\n";
      } else {
         $num = pg_numrows($result);
         echo "<table border=1>\n";
         for ($i1=0; $i1<$num; $i1++) {
	    echo "<tr>\n";
            $rowarr = pg_fetch_row($result, $i1);
	    echo "<td>" . implode("</td><td>",$rowarr) . "</td>\n";
	    echo "</tr>\n";
         }
         echo "</table>\n";
      }
   }
} else {
?>
<h3>Enter SQL sentence to perform:</h3>
<form action="dosql.php" method="post">
<textarea name="sqlsentence" rows="15" cols="120">
</textarea>
<input type="submit" value="Submit">
</form>
<?php
}
?>
</body>
</html>
