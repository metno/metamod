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
require_once("../funcs/mmConfig.inc");
?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
   <title><?php echo $mmConfig->getVar('UPLOAD_APP_TITLE'); ?></title>
   <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
   <link href="<?php echo $mmConfig->getVar('LOCAL_URL'); ?>/style.css" rel="stylesheet" type="text/css" />
   <link href="style.css" rel="stylesheet" type="text/css" />
</head>
<body>
<div class="mybody">
<?php echo $mmConfig->getVar('APP_HEADER_HTML'); ?>
<form action="main.php" method="post">
<?php
   echo '<input type="hidden" name="normemail" value="' . $normemail . '" />' . "\n";
   echo '<input type="hidden" name="sessioncode" value="' . $sessioncode . '" />' . "\n";
?>
<table class="main_structure" cellpadding="0" cellspacing="0" width="100%">
   <col width="10%" />
   <col width="90%" />
   <tr>
   <td class="main_menu">
      <?php
         $s1 = $mmConfig->getVar('APP_MENU');
         $a1 = explode("\n",$s1);
         foreach ($a1 as $s2) {
            if (preg_match ('/^ *([^ ]+) (.*)$/i',$s2,$a2)) {
               echo '<p class="xmm_item">' . $a2[2] . "</p>\n";
            }
         }
      ?>
      <p>&nbsp;</p>
      <p class="xmm_item">Administration</p>
      <?php
         echo '<a class="mm_item" href="upload.php?sessioncode=' .
            $sessioncode . '&normemail=' . $normemail . '">Upload Files</a>' . "\n";
         echo '<a class="mm_item" href="tfile.php?sessioncode=' .
            $sessioncode . '&normemail=' . $normemail . '">Test a file</a>' . "\n";
         echo '<a class="mm_item" href="start.php?sessioncode=' .
            $sessioncode . '&normemail=' . $normemail . '">Log out</a>' . "\n";
      ?>
   </td>
   <td class="heading_and_logo">
      <table cellpadding="0" cellspacing="0" width="100%">
         <tr>
         <td>
            <p class="heading"><?php $mmConfig->getVar('UPLOAD_APP_TITLE'); ?></p>
            <p class="heading_info">
<?php echo $mmConfig->getVar('UPLOAD_APP_INLOGGED_TEXT'); ?>
<br /><br />
<?php echo $mmConfig->getVar('UPLOAD_APP_COMMON_TEXT'); ?>
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
      <h2>Directory Administration</h2>
      <table border="0" cellspacing="0" cellpadding="4">
         <colgroup width="53%" />
         <colgroup width="3%" />
         <colgroup width="11%" />
         <colgroup width="11%" />
         <colgroup width="11%" />
         <colgroup width="11%" />
         <tr>
         <td rowspan="4">
            <p>In this page you can create new directories in the data repository and
            control who are allowed to upload files to your directories.
            </p>
            <p>To create a new directory, fill in the directory
            name and optionally the directory key. Then click the CREATE/UPDATE
            button. Only alphanumeric characters or '.' or '-' (hyphen) are allowed in directory
            names.</p>
            <p>To change the directory key for an existing directory, fill in the directory name
            and click the RETRIEVE button. Then you will get this page again with the directory name
            and directory key filled in. Make your changes and click the CREATE/UPDATE button to
            save them on the server. You may also change the directory name as long as no files
            have been uploaded to the directory.</p>
            <p>
            The directory key may be provided if you want other users to upload files
            to the directory.
            All these users must use the same key. It is your responsibility to communicate the
            key to users that you think will need it. You may change the key at any time to
            regain control over who have access to the directory. If you are the only user of this
            directory, you may leave the key field empty. Note that the key is only for write
            access to the directory. <i>Read access for uploaded files are regulated by metadata
            inside each file.</i></p>
         </td>
         <td rowspan="4">
            &nbsp;
         </td>
         <td class="inputform">
            &nbsp;<b>Directory name:</b><br />&nbsp;(max <?php echo $mmConfig->getVar('MAXLENGTH_DIRNAME'); ?> characters)
         </td>
         <td class="inputform">
            <input name="dirname" value="<?php echo $dirname; ?>" size="10" />
         </td>
         <td class="inputform" colspan="2">
         	<select name="knownDirname" size="1">
         	<?php
         		$dirinfo_sorted = ksort($dirinfo);
         		foreach ( $dirinfo as $di => $ki ) {
       				echo("<option>$di</option>");
					}         		
         	?>
         	</select>
         </td>
         </tr>
         <tr>
         <td class="inputform">
            <input class="selectbutton1" type="submit" name="BTN_retr_dir" value="Retrieve" />
         </td>
         <td class="inputform">
            <input class="selectbutton1" type="submit" name="BTN_creupd_dir" value="Create/Update" />
         </td>
         <td class="inputform">
            <input class="selectbutton1" type="submit" name="BTN_editproj_dir" value="Edit Projections" />
         </td>
         <td class="inputform">
            <input class="selectbutton1" type="submit" name="BTN_editWMS_dir" value="Edit WMS parameter" />
         </td>
         </tr>
         <tr>
         <td class="inputform" colspan="4">
            <p>&nbsp;</p>
            <p>&nbsp;</p>
            <p>&nbsp;</p>
         </td>
         </tr>
         <tr>
         <td class="inputform">
            &nbsp;Directory key:<br />&nbsp;(max 10 characters):
         </td>
         <td class="inputform">
            <input name="dirkey" value="<?php echo $dirkey; ?>" size="10" />
         </td>
         <td class="inputform"/>
         <td class="inputform"/>
         </tr>
      </table>
      </div>
   </td>
   </tr>
</table>
</form>
<?php echo $mmConfig->getVar('APP_FOOTER_HTML'); ?>
</div>
</body>
</html>
