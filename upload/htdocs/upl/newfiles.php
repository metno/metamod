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
      $message = "Query did not contain a dataset value";
   }
   if (!array_key_exists("dirkey", $_GET)) {
      $error = 1;
      $message = "Query did not contain a dirkey value";
   }
   # use filename[] as parameter to indicate array, otherwise, use filename
   if (!array_key_exists("filename", $_GET)) {
      $error = 1;
      $message = "Query did not contain any files values";
   }
   if ($error == 0) {
      $command = $mmConfig->getVar('TARGET_DIRECTORY') . "/scripts/upload_indexer.pl";
      $command .= " --dataset=" . $_GET["dataset"];
      $command .= " --dirkey=" . $_GET["dirkey"];
      $filenames = $_GET["filename"];
      if (is_array($filenames)) {
         $filenames = join(' ', $filenames);
      }
      $command .= " " . $filenames;
      $command = escapeshellcmd($command);
      $output = array();
      mmPutLog("--------- newfiles.php: command=" . $command);
      $message = exec($command,$output,$error);
   }
   if ($error == 0) {
      header("HTTP/1.1 200 OK");
      echo $message;
   } else {
      header("HTTP/1.1 500 Internal Server Error");
      echo $message;
   }
?>
