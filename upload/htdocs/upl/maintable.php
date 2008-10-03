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
            ?>
            <p class="xmm_item">Upload files</p>
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
   <h3>Upload file</h3>
   <p>Use the "File name" entry or the "Browse..." button below to enter the name of
   a file on your local file system that you want to upload to the [==APPLICATION_NAME==] data repository.</p>
   <p>Normally, the file should be a netCDF file (or another format accepted in the repository).
   However, if you have a large number of small files, you may pack the files into an archive
   file. Then you upload the archive file</p>
   <p>The following archive formats are accepted:</p>
   <div align="center">
   <table bgcolor="white" cellspacing="0" cellpadding="8" border="1">
   <tr><th>Archive format</th><th>File extension</th></tr>
   <tr><td align="left">Tar</td><td align="left">.tar</td></tr>
   <tr><td align="left">Compressed tar (gzip)</td><td align="left">.tgz or .tar.gz</td></tr>
   </table>
   </div>
   <p>You may also re-upload a previously uploaded file. The files previously uploaded are
   shown in the table below. If the file to be uploaded should replace any of these files,
   please check the file name by using the radio button in the leftmost table column.</p>
   <p>Finally, push the "Upload" button to initiate the actual upload.</p>
   <p><b>Note:</b> Files to be uploaded must not exceed a size limit of
   <?php $maxsize = [==MAX_UPLOAD_SIZE_BYTES==]/1000000; echo $maxsize; ?>
   MB.
   Only alphanumeric characters, underline (_), period (.) and hyphens (-)
   are allowed in file names. The initial part of a file name must be the name of a
   user directory followed by underline (_).</p>
   <p>The following user directories are owned by you:
   &nbsp;&nbsp;
   <span class="dirlist">
    <?php
         $metadataQuest = "[==QUEST_METADATA_UPLOAD_FORM==]";
         $userinfo = get_userinfo($filepath);
    	 if (!array_key_exists("institution",$userinfo)) {
       		$error = 2;
       		$nextpage = 1;
       		mmPutLog('No institution in userinfo');
       		$errmsg = "Sorry. Internal error";
    	 } else {
       		$institution = $userinfo["institution"];
    	 }
         
     	 if (strlen($metadataQuest) > 0) {
         	foreach ($dirinfo as $d1 => $k1) {
			$form = <<<EOF
     <form action="$metadataQuest" method="post">
      	<fieldset>
     	 	<input type="hidden" name="institutionId" value="$institution" />
     	 	<input type="hidden" name="uploadDirectory" value="$d1" />
			<input type="submit" name="$d1" value="$d1" />
      	</fieldset>
     </form>
EOF;
			echo $form;
         	}
     	 } else {
         	foreach ($dirinfo as $d1 => $k1) {
            	echo $d1 . " ";
         	}
     	 }
      ?>
   </span>.</p>
   <p>You may create new user directories in the 
   <?php
       echo '<a href="adm.php?sessioncode=' .
       $sessioncode . '&normemail=' . $normemail . '">Administration</a>' . "\n";
   ?>
   page.</p>

   <form enctype="multipart/form-data" action="main.php" method="post">
   <p>
      <input type="hidden" name="MAX_FILE_SIZE" value="[==MAX_UPLOAD_SIZE_BYTES==]" />
      <?php
         echo '<input type="hidden" name="normemail" value="' . $normemail . '" />' . "\n";
         echo '<input type="hidden" name="sessioncode" value="' . $sessioncode . '" />' . "\n";
      ?>
      You may upload files to directories not owned by you (even directories owned by another
      institution). In that case you must obtain the directory key from the owner of the
      directory, and fill it into the entry field below. Otherwise, you should leave the directory
      key field empty.<br /><br />
      Directory key: <input name="dirkey" value="" size="10" />&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
      File name: <input name="fileinfo" type="file" />
      <input class="selectbutton1" type="submit" name="BTN_upload" value="Upload" />
   </p>
   <h3>Previously uploaded files</h3>
   <input type="radio" name="selrec" value="-1" checked /> Upload a new file
   <table border="1" bgcolor="white" cellspacing="0" cellpadding="8" width="100%">
      <colgroup width="6%" />
      <colgroup width="37%" />
      <colgroup width="10%" />
      <colgroup width="37%" />
      <colgroup width="10%" />
      <tr>
         <th>Replace</th>
         <th>File name</th>
         <th>Size</th>
         <th>Status</th>
         <th>Show errors</th>
      </tr>
      <?php
         $recnum = 0;
         foreach ($filecontent as $filerec) {
            echo "<tr>\n";
            echo '<td><input type="radio" name="selrec" value="' . $recnum++ . '" />' . "\n";
            echo '<td>' . $filerec["name"] . '</td>' . "\n";
            echo '<td>' . $filerec["size"] . '</td>' . "\n";
            echo '<td>' . $filerec["status"] . '</td>' . "\n";
            if ($filerec["errurl"] != "") {
               echo '<td><a href="' . $filerec["errurl"] . '" target="_blank">Show</a></td>' . "\n";
            } else {
               echo '<td>&nbsp;</td>' . "\n";
            }
            echo "</tr>\n";
         }
      ?>
   </table>
   </form>
   </div>
         </td>
      </tr>
   </table>
[==APP_FOOTER_HTML==]
</div>
</body>
</html>
