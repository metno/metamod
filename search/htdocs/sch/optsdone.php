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
$maxcol = [==SEARCH_APP_MAX_COLUMNS==];
if (array_key_exists("update",$_POST)) {
   $mmSessionState->options = array();
   for ($i1 = 1; $i1 <= $maxcol; $i1++) {
      if (array_key_exists($i1,$_POST)) {
         $key = 'col=' . $i1;
         $mmSessionState->options[$key] = $_POST[$i1];
      }
   }
   if (array_key_exists("v",$_POST)) {
      $mmSessionState->options["cross=v"] = $_POST["v"];
   }
   if (array_key_exists("h",$_POST)) {
      $mmSessionState->options["cross=h"] = $_POST["h"];
   }
   if (array_key_exists("fontsize",$_POST)) {
      $mmSessionState->options["fontsize"] = $_POST["fontsize"];
   }
} elseif (array_key_exists("defaults",$_POST)) {
   $mmSessionState->options = mmInitialiseOptions();
}
?>
