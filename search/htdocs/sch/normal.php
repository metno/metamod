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
    if ($mmError > 0) {
#
# If this file is included when an error condition exists ($mmError > 0)
# then all previous output have been wiped out. Concequently, the file header
# etc. must be output once again.
#
?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
   <title>[==SEARCH_APP_TITLE==]</title>
   <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
   <link href="style.css" rel="stylesheet" type="text/css" />
   <link href="[==LOCAL_URL==]/style.css" rel="stylesheet" type="text/css" />
</head>
<body>
<?php
    }
?>
<div class="mybody">
   [==SEARCH_APP_HEADER_HTML==]
   <table class="main_structure" cellpadding="0" cellspacing="0">
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
            <br />
         </td>
         <td class="heading_and_logo">
            <table cellpadding="0" cellspacing="0">
               <tr>
                  <td>
                     <p class="heading">[==SEARCH_APP_TITLE==]</p>
                     <p class="heading_info">[==SEARCH_APP_DESCRIPTION==]
                     </p>
                     <?php
                        if ($mmError > 0) {
                           echo '<p class="note">' . $mmErrorMessage . "</p>\n";
                        }
                     ?>
                     <!--PLACE HOLDER FOR ERROR MESSAGE-->
                  </td>
               </tr>
            </table>
         </td>
      </tr>
      <tr>
         <td>&nbsp;
         </td>
         <td>
            <table cellspacing="0"><tr>
               <td class="om_item"><?php echo mmAnchor("show.php","Show results","oper") ."\n" ?></td>
               <td>&nbsp;</td>
               <td class="om_item"><?php echo mmAnchor("cross.php","Two-way tables","oper") ."\n" ?></td>
               <td>&nbsp;</td>
               <td class="om_item"><?php echo mmAnchor("options.php","Options","oper") ."\n" ?></td>
               <td>&nbsp;</td>
               <td class="om_item"><?php echo mmAnchor("help.php","Help","oper") ."\n" ?></td>
            </tr></table>
         </td>
      </tr>
      <tr>
         <td>
            <?php
               if (isset($mmCategorytype)) {
                  reset($mmCategorytype);
                  foreach (array([==SEARCH_CATEGORY_SEQUENCE==]) as $category) {
                     $type = $mmCategorytype[$category];
                     if ($type == 1) {
                        if (mmGetCategoryFncValue($category,"status") != "hidden") {
                           mmShowSelectedBK($category);
                        }
                     } else if ($type == 2) {
                        mmShowSelectedHK($category);
                     } else if ($type == 3) {
                        mmShowSelectedNI($category);
                     } else if ($type == 4) {
                        mmShowSelectedGA($category);
                     }
                  }
               }
            ?>
         </td>
         <td>
            <?php
               if ($mmError > 0) {
#
#  Force the index file to be output if an error condition exists:
#
                  $mmButtonName = "index";
               }
               if (array_key_exists($mmButtonName, $mmButtons)) {
                  $fname = $mmButtons[$mmButtonName][1];
                  if ($fname == "current") {
                     $fname = $mmSessionState->state;
                  }
                  if (file_exists($fname)) {
                     include $fname;
                  } else {
                     include "presentation.php";
                  }
               } else {
                  mmPutLog(__FILE__ . __LINE__ . " No such button: $mmButtonName");
                  $mmErrorMessage = $msg_start . "Internal application error";
                  $mmError = 1;
               }
            ?>
         </td>
      </tr>
   </table>
   [==APP_FOOTER_HTML==]
</div>
<?php
    if ($mmError > 0) {
?>
</body>
</html>
<?php
    }
?>
