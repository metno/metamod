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
[==APP_HEADER_HTML==]
   <table class="main_structure" cellpadding="0" cellspacing="0" width="100%">
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
                     echo '<p class="xmm_item">' . $a2[2] . "</p>\n";
                  }
               }
            ?>
            <p>&nbsp;</p>
            <?php
               echo '<a class="mm_item" href="adm.php?sessioncode=' .
                  $sessioncode . '&normemail=' . $normemail . '">Administration</a>' . "\n";
               echo '<a class="mm_item" href="upload.php?sessioncode=' .
                  $sessioncode . '&normemail=' . $normemail . '">Upload files</a>' . "\n";
            ?>
            <p class="xmm_item">Test a file</p>
            <?php
               echo '<a class="mm_item" href="start.php?sessioncode=' .
                  $sessioncode . '&normemail=' . $normemail . '">Log out</a>' . "\n";
            ?>
         </td>
         <td class="heading_and_logo">
            <table cellpadding="0" cellspacing="0" width="100%">
               <tr>
                  <td>
                     <p class="heading">[==UPLOAD_APP_TITLE==]</p>
                     <p class="heading_info">
[==UPLOAD_APP_INLOGGED_TEXT==]
<br /><br />
[==UPLOAD_APP_COMMON_TEXT==]
                     </p>
                     <?php
                        if (strlen($errmsg) > 0) {
                           echo '<p class="note">' . $errmsg . '</p>' . "\n";
                        }
                     ?>
                  </td>
               </tr>
            </table>
         </td>
      </tr>
      <tr>
         <td colspan="2">
   <div class="loginform" style="border-left: 1px solid #4d4d8d;">
   <h3>Test a file</h3>
   <p>Use the "File name" entry or the "Browse..." button below to enter the name of
   a file on your local file system that you want to test against the requirements for 
   this data repository.</p>
   <p>The file should be a netCDF file or a CDL file (the text version of a netCDF file).</p>
   <p><b><i>Note</i></b>:The file will not be sent to the data repository. If you
   want to upload a file to the repository, use the 
   <?php
      echo '<a href="upload.php?sessioncode=' .
         $sessioncode . '&normemail=' . $normemail . '">Upload file</a>' . "\n";
   ?>
   page.</p>
   <p><b><i>Note</i></b>: Files to be tested must not exceed a size limit of
   <?php $maxsize = [==MAX_UPLOAD_SIZE_BYTES==]/1000000; echo $maxsize; ?>
   MB.</p>
   <p>Only alphanumeric characters, underline (_), period (.) and hyphens (-)
   are allowed in file names. The initial part of a file name must be the name of a
   user directory followed by underline (_).
   The user directory need not exist in the repository.</p>
   <form enctype="multipart/form-data" action="main.php" method="post">
   <p>
      <input type="hidden" name="MAX_FILE_SIZE" value="[==MAX_UPLOAD_SIZE_BYTES==]" />
      <?php
         echo '<input type="hidden" name="normemail" value="' . $normemail . '" />' . "\n";
         echo '<input type="hidden" name="sessioncode" value="' . $sessioncode . '" />' . "\n";
      ?>
      File name: <input name="fileinfo" type="file" />
      <input class="selectbutton1" type="submit" name="BTN_filetest" value="Upload test file" />
   </p>
   </form>
   </div>
         </td>
      </tr>
   </table>
[==APP_FOOTER_HTML==]
</div>
</body>
</html>
