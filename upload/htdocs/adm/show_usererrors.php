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
<title>User error files</title>
</head>
<body>
<p>
<?php
#
#  Get array containing all files in a directory
#
   $errfiles = scandir($mmConfig->getVar('WEBRUN_DIRECTORY')."/upl/uerr");
   reset($errfiles);
   foreach ($errfiles as $filename) {
      if (preg_match ('/\.html$/',$filename)) {
         echo '<a href='.$mmConfig->getVar('LOCAL_URL').'/upl/uerr/' . $filename . '">' . $filename . '</a><br />' . "\n";
      }
   }
?>
</p>
</body>
</html>
