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
include_once("../funcs/mmConfig.inc");
#
#  Main page for users which are logged into the upload service.
#
   $debug = $mmConfig->getVar('DEBUG');
   if ($debug == 0) {
      ob_start(); // Turn on output buffering. The output buffer is discarded before
                  // normal user output is sent.
   }
   include_once "funcs.inc";
   $errmsg = "";
   $error = 0; // If any error is encountered, this variable is set to 1 or 2 (severe error)
   $nextpage = 2; // =1 if the login page should be submitted to the user
                  // =2 if the file upload page should be submitted
                  // =3 if the administration page should be submitted
   $dirname = ""; // Eventually to be set by BTN_retr_dir
   $dirkey = "";  // Eventually to be set by BTN_retr_dir
   if ($debug == 1) {
#
# Debug info:
#
      print_r($_POST);
      echo "<br>\n";
      if (isset($_FILES)) {
         print_r($_FILES);
      }
   }
#
   $submit = get_buttonname();
   if ($debug == 1) {
      echo "<br> Button name: $submit \n";
   }
   if ($submit == FALSE) {
      include 'BTN_upl.php';
      if ($error == 0) {
         $error = 1;
         mmPutLog('Attempted upload of too large file. get_buttonname() returned FALSE');
         $maxsize = $mmConfig->getVar('MAX_UPLOAD_SIZE_BYTES')/1000000;
         $errmsg = "Upload failed. Max file size (" . $maxsize . " MB) exceeded";
      }
   } else {
      if ($submit == 'BTN_login') { // Entered this page from the login form. Check user credentials
         include 'BTN_login.php';
      }
      if ($submit == 'BTN_upload') { // The user has pushed the upload button
                                     // in the previous incarnation of this page.
         include 'BTN_upload.php';
      } else if ($submit == 'BTN_adm') { // The user has pushed the "Administration" link
         include 'BTN_adm.php';
      } else if ($submit == 'BTN_retr_dir') {
         include 'BTN_retr_dir.php';
      } else if ($submit == 'BTN_creupd_dir') {
         include 'BTN_creupd_dir.php';
      } else if ($submit == 'BTN_upl') { // The user has pushed the "Upload file" link
         include 'BTN_upl.php';
      } else if ($submit == 'BTN_tfile') { // The user has pushed the "Test a file" link
         include 'BTN_tfile.php';
      } else if ($submit == 'BTN_filetest') { // The user has loaded a file for testing
         include 'BTN_dotest.php';
      } else if ($submit == 'BTN_newsession') { // The user has entered from index.php
         $nextpage = 1;
         $errmsg = "";
      } else if ($submit == 'BTN_logout') { // The user has pushed the "Log out" button
         $normemail = conditional_decode($_POST["normemail"]);
         $sessioncode = conditional_decode($_POST["sessioncode"]);
         $runpath = mmGetRunPath();
         $filepath = $runpath . '/u2/' . $normemail . '.' . $sessioncode;
         unlink($filepath);
         $nextpage = 1;
         $errmsg = "";
      }
   }
   if ($debug == 0) { // Until now, no normal user output have been sent. The output buffer
                      // is cleaned to get rid of any error messages or random debug information.
      ob_end_clean();
   }
   if ($nextpage == 1) {
      include "login.php"; // Login page. Start a new session
   } else if ($nextpage == 2) {
      include "maintable.php"; // Show the File Upload page
   } else if ($nextpage == 3) {
      include "mainadm.php"; // Show the Administration page
   } else if ($nextpage == 4) {
      include "testafile.php"; // Show the Test a file page
   }
?>
