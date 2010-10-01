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
 if ($debug) {
    mmPutTest("--------- User pushed Upload");
 }
 check_credentials(); // Sets $error, $errmsg, $nextpage, $normemail, $sessioncode,
                      // $runpath, $filepath and $filecontent (globals).
 if ($error == 0) { // Check that institution exists and set $institution var.
    $userinfo = get_userinfo($filepath);
    if (!array_key_exists("u_institution",$userinfo)) {
       $error = 2;
       $nextpage = 1;
       mmPutLog('No u_institution in userinfo');
       $errmsg = "Sorry. Internal error";
    } else {
       $institution = $userinfo["u_institution"];
       mmPutTest("BTN_upload.php: OK get_userinfo");
    }
 }
 if ($error == 0) { // Check if this is a re-upload of an existing file
    $selrec = -1;
    if (array_key_exists("selrec",$_POST)) { // True if the user has checked
                                             // a radio button in the file table
                                             // showing uploaded files.
       $selrec = conditional_decode($_POST["selrec"]); // Index in the $filecontent array of the
                                   // selected file
    }
 }
 if ($error == 0) { // Get directory key
    if (array_key_exists("dirkey",$_POST)) {
       $directory_key = normstring(conditional_decode($_POST["dirkey"]));
       mmPutTest("BTN_upload.php: OK get directory key");
    } else {
       mmPutLog('No directory key');
       $errmsg = 'Sorry. Internal error';
       $error = 2;
       $nextpage = 1;
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
       mmPutTest("BTN_upload.php: OK fileinfo found in FILES array");
    }
 }
 if ($error == 0) { // Retrieve file info, check file name
    $origname = $_FILES["fileinfo"]["name"];
    if (strlen($origname) == 0) {
       mmPutLog('BTN_upload.php: No such file name');
       $errmsg = 'No such file name';
       $error = 1;
       $nextpage = 2;
    } elseif (!preg_match ('/^[a-zA-Z0-9_.-]+$/',$origname)) {
       mmPutLog('BTN_upload.php: Illegal characters in file name: "' . $origname .'"');
       $errmsg = 'Illegal characters in file name';
       $error = 1;
       $nextpage = 2;
    }
    mmPutTest("BTN_upload.php: OK original filename is: " . $origname);
 }
 if ($error == 0) { // Check file size
    $tmpname = $_FILES["fileinfo"]["tmp_name"];
    $size = $_FILES["fileinfo"]["size"];
    if ($size == 0) {
       mmPutLog('User attemped to upload an empty file');
       $errmsg = 'Empty files are not accepted';
       $error = 1;
       $nextpage = 2;
    }
    mmPutTest("BTN_upload.php: OK file size is: " . $size);
    mmPutTest("BTN_upload.php: OK temporary file name is: " . $tmpname);
 }
 if ($error == 0) { // Extract user directory name from $origname
    if (!preg_match ('/^([^_]+)_/',$origname,$matches)) {
       mmPutLog('Upload: User directory not part of file name');
       $errmsg = 'File name must start with "dir_" where dir is the destination directory';
       $error = 1;
       $nextpage = 2;
    } else {
       $dirname = $matches[1];
       mmPutTest("BTN_upload.php: OK destination directory is: " . $dirname);
    }
 }
 //
 // Check if the user directory name matches any user directory
 // name in any institution directory. If so, check the supplied
 // directory key
 //
 if ($error == 0) {
    $errmsg = "";
    $new_institution = checkDirectoryPermission($dirname, $directory_key, $errmsg);
    if ($new_institution === FALSE) {
       mmPutLog("checkDirectoryPermission returns FALSE: $errmsg");
       $error = 1;
       $nextpage = 2;
    } else if ($new_institution !== TRUE) {
       $institution = $new_institution;
    }
 }
 if ($error == 0) {
    mmPutTest("BTN_upload.php: OK destination directory found");
    $dirpath = get_upload_path() . "/" . $institution . "/" . $dirname;
    if (!file_exists($dirpath)) {
       $error = 1;
       $nextpage = 2;
       mmPutLog('Upload: No user directory: ' . $dirpath);
       $errmsg = "Upload failed. User directory, " . $dirname . ", not found.";
    }
    mmPutTest("BTN_upload.php: OK file will be uploaded to path: " . $dirpath);
 }
 if ($error == 0 && $selrec < 0) { // Check if the original file name is the same as the 
             // original file name for an existing file. This is not allowed without checking
             // a replace radio button
    reset($filecontent);
    foreach ($filecontent as $filearr) {
       if ($filearr["f_name"] == $origname) {
          mmPutLog('User attemped to upload an existing file without resubmit');
          $errmsg = 'To upload an already uploaded file,' .
                    'you must check the "Replace" radio button to the left of the file entry.';
          $error = 1;
          $nextpage = 2;
          break;
       }
    }
 }
 if ($error == 0 && $selrec < 0) { // Check if the same file already exists in
                                   // the file system (i.e. uploaded by another
                                   // user).
    if (file_exists($dirpath . '/' . $origname)) {
       mmPutLog('User attemtped to upload an existing file owned by another');
       $errmsg = 'File already uploaded by another user. Use a different file name';
       $error = 1;
       $nextpage = 2;
       break;
    }
 }
 $existingname = "";
 if ($error == 0 && $selrec >= 0) { // File to be uploaded have been uploaded before.
                                    // Extract user directory name for the existing
                                    // file
    $existingname = $filecontent[$selrec]["f_name"];
    if (!preg_match ('/^([^_]+)_/',$existingname,$matches)) {
       mmPutLog('Upload: User directory not part of existing file name');
       $errmsg = 'Could not upload. Internal error';
       $error = 2;
       $nextpage = 1;
    } else {
       $olddirname = $matches[1];
    }
 }
 if ($error == 0 && $selrec >= 0) { // File to be uploaded have been uploaded before.
                                    // Delete existing file
    $olddirpath = get_upload_path() . "/" . $institution . "/" . $olddirname;
    $oldfilename = $olddirpath . "/" . $existingname;
    if (file_exists($oldfilename)) {
       if (!unlink($oldfilename)) {
          mmPutLog('Upload: Existing file could not be deleted');
          $errmsg = 'Could not upload. Internal error';
          $error = 2;
          $nextpage = 1;
       }
    }
 }
 if ($error == 0) { // Move the uploaded file to the permanent upload directory:

    mmPutTest("BTN_upload.php: About to move uploaded file to: " . $dirpath);
    if (!move_uploaded_file($tmpname,$dirpath . '/' . $origname)) {
       mmPutLog('Could not move uploaded file to the upload directory');
       $errmsg = 'Sorry. Unable to upload file';
       $error = 2;
       $nextpage = 1;
    }
 }
 if ($error == 0 and update_fileinfo($filepath,$existingname,$origname,$size) === FALSE) {
    mmPutLog('Upload: Could not update file info in the User database');
    $errmsg = 'Could not upload. Internal error';
    $error = 2;
    $nextpage = 1;
 }
 if ($error == 0) { // Update the $filecontent array
    $filecontent = get_fileinfo($filepath);
    if (is_bool($filecontent) && $filecontent == FALSE) {
        mmPutLog("On updating the filecontent array, function get_fileinfo returned FALSE");
        $errmsg = 'Sorry. Internal error';
        $error = 2;
        $nextpage = 1;
    }
 }
?>
