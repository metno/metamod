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
   <title>[==APPLICATION_NAME==]: [==UPLOAD_APP_TITLE==]</title>
   <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
   <link href="[==LOCAL_URL==]/style.css" rel="stylesheet" type="text/css" />
   <link href="style.css" rel="stylesheet" type="text/css" />
</head>
<body>
<div class="mybody">
[==APP_HEADER_HTML==]
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
                     <p class="heading_info">
[==UPLOAD_APP_LOGIN_TEXT==]
<br /><br />
[==UPLOAD_APP_COMMON_TEXT==]
                     </p>
                     <?php
                        if ($errmsg != "") {
                           echo '<p class="note">' . $errmsg . '</p>';
                        }
                     ?>
                  </td>
               </tr>
            </table>
         </td>
      </tr>
      <tr>
         <td colspan="2" style="border-left: 1px solid #4d4d8d">
   <table border="0" cellspacing="0" width="100%">
      <colgroup width="40%" />
      <colgroup width="60%" />
      <tr>
         <td class="loginform">
            <center>
            <h3>Registered users</h3>
            <form action="main.php" method="post">
            <table>
               <tr valign="top">
                 <td>Your E-mail address:</td>
                 <td><input type="text" name="email" /></td>
               </tr>
               <tr valign="top">
                 <td>Password:</td>
                 <td><input type="password" name="paw" /></td>
               </tr>
               <tr valign="top"><td colspan="2">&nbsp;</td></tr>
               <tr valign="top">
                  <td colspan="2">
                     <input type="checkbox" name="changepaw" value="1" />I want to change my password:
                  </td>
               </tr>
               <tr valign="top"><td colspan="2">&nbsp;</td></tr>
               <tr valign="top">
                 <td>New password:</td>
                 <td><input type="password" name="pawnew1" /></td>
               </tr>
               <tr valign="top">
                 <td>Repeat new password:</td>
                 <td><input type="password" name="pawnew2" /></td>
               </tr>
               <tr valign="top"><td colspan="2">&nbsp;</td></tr>
               <tr valign="top">
                 <td colspan="2" align="center">
                   <input type="hidden" name="action" value="started" />
                   <input class="selectbutton1" type="submit" name="BTN_login" value="Log in" />
                 </td>
               </tr>
            </table>
            </form>
            </center>
         </td>
         <td class="loginform">
            <center>
            <h3>New users</h3>
            <p>(also to be used by registered users who can not remember the password)</p>
            <form action="newuser.php" method="post">
            <table>
               <colgroup width="40%" />
               <colgroup width="60%" />
               <tr valign="top">
                 <td>Name:</td>
                 <td><input type="text" size="34" name="name" /></td>
               </tr>
               <tr valign="top">
                 <td>Your E-mail address:</td>
                 <td><input type="text" size="34" name="email" /></td>
               </tr>
               <tr valign="top">
                 <td colspan="2">Name of institution:</td>
               </tr>
               <tr valign="top">
                 <td colspan="2">
                   <select name="institution">
                     <option selected value="">Select ...</option>
            <?php
               $s1 = <<<END_OF_STRING
[==INSTITUTION_LIST==]
END_OF_STRING;
               $a1 = explode("\n",$s1);
               foreach ($a1 as $s2) {
                  if (preg_match ('/^ *([^ ]+) (.*)$/i',$s2,$a2)) {
                     echo '<option value="' . $a2[1] . '">' . $a2[2] . "</option>\n";
                  }
               }
            ?>
                   </select>
                 </td>
               </tr>
               <tr valign="top"><td colspan="2">&nbsp;</td></tr>
               <tr valign="top">
                 <td>Telephone number:</td>
                 <td><input type="text" size="34" name="telephone" /></td>
               </tr>
               <tr valign="top"><td colspan="2">&nbsp;</td></tr>
               <tr valign="top">
                 <td colspan="2" align="center">
                   <input type="hidden" name="action" value="started" />
                   <input class="selectbutton1" type="submit" name="BTN_send" value="Send form" />
                 </td>
               </tr>
               <tr valign="top">
                 <td colspan="2"><p>You will recieve an E-mail with your password.
                    If we already have your E-mail address in our files, this will be done
                    automatically, and should not take much time. 
                    For completely new users, this may take a few days.</p>
                 </td>
               </tr>
            </table>
            </form>
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
