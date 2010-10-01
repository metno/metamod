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
 // The user has pushed the "Upload file" link
 //
 if ($debug) {
    mmPutTest("--------- User pushed Upload file");
 }
 $nextpage = 2;
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
    }
 }
?>
