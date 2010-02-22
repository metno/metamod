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
   if (array_key_exists("gamap_srid", $_POST)) {
      # switch to a new map
      $srid = $_POST["gamap_srid"];
      $mmSessionState->sitems["$mmCategoryNum,GA"] = array(0,$srid);

   } elseif (!array_key_exists("gacoord_x",$_POST) || !array_key_exists("gacoord_y",$_POST)) {
       mmPutLog("Error. Could not get coordinates from image type input button");
       $mmErrorMessage = "Sorry, internal error";
       $mmError = 1;
   } else {
      $xco = $_POST["gacoord_x"];
      $yco = $_POST["gacoord_y"];
      if (isset($mmSessionState->sitems) &&
            array_key_exists("$mmCategoryNum,GA",$mmSessionState->sitems)) {
         $stage = $mmSessionState->sitems["$mmCategoryNum,GA"][0];
         $srid = $mmSessionState->sitems["$mmCategoryNum,GA"][1];
      } else {
         $stage = 2;
         # set srid to first available in config
         list($srid) = preg_split('/\s+/', $mmConfig->getVar('SRID_ID_COLUMNS'));
      }
   }
   if ($mmError == 0) {
      if ($stage == 1) {
         $newstage = 2;
         $x1 = $mmSessionState->sitems["$mmCategoryNum,GA"][2];
         $y1 = $mmSessionState->sitems["$mmCategoryNum,GA"][3];
         $x2 = $xco;
         $y2 = $yco;
         if ($x2 < $x1) {
            $xx = $x1;
            $x1 = $x2;
            $x2 = $xx;
         }
         if ($y2 < $y1) {
            $yy = $y1;
            $y1 = $y2;
            $y2 = $yy;
         }
         $mmSessionState->sitems["$mmCategoryNum,GA"] = array($newstage,$srid,$x1,$y1,$x2,$y2);
      } else {
         $newstage = 1;
         $x1 = $xco;
         $y1 = $yco;
         $mmSessionState->sitems["$mmCategoryNum,GA"] = array($newstage,$srid,$x1,$y1);
      }
   }
?>
