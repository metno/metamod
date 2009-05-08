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
<form action="gaget.php#gaform" method="POST">
<?php
   echo mmHiddenSessionField();
   $name = mmGetCategoryFncValue($mmCategoryNum,"name");
?>
<table border="0" cellspacing="5" class="orange">
   <tr><td><center>
      <table border="0" cellspacing="0" cellpadding="20"><tr>
         <td><?php echo mmSelectbutton($mmCategoryNum,"gadone","OK"); ?></td>
         <td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>
         <td><?php echo mmSelectbutton($mmCategoryNum,"garemove","Remove"); ?></td>
      </tr></table>
   </center></td></tr>
   <tr><td>
      <p>Select a rectangular search area in the map below. Click on two points in the
      map. These will be used as opposite corners in the rectangle.
      Repeate this operation until you are satisfied with the rectangle,
      then click the "OK" button. An existing rectangle will be forgotten when
      a new one is defined.<br /><br />
      To delete an existing search area, so that no search area will influence
      the overall search results, click the "Remove" button.</p>
      <p>
      <?php
         if (! file_exists("maps")) {
            if (! symlink($mmConfig->getVar('WEBRUN_DIRECTORY')."/maps","maps")) {
               mmPutLog("Error. Could not create symlink ./maps");
               $mmErrorMessage = "Sorry, internal error";
               $mmError = 1;
            }
         }
         if ($mmError == 0) {
            if (isset($mmSessionState->sitems) &&
                   array_key_exists("$mmCategoryNum,GA",$mmSessionState->sitems)) {

               $stage = $mmSessionState->sitems["$mmCategoryNum,GA"][0];
               $mmMapnum = $mmSessionState->sitems["$mmCategoryNum,GA"][1];
               $x1 = $mmSessionState->sitems["$mmCategoryNum,GA"][2];
               $y1 = $mmSessionState->sitems["$mmCategoryNum,GA"][3];
               $fname = 'maps/m' . $mmSessionId . _ . $mmMapnum . '.png';
               if ($stage == 1) {
                  $x1 = 5*floor(($x1+0.01)/5);
                  $y1 = 5*floor(($y1+0.01)/5);
                  $cmd = "convert maps/orig.png -region 5x5+" . $x1 ."+" . $y1 .
                         " -colorize 80% " . $fname;
                  system($cmd,$ier);
                  if ($ier != 0) {
                     mmPutLog("Error. Could not generate stage1 map with convert. Returned errcode: " . $ier);
                     $mmErrorMessage = "Sorry, internal error";
                     $mmError = 1;
                  }
               } else {
                  $x2 = $mmSessionState->sitems["$mmCategoryNum,GA"][4];
                  $y2 = $mmSessionState->sitems["$mmCategoryNum,GA"][5];
                  $x1 = 5*floor(($x1+0.01)/5);
                  $y1 = 5*floor(($y1+0.01)/5);
                  $x2 = 5*ceil(($x2+0.01)/5);
                  $y2 = 5*ceil(($y2+0.01)/5);
                  $xd = $x2 - $x1;
                  $yd = $y2 - $y1;
                  $cmd = "convert maps/orig.png -region " . $xd . "x" . $yd . "+" . $x1 ."+" . $y1 .
                         " -colorize 20% " . $fname;
                  system($cmd,$ier);
                  if ($ier != 0) {
                     mmPutLog("Error. Could not generate stage2 map with convert. Returned errcode: " . $ier);
                     $mmErrorMessage = "Sorry, internal error";
                     $mmError = 1;
                  }
               }
            } else {
               $fname = 'maps/orig.png';
            }
            echo '<input type="image" src="' . $fname . '" height="560" width="560" name="gacoord" align="left" />';
         }
      ?>
      </p><p><a name="gaform">&nbsp;</a>
      </p>
   </td></tr>
</table>
</form>
