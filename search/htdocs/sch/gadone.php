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
   include_once 'gautil.inc';
   if (! file_exists("maps")) {
      mmPutLog("Error. Directory ./maps not found");
      $mmErrorMessage = "Sorry, internal error";
      $mmError = 1;
   }
   if ($mmError == 0) {
      if (isset($mmSessionState->sitems) &&
            array_key_exists("$mmCategoryNum,GA",$mmSessionState->sitems)) {

         $stage = $mmSessionState->sitems["$mmCategoryNum,GA"][0];
         $mmMapnum = $mmSessionState->sitems["$mmCategoryNum,GA"][1];
         $fname = 'maps/m' . $mmSessionId . _ . $mmMapnum . '.png';
         if ($stage == 1) { # The user has only defined one point in the rectangle
            unset($mmSessionState->sitems["$mmCategoryNum,GA"]);
         } else {
            $tfname = 'maps/t' . $mmSessionId . _ . $mmMapnum . '.png';
            $cmd = "convert " . $fname . " -resize 150 " . $tfname;
            system($cmd,$ier);
            if ($ier != 0) {
               mmPutLog("Error. Failed command: " . $cmd . " Returned errcode: " . $ier);
               $mmErrorMessage = "Sorry, internal error";
               $mmError = 1;
            }
            $drhash = mmGetqtnodes(7,0);
            $mmSessionState->sitems["$mmCategoryNum,GA"][6] = count($drhash);
            foreach ($drhash as $did) {
               $mmSessionState->sitems["$mmCategoryNum,GA"][] = $did;
            }
         }
         if (!unlink($fname)) {
            mmPutLog("Error. Could not unlink " . $fname);
            $mmErrorMessage = "Sorry, internal error";
            $mmError = 1;
         }
      }
   }
?>
