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
require_once("../funcs/mmConfig.inc"); 
?>
<html>
<head>
<title>File Upload Users</title>
</head>
<body>
<?php
#
#  Get array containing all files in a directory
#
   $userfiles = scandir($mmConfig->getVar('WEBRUN_DIRECTORY')."/u1");
   reset($userfiles);
   foreach ($userfiles as $filename) {
      $firstchar = substr($filename,0,1);
      if ($firstchar != '.') {
#
#        Get last file modification time
#
         $filepath = $mmConfig->getVar('WEBRUN_DIRECTORY')."/u1/$filename";
         $modified = filemtime($filepath);
         $modified_str = date('Y-m-d H:i',$modified);
         echo "<h3>$filename modified $modified_str</h3>\n<pre>\n";
         $content = file_get_contents($filepath);
         $content_ent = htmlentities($content);
         echo $content_ent;
         echo "\n</pre>\n";
      }
   }
?>
</body>
</html>
