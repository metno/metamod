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
   if ($mmError == 0) {
      if (isset($mmSessionState->sitems) &&
            array_key_exists("$mmCategoryNum,GA",$mmSessionState->sitems)) {

         $stage = $mmSessionState->sitems["$mmCategoryNum,GA"][0];
         $mmMapnum = $mmSessionState->sitems["$mmCategoryNum,GA"][1];
         if ($stage == 1) { # The user has only defined one point in the rectangle
            unset($mmSessionState->sitems["$mmCategoryNum,GA"]);
         } else {
            if (strlen($mmConfig->getVar("USE_QUADTREE"))) {
            	$drhash = mmGetqtnodes(7,0);
            	$mmSessionState->sitems["$mmCategoryNum,GA"][6] = count($drhash);
            	foreach ($drhash as $did) {
               	$mmSessionState->sitems["$mmCategoryNum,GA"][] = $did;
            	}               
            }
         }
      }
   }
?>
