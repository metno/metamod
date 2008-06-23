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
   $lower = mmGetCategoryFncValue($mmCategoryNum,"lower");
   $upper = mmGetCategoryFncValue($mmCategoryNum,"upper");
   $numtype = mmGetCategoryFncValue($mmCategoryNum,"numtype");
?>
<table border="0" cellspacing="5" class="orange">
   <tr><td><center>
      <table border="0" cellspacing="0" cellpadding="20"><tr>
         <td><?php echo mmSelectbutton($mmCategoryNum,"nidone","OK"); ?></td>
         <td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>
         <td><?php echo mmSelectbutton($mmCategoryNum,"niremove","Remove"); ?></td>
      </tr></table>
   </center></td></tr>
   <tr><td>
<?php
echo <<<END_TEXT
   <p>Enter the $name to search for by filling in the $lower and $upper fields below.
END_TEXT;
if ($numtype == "date") {
   echo "In each field, use the date format \"YYYY-MM-DD\". Just \"YYYY\" or \"YYYY-MM\"\n";
   echo "will also be understood.\n";
}
echo <<<END_TEXT
   Then, click the "OK" button.</p>
   <p>Only data references having a $name overlapping the interval thus defined, will be selected.
   To accept any $name, i.e. not filter the data references against any $name at all, click the
   "Remove" button.
   </p>
END_TEXT;
?>
   </td></tr>
<?php
$nitextarr = mmGetSelectedNI($mmCategoryNum,$numtype);
if (count($nitextarr) > 0) {
   $fromto = explode(" to ",$nitextarr[0]);
} else {
   $fromto = array('','');
}
echo "<tr><td>\n";
echo $lower . ': <input type="text" size="12" name="from" value="' . $fromto[0] . '" />' ."\n";
echo "&nbsp;&nbsp;&nbsp;&nbsp;\n";
echo $upper . ': <input type="text" size="12" name="to" value="' . $fromto[1] . '" />' ."\n";
echo "</td></tr>\n";
?>
</table>
</form>
