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
#  This file is activated by the METAMOD2 file repository operator from
#  an E-mail sent by the upl/newuser.php file. It will move the user file from
#  directory $u0path to $u1path, and thereby approve the new user.
#  The user will be sent a standard E-mail containing his password. An html
#  page is produced for the operator confirming that the approvement actions
#  has been performed.
#
   include "../upl/funcs.inc";
   print_r($_GET);
   $normemail = $_GET["em"];
   $runpath = mmGetRunPath();
   $u1path = $runpath . '/u1';
   $u0path = $runpath . '/u0';
   $matching1 = glob($u1path . '/' . $normemail . '.*');
   if (count($matching1) >= 1) {
      echo 'User is already registered. Nothing done';
   } else {
      $matching0 = glob($u0path . '/' . $normemail . '.*');
      if (count($matching0) == 1) {
         $oldfilepath = $matching0[0];
         $filename = basename($oldfilepath);
         $userinfo = get_userinfo($oldfilepath);
         rename($oldfilepath,$u1path . '/' . $filename);
         if (array_key_exists("name",$userinfo) &&
             array_key_exists("email",$userinfo) &&
             array_key_exists("paw",$userinfo)) {
            $email = $userinfo["email"];
            if ('[==TEST_EMAIL_RECIPIENT==]' == '') {
               $email = '[==OPERATOR_EMAIL==]';
            }
            if ('[==TEST_EMAIL_RECIPIENT==]' != '0') {
               send_welcome_mail($userinfo["name"],$email,$userinfo["paw"]);
            }
            echo 'User approved and moved to u1, Welcome mail sent';
         } else {
            echo 'User approved and moved to u1, Heading problems in user file';
         }
      } else if (count($matching0) > 1) {
         echo 'More than one user found on u0. Nothing done';
      } else {
         echo 'User not found. Nothing done';
      }
   }
?>
