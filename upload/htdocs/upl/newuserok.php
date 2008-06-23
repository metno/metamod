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
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
   <title>[==UPLOAD_APP_TITLE==]</title>
   <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
   <link href="[==LOCAL_URL==]/style.css" rel="stylesheet" type="text/css" />
   <link href="style.css" rel="stylesheet" type="text/css" />
</head>
<body>
<div class="mybody">
   <a href="http://www.damocles-eu.org/">
      <img src="[==LOCAL_URL==]/img/damocles-header.gif" style="clear:left;border: none;" />
   </a>
   <table class="main_structure" cellpadding="0" cellspacing="0">
      <col width="10%" />
      <col width="90%" />
      <tr>
         <td class="main_menu">
            <?php
               $s1 = <<<END_OF_STRING
[==APP_MENU==]
END_OF_STRING;
               $a1 = explode("\n",$s1);
               foreach ($a1 as $s2) {
                  if (preg_match ('/^ *([^ ]+) (.*)$/i',$s2,$a2)) {
                     echo '<a class="mm_item" href="' . $a2[1] . '">' . $a2[2] . "</a>\n";
                  }
               }
            ?>
         </td>
         <td class="heading_and_logo">
            <table cellpadding="0" cellspacing="0">
               <tr>
                  <td>
                     <p class="heading">[==UPLOAD_APP_TITLE==]</p>
                  </td>
               </tr>
            </table>
         </td>
      </tr>
      <tr>
         <td style="border-right: 1px solid #4d4d8d; border-bottom: 1px solid #4d4d8d">&nbsp;</td>
         <td>
   <table border="0" cellspacing="0" width="100%">
      <tr>
         <td class="loginform">
            <center>
            <h3>Thank you for your user account application</h3>
            <p>If accepted, you will receive an E-mail with a password for logging into
            the upload service for the [==APPLICATION_NAME==] file repository. 
            </center>
         </td>
      </tr>
   </table>
         </td>
      </tr>
   </table>
[==APP_FOOTER_HTML==]
</div>
</body>
</html>
