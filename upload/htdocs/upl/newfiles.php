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
#
   require_once("../funcs/mmConfig.inc");
   require_once "funcs.inc";
   $debug = $mmConfig->getVar('DEBUG');
   $error = 0;
   if (!array_key_exists("dataset", $_GET)) {
      $error = 1;
   }
   if (!array_key_exists("dirkey", $_GET)) {
      $error = 1;
   }
   if (!array_key_exists("filenames", $_GET)) {
      $error = 1;
   }
   if ($error == 0) {
      $command = $mmConfig->getVar('TARGET_DIRECTORY') . "/scripts/upload_indexer.pl";
      $command .= " --dataset=" . $_GET["dataset"];
      $command .= " --dirkey=" . $_GET["dirkey"];
      $command .= " " . str_replace(',',' ',$_GET["filenames"]);
      $output = array();
      mmPutLog("--------- newfiles.php: command=" . $command);
      exec($command,$output,$error);
   }
   if ($error == 0) {
      header("HTTP/1.1 200 OK");
   } else {
      header("HTTP/1.1 404 Not found");
   }
?>
