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
include "hkupdate.php";
#
#  Replace all items in $mmSessionState->sitems["$mmCategoryNum,X"]
#  with updated values:
#
unset($mmSessionState->sitems["$mmCategoryNum,X"]);
$mmSessionState->sitems["$mmCategoryNum,X"] = array();
unset($mmSessionState->sitems["$mmCategoryNum,Y"]);
$mmSessionState->sitems["$mmCategoryNum,Y"] = array();
$s1 = $mmCategoryNum . ",HK";
if (isset($mmSessionState->sitems) && array_key_exists($s1, $mmSessionState->sitems)) {
   $keyarr = $mmSessionState->sitems[$s1];
   while ($newlevch = array_shift($keyarr)) {
      $newhidden = array_shift($keyarr);
      $newid = array_shift($keyarr);
      $newname = array_shift($keyarr);
      if ($newlevch % 10 == 1) {
         if ($newlevch < 990) {
            $mmSessionState->sitems["$mmCategoryNum,Y"][$newid] = 1;
         } else {
            $mmSessionState->sitems["$mmCategoryNum,X"][$newid] = 1;
         }
      }
   }
}
?>
