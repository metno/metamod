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
<form action="search.php" method="POST">
<?php
   echo mmHiddenSessionField();
   $name = mmGetCategoryFncValue($mmCategoryNum,"name");
?>
<table border="0" cellspacing="5" class="orange">
   <tr><td><center>
      <table border="0" cellspacing="0" cellpadding="20"><tr>
         <td><?php echo mmSelectbutton($mmCategoryNum,"bkdone","Select"); ?></td>
         <td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>
         <td><?php echo mmSelectbutton($mmCategoryNum,"bkclear","Clear All"); ?></td>
      </tr></table>
   </center></td></tr>
   <tr><td>
<?php
echo <<<END_TEXT
   <p>Mark one or more $name from the list below by checking the corresponding checkboxes.
   Then, click the "Select" button above.</p>
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
foreach (mmGetBK($mmCategoryNum) as $bkid => $bktext) {
   if (mmIsSelectedBK($mmCategoryNum,$bkid)) {
      $checked = ' CHECKED';
   } else {
      $checked = '';
   }
   $namex = str_replace(' ','',$name);
   echo "<input type=\"checkbox\" name=\"${namex}_${bkid}\" value=\"${bkid}\"${checked} />" .
      "<span class=\"checkboxtext\">${bktext}</span><br>\n";
}
?>
   </td></tr>

</table>
</form>
