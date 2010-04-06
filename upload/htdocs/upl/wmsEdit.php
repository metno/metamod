<?php
/*
 * Created on Jul 20, 2009
 *
 *---------------------------------------------------------------------------- 
 * METAMOD - Web portal for metadata search and upload 
 *
 * Copyright (C) 2009 met.no 
 *
 * Contact information: 
 * Norwegian Meteorological Institute 
 * Box 43 Blindern 
 * 0313 OSLO 
 * NORWAY 
 * email: heiko.klein@met.no 
 *  
 * This file is part of METAMOD 
 *
 * METAMOD is free software; you can redistribute it and/or modify 
 * it under the terms of the GNU General Public License as published by 
 * the Free Software Foundation; either version 2 of the License, or 
 * (at your option) any later version. 
 *
 * METAMOD is distributed in the hope that it will be useful, 
 * but WITHOUT ANY WARRANTY; without even the implied warranty of 
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the 
 * GNU General Public License for more details. 
 *  
 * You should have received a copy of the GNU General Public License 
 * along with METAMOD; if not, write to the Free Software 
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA 
 *--------------------------------------------------------------------------- 
 */
require_once("../funcs/mmConfig.inc");
// must be called from main.php and via BTN_editwms_dir, to set variables $wmsDataset and $wmsDatasetFile
?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
   <title><?php echo $mmConfig->getVar('UPLOAD_APP_TITLE'); ?></title>
   <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
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
      <h2>WMS Administration of Dataset <?php $directory ?></h2>
      <table border="0" cellspacing="0" cellpadding="4">
         <colgroup width="100%" />
         <tr>
         <td>
            <p>In this page you can create/edit the WMS download options for all your data in the
            directory <?php $directory ?>.
            </p>
            <p>
            <b>You will need to have made a working DIANA setup on the
            diana-WMS server</b>.  
            </p>
            <p>The setup will be uploaded within the next 10 minutes. <b>Please test your setup!</b></p>
            <p>Simply edit/add a setup according the example below. The most important parameters are the url in the begining 
            (using the DATASET_PARENT and DATASET), and the displayArea (EPSG:32661 (northpole), EPSG:32761 (southpole) and EPSG:4326 (lat/lon))
				The layer/palette setup is optional.
            <pre>
<?php $input = <<<EOT
<?xml version="1.0" encoding="UTF-8"?>
<w:ncWmsSetup url="http://dev-vm188/thredds/wms/osisaf/met.no/%DATASET_PARENT%/%DATASET%.nc"
          xmlns:w="http://www.met.no/schema/metamod/ncWmsSetup"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://www.met.no/schema/metamod/ncWmsSetup ncWmsSetup.xsd ">
          <w:displayArea crs="EPSG:32661" left="-3000000" right="7000000" bottom="-3000000" top="7000000"/>
          <w:layer name="ice_conc" style="BOXFILL/greyscale"/>
          <w:layer name="lat"/>
</w:ncWmsSetup>
EOT;
echo htmlentities($input);
?>
            </pre>
         </td>
			</tr>
			<tr>
         <td class="inputform">
         	<?php if ($error > 0) {$wmsInfo = $wmsInput;} else {$wmsInfo = $wmsDataset->getWMSInfo();} ?>
            <textarea name="wmsInfo" cols="120" rows="60"><?php echo htmlentities($wmsInfo) ?></textarea>
  				<input type="hidden" name="dirname" value="<?php echo $directory ?>" />
   			<input type="hidden" name="dirkey" value="<?php echo $dirkey ?>" />
         </td>
         </tr>
         <tr>
         <td class="inputform">
            <table><tr>
            	<td><input class="selectbutton1" type="reset" /></td>
               <td><input class="selectbutton1" type="submit" name="BTN_adm" value="Cancel" /></td>
            	<td><input class="selectbutton1" type="submit" name="BTN_writeWMS_dir" value="Apply" /></td>
            </tr></table>
         </td>
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
