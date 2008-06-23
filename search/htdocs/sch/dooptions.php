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
$maxcol = [==SEARCH_APP_MAX_COLUMNS==];
$totalcol = $maxcol+4;
?>
<form action="search.php" method="POST">
<table class="orange" cellspacing="5">
   <tr><td colspan="<?php echo $totalcol; ?>"><center>
      <table border="0" cellspacing="0" cellpadding="0"><tr>
         <td>
            <?php echo mmHiddenSessionField(); ?>
            <input type="hidden" name="mmSubmitButton" value="optsdone" />
            <input class="selectbutton" type="submit" name="update" value="Update options" />
         </td>
         <td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>
         <td><input class="selectbutton" type="submit" name="defaults" value="Set defaults" /></td>
         <td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>
         <td><input class="selectbutton" type="submit" name="cancel" value="Cancel" /></td>
      </tr></table>
   </center></td></tr>
   <tr><td colspan="<?php echo $totalcol; ?>">
<p>Select the metadata to be shown as columns in the "Show results" page by checking
radiobuttons in the table below. The columns in this page are numbered from 1 to
[==SEARCH_APP_MAX_COLUMNS==]. By checking a radio button corresponding to a given
metadata category (in the first table column), metadata from this category will be
shown in the selected page column. Checking a radiobutton in the last table row
(the "Not to be used" row), will hide the corresponding page column, and thereby reduce
the number of page columns shown.</p>
<p>You may also select the metadata to be used as labels along the vertical and horisontal
axis in a two-way table. The cells in such a table show the number of datasets matching
the metadata items corresponding to both the vertical and horisontal label.</p>
   </td></tr>
<?php
echo "<tr>\n";
echo "   <th>&nbsp;</th>\n";
echo '   <th colspan="' . $maxcol . '">Column number</th>' . "\n";
echo '   <th>&nbsp;</th>' . "\n";
echo '   <th colspan="2">Crosstable columns</th>' . "\n";
echo "</tr>\n";
echo "<tr>\n";
echo "   <th>Column names</th>\n";
for ($i1 = 1; $i1 <= $maxcol; $i1++) {
   echo "   <th>" . $i1 . "</th>\n";
}
echo '   <th>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</th>' . "\n";
echo '   <th>Vertical</th>' . "\n";
echo '   <th>Horisontal</th>' . "\n";
echo "</tr>\n";
$selected = array();
$cselected = array();
foreach ($mmColumns as $col) {
   $selectcol = 0;
   $selectcross = "x";
   reset($mmSessionState->options);
   foreach ($mmSessionState->options as $opt => $mtname) {
      if ($col[0] == $mtname) {
         if (substr($opt,0,4) == 'col=') {
            $selectcol = substr($opt,4);
            $selected[$selectcol] = 1;
         }
         if (substr($opt,0,6) == 'cross=') {
            $selectcross = substr($opt,6);
            $cselected[$selectcross] = 1;
         }
      }
   }
   echo "<tr>\n";
   echo "   <td>" . $col[1] . ":</td>\n";
   for ($i1 = 1; $i1 <= $maxcol; $i1++) {
      if ($selectcol == $i1) {
         $checked = "CHECKED ";
      } else {
         $checked = "";
      }
      echo '   <td><input type="radio" name="' . $i1 . '" value="' . $col[0] .
           '" ' . $checked . "/>\n";
   }
   echo "   <td>&nbsp;</td>\n";
   $h_checked = "";
   $v_checked = "";
   if ($selectcross == "h") {
      $h_checked = "CHECKED ";
   } elseif ($selectcross == "v") {
      $v_checked = "CHECKED ";
   }
   if (in_array("cross=no", $col)) {
      echo "   <td>&nbsp;</td>\n";
      echo "   <td>&nbsp;</td>\n";
   } else {
      echo '   <td><input type="radio" name="v" value="' . $col[0] .
           '" ' . $v_checked . "/>\n";
      echo '   <td><input type="radio" name="h" value="' . $col[0] .
           '" ' . $h_checked . "/>\n";
   }
   echo "</tr>\n";
}
echo "<tr>\n";
$j1 = $maxcol + 4;
echo '   <th colspan="' . $j1 . '">&nbsp;</th>' . "\n";
echo "</tr>\n";
echo "<tr>\n";
echo "   <td>Not to be used:</td>\n";
for ($i1 = 1; $i1 <= $maxcol; $i1++) {
   if (array_key_exists($i1,$selected)) {
      $checked = "";
   } else {
      $checked = "CHECKED ";
   }
   echo '   <td><input type="radio" name="' . $i1 . '" value="notused" ' . $checked . "/>\n";
}
echo "   <td>&nbsp;</td>\n";
$h_checked = "CHECKED ";
$v_checked = "CHECKED ";
if (array_key_exists("v",$cselected)) {
   $v_checked = "";
}
if (array_key_exists("h",$cselected)) {
   $h_checked = "";
}
echo '   <td><input type="radio" name="v" value="notused" ' . $v_checked . "/>\n";
echo '   <td><input type="radio" name="h" value="notused" ' . $h_checked . "/>\n";
echo "</tr>\n";
$fontsize = [==DEFAULT_FONTSIZE==];
if (array_key_exists("fontsize",$mmSessionState->options)) {
   $fontsize = $mmSessionState->options["fontsize"];
}
$j1 = $maxcol + 4;
echo '<tr><td colspan="' . $j1 . '">' . "\n";
echo '<p>Set the relative font size to be used in the result page and the two-way tables: ' . "\n";
echo '<input type="text" size="4" name="fontsize" value="' . $fontsize . '" /> %</p>' ."\n";
echo "</td></tr>\n";
?>
</table>
</form>
