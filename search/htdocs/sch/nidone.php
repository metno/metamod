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
#  Replace all items in $mmSessionState->sitems["$mmCategoryNum,NI"]
#  with updated values:
#
unset($mmSessionState->sitems["$mmCategoryNum,NI"]);
$from = $_POST["from"];
$to = $_POST["to"];
if (preg_match ('/^[0-9-]+$/',$to) && preg_match ('/^[0-9-]+$/',$from)) {
   $mmSessionState->sitems["$mmCategoryNum,NI"] = array();
   $numtype = mmGetCategoryFncValue($mmCategoryNum,"numtype");
   if ($numtype == "date") {
      $fromarr = explode("-",$_POST["from"]);
      $from = "";
      foreach ($fromarr as $tval) {
         $from .= $tval;
      }
      $from .= "00000000";
      $from = substr($from,0,8);
      $toarr = explode("-",$_POST["to"]);
      $to = "";
      foreach ($toarr as $tval) {
         $to .= $tval;
      }
      $to .= "99999999";
      $to = substr($to,0,8);
   }
   $mmSessionState->sitems["$mmCategoryNum,NI"][0] = $from;
   $mmSessionState->sitems["$mmCategoryNum,NI"][1] = $to;
}
?>
