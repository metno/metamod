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
<html><head>
</head><body>
<h2>View tables in the DAMOCLES database</h2>
<?php
   include "gettables.php";
   echo "<table border=0>\n";
#
# foreach key,value pair in an array
#
   reset($tables);
   foreach ($tables as $tablename => $columns) {
#   
#    foreach value in an array
#   
      echo "<tr><th style=\"text-align: left\"><a href=\"viewdb.php?dbtable=$tablename\">$tablename</a></th><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;";
      reset($columns);
      foreach ($columns as $colname) {
         echo $colname . " &nbsp;&nbsp;&nbsp;&nbsp;";
      }
      echo "</td></tr>\n";
   }
   echo "</table>\n";
?>
</body></html>
