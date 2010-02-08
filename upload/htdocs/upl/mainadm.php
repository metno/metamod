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
<?php 
   echo $mmConfig->getVar('APP_HEADER_HTML');
   $external_repository = (strtolower($mmConfig->getVar('EXTERNAL_REPOSITORY')) == "true");
?>
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
         if ($external_repository) {
            $files_text = "Files";
         } else {
            $files_text = "Upload Files";
         }
         echo '<a class="mm_item" href="upload.php?sessioncode=' .
            $sessioncode . '&normemail=' . $normemail . '">' . $files_text . '</a>' . "\n";
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
            <p class="heading"><?php echo $mmConfig->getVar('UPLOAD_APP_TITLE'); ?></p>
            <p class="heading_info">
<?php echo $mmConfig->getVar('UPLOAD_APP_INLOGGED_TEXT'); ?>
<br /><br />
<?php echo $mmConfig->getVar('UPLOAD_APP_COMMON_TEXT'); ?>
            </p>
            <?php
               if (strlen($errmsg) > 0) {
                  if ($error == 0) {
                     echo '<p class="notegreen">' . $errmsg . '</p>' . "\n";
                  } else {
                     echo '<p class="note">' . $errmsg . '</p>' . "\n";
                  }
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
         <td rowspan="6">
            <?php 
            if ($external_repository) {
            echo '<p>In this page you can enter access information for directories in an external
            repository. The information will be used to harvest metadata from new files in the
            directory and to create links from the search page to the actual data.</p>
            <p>To register a new directory, fill in the directory name and the access information
            fields (directory key, location and catalog URL). All these fields are mandatory.
            Then click the CREATE/UPDATE button. Some restrictions exist on the format of the
            fields. If they are not accepted, you will be informed by a message box.</p>
            <p>You may change the information about directories that already have been registered.
            Select the directory name in the selection box at the right hand side, or type in
            the name in the Directory name field. Then click the RETRIEVE button. All information
            previously entered will be shown, and may be changed. After editing the fields, click
            the CREATE/UPDATE button.</p>
            <p>The CANCEL button clears the fields, and makes the selection box again available for
            new retrievals.</p>
            <p>Note that changing access information for directories with files already parsed
            into the database, will not change links to these older files. Only new files will
            be affected.</p>';
            } else {
            echo '<p>In this page you can create new directories in the data repository and
            control who are allowed to upload files to your directories.
            </p>
            <p>To create a new directory, fill in the directory
            name and optionally the directory key. Then click the CREATE/UPDATE
            button. Only alphanumeric characters or "." or "-" (hyphen) are allowed in directory
            names.</p>
            <p>To change the directory key for an existing directory, select the directory name in
            the selection box at the right hand side, or enter the directory name in the "Directory name"
            field. Then click the RETRIEVE button. You will then get this page again with the directory 
            name and directory key filled in. Make your changes and click the CREATE/UPDATE button to
            save them on the server.</p>
            <p>The CANCEL button clears the fields, and makes the selection box again available for
            new retrievals.</p>
            <p>
            The directory key may be provided if you want other users to upload files
            to the directory.
            All these users must use the same key. It is your responsibility to communicate the
            key to users that you think will need it. You may change the key at any time to
            regain control over who have access to the directory. If you are the only user of this
            directory, you may leave the key field empty. Note that the key is only for write
            access to the directory. <i>Read access for uploaded files are regulated by metadata
            inside each file.</i></p>';
            }
            ?>
         </td>
         <td rowspan="6">
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
                if (strlen($dirname) == 0) {
         		   $dirinfo_sorted = ksort($dirinfo);
         		   foreach ( $dirinfo as $di => $ki ) {
       				   echo("<option>$di</option>");
				   }         		
                } else {
                   echo "<option></option>";
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
            <input class="selectbutton1" type="submit" name="BTN_cancel_dir" value="Cancel" />
         </td>
         <?php
         if (strlen($mmConfig->getVar("FIMEX_PROGRAM"))) {
         	echo '<td class="inputform">
            <input class="selectbutton1" type="submit" name="BTN_editproj_dir" value="Edit Projections" />
         </td>
';
         } else {
         	echo '<td class="inputform" />'."\n";
         }
         if (strlen($mmConfig->getVar("WMS_URL"))) {
				echo '<td class="inputform">
            <input class="selectbutton1" type="submit" name="BTN_editWMS_dir" value="Edit WMS parameter" />
         </td>
';
         } else {
         	echo '<td class="inputform" />'."\n";
         }
         ?>
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
         <?php
            if (strtolower($mmConfig->getVar("EXTERNAL_REPOSITORY")) == "true") {
               echo '
         <tr>
         <td class="inputform">
            &nbsp;Dataset location:<br />&nbsp;(absolute directory path)
         </td>
         <td class="inputform" colspan="3">
            <input name="location" value="' . $location . '" size="30" />
         </td>
         </tr>
         <tr>
         <td class="inputform">
            &nbsp;Dataset catalog:<br />&nbsp;(THREDDS URL)
         </td>
         <td class="inputform" colspan="3">
            <input name="threddscatalog" value="' . $threddscatalog . '" size="30" />
         </td>
         </tr>
';
            } else {
         	   echo '<tr rowspan="2"><td class="inputform" colspan="4" /></tr>'."\n";
            }
         ?>
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
