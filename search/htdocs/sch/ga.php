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
         $imgSrc = mmGetGAImageSrc($mmCategoryNum);
         if (strlen($imgSrc)) {
            echo '<input type="image" src="' . $imgSrc . '" height="560" width="560" name="gacoord" align="left" />';
         }
      ?>
      </p><p><a name="gaform">&nbsp;</a>
      </p>
   </td></tr>
</table>
</form>
<form action="gaget.php#gaform" method="POST">

<?php
  $srids = preg_split('/\s+/', $mmConfig->getVar('SRID_ID_COLUMNS'));
  if (count($srids) > 1) {
     echo mmHiddenSessionField();
     $name = mmGetCategoryFncValue($mmCategoryNum,"name");
?>
<table border="0" cellspacing="5" class="orange" width="100%">
   <tr><td>
<?php
     echo("Select another area: <select name=\"gamap_srid\" size=\"1\"><option selected=\"selected\">$srids[0]</option>");
        array_shift($srids); # remove first element
        foreach ( $srids as $srid ) {
           echo "<option value=\"$srid\">$srid</option>";
        }
        echo("</select>\n");
     echo (mmSelectbutton($mmCategoryNum,"gaget","Switch Map"));
?>
   </td></tr>
</table>
</form>
<?php
  }
?>  