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
   if (!isset($mmSelectedNum)) {
      echo '<a name="current"></a>' . "\n";
   }
?>
<form action="search.php#current" method="POST">
<?php
   echo mmHiddenSessionField();
   $name = mmGetCategoryFncValue($mmCategoryNum,"name");
   $name1 = str_replace(' ','_',$name);
?>
<table cellspacing="5" class="orange">
   <tr><td><center>
      <table border="0" cellspacing="0" cellpadding="20"><tr>
         <td><?php echo mmSelectbutton($mmCategoryNum,"hkdone","Select"); ?></td>
         <td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>
         <td><?php echo mmSelectbutton($mmCategoryNum,"hkclear","Clear All"); ?></td>
      </tr></table>
   </center></td></tr>
   <tr><td>
<?php
echo <<<END_TEXT
   <p>Mark one or more $name in the tree structure below by checking checkboxes in the
   the tree. Parts of the tree may be hidden beneath branch buttons.
   Click a <span class="hkplusminus">+</span> branch button to expand the branch one level.
   You may have to do this again
   on branch buttons on the new level in order to reach the bottom nodes.
   Expanded branches can be collapsed by clicking the corresponding 
   <span class="hkplusminus">-</span> button.</p>
   <p>When all the wanted check buttons are checked, click the "Select" button above.</p>
   <p>The selected $name will restrict the data references available for selection through
   other parts of this web interface. Only data references corresponding to one of the selected
   $name will be available. If no $name are selected, no restrictions regarding $name are used.
   </p>
END_TEXT;
?>
   </td></tr>

   <tr>
      <td>
         <font size="+1">Available <?php echo $name; ?>:</font>
      </td>
   </tr>

   <tr><td>
<?php
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
$level = 1;
$hidelevel = 0;
$keyarr = $mmSessionState->sitems[$s1];
while ($newlevch = array_shift($keyarr)) {
   $newlev = round($newlevch / 10);
   $newchecked = $newlevch % 10;
   $newhidden = array_shift($keyarr);
   $newid = array_shift($keyarr);
   $newname = array_shift($keyarr);
   if ($hidelevel == 0 && $newhidden == 1) {
      $hidelevel = $newlev;
   }
   if ($hidelevel > 0 && $newlev < $hidelevel) {
      $hidelevel = 0;
   }
   if ($hidelevel == 0 || $newlev < $hidelevel) {
      $btext = '+';
      if (array_key_exists(0,$keyarr)) {
         $nextlev = round($keyarr[0] / 10);
         if ($nextlev > $newlev && $keyarr[1] == 0) {
            $btext = '-';
         }
      }
      if ($newchecked == 1) {
         $checked = ' CHECKED';
      } else {
         $checked = '';
      }
      if (isset($mmSelectedNum) && $mmSelectedNum == $newid) {
         echo '<a name="current"></a>';
      }
      if ($newlev < 99) {
#
# Check forward in the $keyarr array to see if the next node is just an isolated level=99 node
# where the name ends with "HIDDEN". In that case, it should not be possible to expand to this
# level: Disable the [+] button.
#
         $isolated_hidden = 0;
         if (count($keyarr) >= 4) {
            if ($keyarr[0] >= 990 && preg_match ('/ HIDDEN$/',$keyarr[3])) {
               if (count($keyarr) == 4 || $keyarr[4] < 990) {
                  $isolated_hidden = 1;
               }
            }
         }
         if ($isolated_hidden == 0) {
            echo '<input class="hkplusminus" type="submit" style="margin-left: ' . 20*$newlev . 'px" ' .
                 'name="mmSubmitButton_hk' . $newid . '_' . $mmCategoryNum . '" value="' .
                 $btext . '" />' . "\n";
         } else {
            echo '<input class="hkplusminus" type="submit" disabled style="margin-left: ' .
                 20*$newlev . 'px; background: #d2f2f4" ' .
                 'name="mmSubmitButton_hk' . $newid . '_' . $mmCategoryNum . '" value=" " />' . "\n";
         }
         echo '<input type="checkbox" name="' . $name1 . '_hk' . $newid . 
              '" value="' .  $newid . '"' . $checked . '/>';
         echo '<span class="hkkeyword">' .$newname . '</span><br />' . "\n";
         $level = $newlev;
      } else if (! preg_match ('/ HIDDEN$/',$newname)) {
         $margin = 20*($level + 2);
         echo '<input type="checkbox" name="' . $name1 . '_' . $newid . 
              '" style="margin-left: ' . $margin . 'px" value="' .
              $newid . '"' . $checked . '/>' . 
              '<span class="checkboxtext">' . $newname . '</span><br />' . "\n";
      }
   }
}
?>
   </td></tr>

</table>
</form>
