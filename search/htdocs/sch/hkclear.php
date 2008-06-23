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
#
#  Update $mmSessionState->sitems["$mmCategoryNum,HK"]
#  Set all selected entries to non-selected:
#
$s1 = $mmCategoryNum . ",HK";
if (!isset($mmSessionState->sitems) || !array_key_exists($s1, $mmSessionState->sitems)) {
   $mmSessionState->sitems[$s1] = array();
   foreach (mmGetHK($mmCategoryNum) as $hkid => $hkvalue) {
      $mmSessionState->sitems[$s1][] = 10;
      $mmSessionState->sitems[$s1][] = 0;
      $mmSessionState->sitems[$s1][] = $hkid;
      $mmSessionState->sitems[$s1][] = $hkvalue;
   }
}
$count = count($mmSessionState->sitems[$s1]);
for ($i1=0; $i1 < $count; $i1 += 4) {
   $levelch = $mmSessionState->sitems[$s1][$i1];
   $level = round($levelch / 10);
   $mmSessionState->sitems[$s1][$i1] = 10 * $level;
}
#
#  Remove all items in $mmSessionState->sitems["$mmCategoryNum,X"]
#  and $mmSessionState->sitems["$mmCategoryNum,Y"]
#
unset($mmSessionState->sitems["$mmCategoryNum,X"]);
$mmSessionState->sitems["$mmCategoryNum,X"] = array();
unset($mmSessionState->sitems["$mmCategoryNum,Y"]);
$mmSessionState->sitems["$mmCategoryNum,Y"] = array();
?>
