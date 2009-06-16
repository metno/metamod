<?php 
#---------------------------------------------------------------------------- 
#  METAMOD - Web portal for metadata search and upload 
# 
#  Copyright (C) 2009 met.no 
# 
#  Contact information: 
#  Norwegian Meteorological Institute 
#  Box 43 Blindern 
#  0313 OSLO 
#  NORWAY 
#  email: heiko.klein@met.no
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
?>
<table border="0" cellspacing="5" class="orange">
   <tr><td><center>
      <table border="0" cellspacing="0" cellpadding="20"><tr>
         <td><?php echo mmSelectbutton("0","ftdone","OK"); ?></td>
         <td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>
         <td><?php echo mmSelectbutton("0","ftremove","Remove"); ?></td>
      </tr></table>
   </center></td></tr>
   <tr><td>
<?php
echo <<<END_TEXT
   <p>Enter a list of search words separated by spaces. 
END_TEXT;
echo <<<END_TEXT
   Then, click the "OK" button.</p>
   <p>Only data references matching all the entered search-terms will be selected.
   To accept all data-references, use an empty string, or click
   "Remove" button.
   </p>
END_TEXT;
?>
   </td></tr>
<?php
echo "<tr><td>\n";
echo  'Query-String: <input type="text" size="12" name="fullTextQuery" value="' . htmlspecialchars($mmSessionState->fullTextQuery) . '" />' ."\n";
echo "</td></tr>\n";
?>
</table>
</form>
