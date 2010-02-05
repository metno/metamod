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
 check_credentials(); // Sets $error, $errmsg, $nextpage, $normemail, $sessioncode,
 if ($debug) {
    mmPutTest("--------- User pushed Upload test file");
 }
                      // $runpath, $filepath and $filecontent (globals).
 if ($error == 0) { // Check that institution exists and set $institution var.
    $userinfo = get_userinfo($filepath);
    if (!array_key_exists("institution",$userinfo)) {
       $error = 2;
       $nextpage = 1;
       mmPutLog('No institution in userinfo');
       $errmsg = "Sorry. Internal error";
    } else {
       $institution = $userinfo["institution"];
       mmPutTest("BTN_dotest.php: OK get_userinfo");
    }
 }
 if ($error == 0) { // Check content of the $_FILES array, containing info about
                    // the uploaded file
    if (!array_key_exists("fileinfo",$_FILES)) {
       mmPutLog('No "fileinfo" key in $_FILES');
       $errmsg = 'Sorry. Internal error';
       $error = 2;
       $nextpage = 1;
    } else { // The keys below are used by PHP's file upload system:
             // http://no2.php.net/manual/en/features.file-upload.php
       foreach (array("name","tmp_name","size") as $key) {
          if (!array_key_exists($key,$_FILES["fileinfo"])) {
             mmPutLog('Missing keys in array $_FILES["fileinfo"]');
             $errmsg = 'Sorry. Internal error';
             $error = 2;
             $nextpage = 1;
             break;
          }
       }
       mmPutTest("BTN_dotest.php: OK fileinfo found in FILES array");
    }
 }
 if ($error == 0) { // Retrieve file info, check file name
    $origname = $_FILES["fileinfo"]["name"];
    if (strlen($origname) == 0) {
       mmPutLog('BTN_dotest.php: No such file name');
       $errmsg = 'No such file name';
       $error = 1;
       $nextpage = 4;
    } elseif (!preg_match ('/^[a-zA-Z0-9_.-]+$/',$origname)) {
       mmPutLog('BTN_dotest.php: Illegal characters in file name: "' . $origname .'"');
       $errmsg = 'Illegal characters in file name';
       $error = 1;
       $nextpage = 4;
    }
    mmPutTest("BTN_dotest.php: OK original filename is: " . $origname);
 }
 if ($error == 0) { // Extract user directory name from $origname
    if (!preg_match ('/^([^_]+)_/',$origname,$matches)) {
       mmPutLog('BTN_dotest.php: User directory not part of file name');
       $errmsg = 'File name must start with "dir_" where dir is a destination directory (which need not exist)';
       $error = 1;
       $nextpage = 4;
    } else {
       $dirname = $matches[1];
       mmPutTest("BTN_dotest.php: OK destination directory is: " . $dirname);
    }
 }
 if ($error == 0) { // Check file size
    $tmpname = $_FILES["fileinfo"]["tmp_name"];
    $size = $_FILES["fileinfo"]["size"];
    if ($size == 0) {
       mmPutLog('User attemped to upload an empty file');
       $errmsg = 'File is empty';
       $error = 1;
       $nextpage = 4;
    }
    mmPutTest("BTN_dotest.php: OK file size is: " . $size);
    mmPutTest("BTN_dotest.php: OK temporary file name is: " . $tmpname);
 }
 if ($error == 0) { // Write a file containing the E-mail address, and
                    // move the uploaded file to the destination directory:

    $emailfile = $mmConfig->getVar('WEBRUN_DIRECTORY').'/upl/etaf/' . $origname;
    $EMAILFILE = fopen($emailfile,'w');
    fwrite($EMAILFILE,decodenorm($normemail) . " " . $userinfo["name"] . "\n");
    fclose($EMAILFILE);
    $dirpath = $mmConfig->getVar('WEBRUN_DIRECTORY').'/upl/ftaf';
    mmPutTest("BTN_dotest.php: About to move uploaded file to: " . $dirpath);
    if (!move_uploaded_file($tmpname,$dirpath . '/' . $origname)) {
       mmPutLog('Could not move uploaded file to the upload directory');
       $errmsg = 'Sorry. Unable to upload file';
       $error = 2;
       $nextpage = 1;
    } else {
       $errmsg = $origname . ' loaded successfully. Test report will be sent on E-mail.';
       $nextpage = 4;
    }
 }
?>
