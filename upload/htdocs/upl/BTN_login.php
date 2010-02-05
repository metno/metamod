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
 // Entered this page from the login form. Check user credentials
 //
 if ($debug) {
    mmPutTest("--------- User pushed Log in");
 }
 $email = conditional_decode($_POST["email"]);
 $paw = conditional_decode($_POST["paw"]); // Password
 if (strlen($email) == 0 || strlen($paw) == 0) {
    mmPutLog("User provided empty E-mail address or password");
    $errmsg = 'You must provide both an E-mail address and a password';
    $error = 1;
    $nextpage = 1;
 }
 if ($error == 0) {
    $normemail = normstring($email); // Normalized E-mail address. To get rid of funny characters
    $filename = $normemail . '.' . normstring($paw); // User filename
    $runpath = mmGetRunPath();
    $u1path = $runpath . '/u1';
    if (!create_directory($u1path)) {
       mmPutLog("Error while creating directory: $u1path");
       $errmsg = 'Sorry, you were not logged in. Internal error';
       $error = 2;
       $nextpage = 1;
    }
    $u2path = $runpath . '/u2';
    if (!create_directory($u2path)) {
       mmPutLog("Error while creating directory: $u2path");
       $errmsg = 'Sorry, you were not logged in. Internal error';
       $error = 2;
       $nextpage = 1;
    }
 }
 if ($error == 0) {
    $filepath = $u1path . '/' . $filename;
    if (!file_exists($filepath)) { // Which means wrong E-mail address or password
       mmPutLog("Attemted login did not succeed: $filename");
       $errmsg = 'Sorry, wrong E-mail address or password';
       $error = 1;
       $nextpage = 1;
    }
 }
 if ($error == 0) { // Check if user wants to change password
    $errextra = ''; // Extra info to the user prepended to an error message.
                    // To be used if password change was successful, 
                    // but other error occured.
    $changepaw = array_key_exists("changepaw", $_POST) && $_POST["changepaw"] == 1;
    $pawnew1 = "";
    if (array_key_exists("pawnew1", $_POST)) {
       $pawnew1 = conditional_decode($_POST["pawnew1"]);
    }
    $pawnew2 = "";
    if (array_key_exists("pawnew2", $_POST)) {
       $pawnew2 = conditional_decode($_POST["pawnew2"]);
    }
    if (strlen($pawnew1) > 0 && strlen($pawnew2) > 0) {
       if ($changepaw && $pawnew1 == $pawnew2) { // Change password to user-supplied password
          $newfilename = $normemail . '.' . normstring($pawnew1); // User filename
          $newfilepath = $u1path . '/' . $newfilename;
          if (!rename($filepath,$newfilepath)) {
             mmPutLog("Function rename returnef FALSE.");
             mmPutLog("   - from: $filepath");
             mmPutLog("   - to:   $newfilepath");
             $errmsg = 'Sorry. Could not change your password. Internal error';
             $error = 2;
             $nextpage = 1;
          } else {
             $filename = $newfilename;
             $filepath = $newfilepath;
             $paw = $pawnew1;
             $errextra = 'Your password were changed, BUT: ';
          }
       } else if (!$changepaw) {
          mmPutLog("User provided new password without checking the change password checkbox");
          $errmsg = 'Warning: You have to check the "change password" checkbox<br>' . "\n" .
                    'if you want to change the password. Password not changed.';
          $error = 1;
          $nextpage = 1;
       } else {
          mmPutLog("User supplied different versions of new password");
          $errmsg = 'The two versions of your new password were not equal';
          $error = 1;
          $nextpage = 1;
       }
    } else if ($changepaw) {
       mmPutLog("User supplied an emtpty new password");
       $errmsg = 'Passwords are not allowed to be empty strings. Password not changed';
       $error = 1;
       $nextpage = 1;
    }
 }
 if ($error == 0) { // Set up a new user session:
    $sessioncode = create_user_session($filename);
    if (is_bool($sessioncode) && $sessioncode == FALSE) {
       mmPutLog("Problems creating new user session: $filename");
       $errmsg = $errextra . 'Sorry, you were not logged in. Internal error';
       $error = 2;
       $nextpage = 1;
    }
 }
 if ($error == 0) { // Get content of the user file to be displayed in "maintable.php"
    $filepath = $runpath . '/u2/' . $normemail . '.' . $sessioncode;
    $filecontent = get_fileinfo($filepath);
    if (is_bool($filecontent) && $filecontent == FALSE) {
       mmPutLog("Function get_fileinfo returned FALSE. Filepath: ". $filepath);
       $errmsg = $errextra . 'Sorry, you were not logged in. Internal error';
       $error = 2;
       $nextpage = 1;
    }
 }
 if ($error == 0) { // Check that institution exists and set $institution var.
    $userinfo = get_userinfo($filepath);
    if (!array_key_exists("institution",$userinfo)) {
       $error = 2;
       $nextpage = 1;
       mmPutLog('No institution in userinfo');
       $errmsg = "Sorry. Internal error";
    } else {
       $institution = $userinfo["institution"];
    }
 }
 if ($error == 0) { // Write a new version of the user file to disk:
    $bytecount = put_fileinfo($filepath,$filecontent);
    if ($bytecount == 0) {
       mmPutLog('Could not update the user file. 0 bytes written');
       $errmsg = 'Sorry. Internal error';
       $error = 2;
       $nextpage = 1;
    }
 }
 if ($error == 0) { // Get directory info from the user file:
    $dirinfo = get_dirinfo($filepath);
    if (is_bool($dirinfo) && $dirinfo == FALSE) {
       mmPutLog("Function get_dirinfo returned FALSE");
       $error = 1;
       $nextpage = 1;
       $errmsg = "Sorry, internal error";
    }
 }
?>
