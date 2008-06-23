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
 // The user has pushed the "Retrieve" button
 // in the Administration page
 //
 $nextpage = 3;
 check_credentials(); // Sets $error, $errmsg, $nextpage, $normemail, $sessioncode,
               // $runpath, $filepath, $dirinfo and $filecontent (globals).
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
 if ($error == 0) {
    $dirname = conditional_decode($_POST["dirname"]);
#    $dirinfo = get_dirinfo($filepath);
#    if (is_bool($dirinfo) && $dirinfo == FALSE) {
#       mmPutLog("Function get_dirinfo returned FALSE");
#       $errmsg = "[Retrieve] failed. Internal error";
#       $error = 1;
#       $nextpage = 1;
#    }
# }
# if ($error == 0) {
    if (! array_key_exists($dirname,$dirinfo)) {
       $errmsg = "[Retrieve] failed. No such directory name";
       $error = 1;
       $nextpage = 3;
    } else {
       $dirkey = decodenorm($dirinfo[$dirname]);
    }
 }
?>
