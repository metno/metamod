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
#
#  Prosessing new user registration forms. A file is initially created for new
#  users in directory $u0path. A notification E-mail is sent to the operator who
#  has to approve the new user. Approved users have their user files moved from
#  $u0path to $u1path. If a user file matching the user application is found in
#  $u1path, then the user is given a new password, and the password is 
#  automatically sent to the user by E-mail.
#
   include_once("../funcs/mmConfig.inc");
   include_once("../funcs/mmUserbase.inc");
   include "funcs.inc";
   $debug = $mmConfig->getVar('DEBUG');
   if ($debug == 1) {
      print_r($_POST);
   }
   $paw = mkpasswd(); // Create new password
   $name = conditional_decode($_POST["name"]);
   $email = conditional_decode($_POST["email"]);
   $regex = '^[_a-zA-Z0-9-]+(\.[_a-zA-Z0-9-]+)*@[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)+$';
   $normemail = normstring($email);
   $filename = $normemail . '.' . normstring($paw); // New user filename
   $runpath = mmGetRunPath();
   $u1path = $runpath . '/u1';
   if (!create_directory($u1path)) {
      mmPutLog("Error while creating directory: $u1path");
      $errmsg = 'Sorry, your request were not received. Internal error';
      include "login.php";
   } else {
      $matching = glob($u1path . '/' . $normemail . '.*');
      $matchingcount = count($matching);
      if (!ereg($regex,$email)) {
         $errmsg = 'Badly formed E-mail address. Please correct and send the form again.';
         include "login.php";
      } else if ($matchingcount == 0) { // User not found among already registered users
         $u0path = $runpath . '/u0';
         if (!create_directory($u0path)) {
            mmPutLog("Error while creating directory: $u0path");
            $errmsg = 'Sorry, your request were not received. Internal error';
            include "login.php";
         } else {
            $s1 = preg_replace(':/[^/]*/[^/]*$:','',$_SERVER["REQUEST_URI"]);
            $approvelink = 'Approve: http://' .
                           $_SERVER["HTTP_HOST"] . $s1 . '/adm/approve.php?em=' . $normemail;
            $matching = glob($u0path . '/' . $normemail . '.*');
            $matchingcount = count($matching);
            if ($matchingcount == 0) { // The user has not already sent a registration form
               $fileid = fopen($u0path . '/' . $filename,'w+b');
               if ($fileid != false) {
                  $heading = '<heading';
                  $notification = "New user details:\n";
                  $items = array("name","email","institution","telephone");
                  $userinfo = array();
                  foreach ($items as $item) {
                     $heading .= ' ' . $item . '="' . normstring(conditional_decode($_POST[$item])) . '"';
                     $notification .= '   ' . $item . ': ' . conditional_decode($_POST[$item]) . "\n";
                     $userinfo['u_' . $item] = conditional_decode($_POST[$item]);
                  }
                  $heading .= " />\n";
                  fwrite($fileid,$heading);
                  fclose($fileid);
                  $userinfo['u_password'] = $paw;
                  if ($debug == 1) {
                     print_r($userinfo);
                  }
                  if (put_userinfo($userinfo) === FALSE) {
                     mmPutLog("Error while adding user info to the User database");
                     $errmsg = 'Sorry, internal error while processing your request';
                     include "login.php";
                  } else {
                     include "./newuserok.php";
                     $notification .= "\n\n" . $approvelink;
                     mail($mmConfig->getVar('OPERATOR_EMAIL'),
                          "New ".$mmConfig->getVar('APPLICATION_NAME')." user",
                          $notification,
                          "From: ".$mmConfig->getVar('FROM_ADDRESS'));
                  }
               } else {
                  mmPutLog("Error while opening file: $u0path/$filename");
                  $errmsg = 'Sorry, your request were not received. Internal error';
                  include "login.php";
               }
            } else { // The user has already sent a registration form
               include "./newuserok.php";
               $msg = "Repeated request from: $email" . "\n\n" . $approvelink;
               mail($mmConfig->getVar('OPERATOR_EMAIL'), "New ".$mmConfig->getVar('APPLICATION_NAME')." user",$msg, "From: ".$mmConfig->getVar('FROM_ADDRESS'));
            }
         }
      } else if ($matchingcount == 1) { // The user is already a registered user. Change password
         $oldfilepath = $matching[0];
         rename($oldfilepath,$u1path . '/' . $filename);
         if (strlen($mmConfig->getVar('TEST_EMAIL_RECIPIENT')) == 0) {
            $email = $mmConfig->getVar('OPERATOR_EMAIL');
         }
         if ($mmConfig->getVar('TEST_EMAIL_RECIPIENT') != '0') {
            send_welcome_mail($name,$email,$paw);
         }
         include "./newuserok.php";
      } else {
         $errmsg = 'Sorry, your request were not received. Internal error';
         include "login.php";
         mmPutLog("Error while registering new file upload user.\n" .
                  "   More than one user with same E-mail address: $email");
      }
   }
?>
