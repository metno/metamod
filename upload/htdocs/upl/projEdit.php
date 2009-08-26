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
// must be called from main.php and via BTN_editproj_dir, to set variables $projDataset and $projDatasetFile
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
      <h2>Projection Administration of Dataset <?php $directory ?></h2>
      <table border="0" cellspacing="0" cellpadding="4">
         <colgroup width="100%" />
         <tr>
         <td>
            <p>In this page you can create/edit the reprojection download options for all your data in the
            directory <?php $directory ?>. This facility will only work with netcdf files in CF-1.x convention.
            The reprojection will only work with freely available dataset, restricted dataset cannot be retrieve by this options yet.
            </p>
            <p>The setup will be uploaded within the next 10 minutes. <b>Please test your setup!</b></p>
            <p>Simply edit/add a setup according the example below:</p>
            <pre>
<?php $input = <<<EOT
<fimexProjections xmlns="http://www.met.no/schema/metamod/fimexProjections"
                  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                  xsi:schemaLocation="http://www.met.no/schema/metamod/fimexProjections https://wiki.met.no/_media/metamod/fimexProjections.xsd">
<dataset urlRegex="!(.*/thredds).*dataset=(.*)!" urlReplace="$1/fileServer/data/$2"/>
<!-- see fimex-interpolation for more info on options -->
<projection name="Lat/Long" method="nearestneighbor" 
            projString="+proj=latlong +a=6371000 +ellps=sphere +e=0" 
            xAxis="-180,-179,...,180" 
            yAxis="60,61,...,90" 
            toDegree="true"/>
<projection name="Stereo" method="bilinear"
            projString="+proj=stere +lon_0=0 +lat_0=90 +lat_ts=-32 +a=6371000 +ellps=sphere +e=0" 
            xAxis="0,50000,...,x;relativeStart=0" 
            yAxis="0,50000,...,x;relativeStart=0" 
            toDegree="false" /> 
</fimexProjections>
EOT;
echo htmlentities($input);
?>
            </pre>
         </td>
			</tr>
			<tr>
         <td class="inputform">
         	<?php if ($error > 0) {$projectionInfo = $projectionInput;} else {$projectionInfo = $projDataset->getProjectionInfo();} ?>
            <textarea name="projectionInfo" cols="80" rows="25"><?php echo htmlentities($projectionInfo) ?></textarea>
  				<input type="hidden" name="dirname" value="<?php echo $directory ?>" />
   			<input type="hidden" name="dirkey" value="<?php echo $dirkey ?>" />
         </td>
         </tr>
         <tr>
         <td class="inputform">
            <table><tr>
            	<td><input class="selectbutton1" type="reset" /></td>
               <td><input class="selectbutton1" type="submit" name="BTN_adm" value="Cancel" /></td>
            	<td><input class="selectbutton1" type="submit" name="BTN_writeproj_dir" value="Apply" /></td>
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
