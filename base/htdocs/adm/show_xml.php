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
<title>Show .xmd and .xml dataset files</title>
</head>
<body>
<pre>
<?php
   $importdirs = "[==IMPORTDIRS==]";
   $arr_importdirs = preg_split('/\s*\n\s*/m',$importdirs);
   if ($_REQUEST["subdirectory"]) {
   	$arr_importdirs = array($_REQUEST["subdirectory"]);
   	echo "<h2><a href=\"show_xml.php\">Go to Dataset Overview</a></h2>";
   }
   $inTR = 0;
	$endTR = 1;
   foreach ($arr_importdirs as $dirpath) {
      echo "<h2>$dirpath</h2>\n";
      $bname = basename($dirpath);
      if ($_REQUEST["parent"]) {
      	$bname = $_REQUEST["parent"] . "/" . $bname;
      }
      if (is_dir($dirpath)) {
         echo "<table cellpadding=\"10\" border=\"1\">\n";
         echo "<tr><th>Subdirectory</th><th>Meta-Metadata</th><th>Metadata</th></tr>\n";
         $files = scandir($dirpath);
         foreach ($files as $file) {
         	$filePath = $dirpath.'/'.$file;
           	if (is_dir($filePath) && $file != '.' && $file != '..') {
           		if ($endTR == 0) {
           			echo "</tr>\n";
           			$endTR = 1;
           		}
           		echo "<tr><td><a href=\"show_xml.php?subdirectory=$filePath&parent=$bname\">$file</a></a></td>";
           		$inTR = 1;
           		$endTR = 0;
           	} elseif (preg_match ('/\.xmd$/i',$file)) {
           		if ($inTR == 0) {
	           		if ($endTR == 0) {
   	        			echo "</tr>\n";
      	     			$endTR = 1;
         	  		}
           			echo "<tr><td></td>";
           			$inTR++;
           			$endTR = 0;
           		}
               echo "<td><a href=\"$bname/$file\">$file</a> <a href=\"edit_xml.php?file=$filePath\">(edit)</a></td>";
            } elseif (preg_match ('/\.xml$/i',$file)) {
           		if ($inTR == 0) {
	           		if ($endTR == 0) {
   	        			echo "</tr>\n";
      	     			$endTR = 1;
         	  		}
           			echo "<tr><td></td><td></td>";
           			$inTR++;
           			$endTR = 0;
           		}
               echo "<td><a href=\"$bname/$file\">$file</a> <a href=\"edit_xml.php?file=$filePath\">(edit)</a></td></tr>\n";
               $inTR = 0;
					$endTR = 1;
            }
         }
         echo "</table>\n";
      } else {
         echo "Directory not found";
      }
   }
?>
</pre>
</body>
</html>
