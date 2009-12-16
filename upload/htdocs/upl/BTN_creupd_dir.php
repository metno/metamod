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
 // The user has pushed the "Create/Update" button in the Administration page
 //
 check_credentials(); // Sets $error, $errmsg, $nextpage, $normemail, $sessioncode,
                      // $runpath, $filepath, $filecontent and $dirinfo (globals).
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
    $update_dirinfo_needed = FALSE;
    $dirname = conditional_decode($_POST["dirname"]);
    if (strlen($dirname) == 0) {
       // directory name can be in input or select box
       $dirname = conditional_decode($_POST["knownDirname"]);
    }
    
    if (!preg_match ('/^[a-zA-Z0-9.-]+$/',$dirname)) {
       $error = 1;
       $nextpage = 3;
       mmPutLog('Create/Update: Illegal character in directory name');
       $errmsg = "[Create/Update] failed. Illegal character in directory name." .
                 " Use only: a-z A-Z 0-9 . -";
    } else if (strlen($dirname) > $mmConfig->getVar('MAXLENGTH_DIRNAME')) {
       $error = 1;
       $nextpage = 3;
       mmPutLog('Create/Update: Illegal directory name');
       $errmsg = "[Create/Update] failed. Directory name too long." .
                 " Max ".$mmConfig->getVar('MAXLENGTH_DIRNAME')." characters allowed";
    }
 }
 if ($error == 0) {
    $dirkey = conditional_decode($_POST["dirkey"]);
    if (strlen($dirkey) > $mmConfig->getVar('MAXLENGTH_DIRKEY')) {
       $error = 1;
       $nextpage = 3;
       mmPutLog('Create/Update: Illegal directory key');
       $errmsg = "[Create/Update] failed. Directory access key too long." .
                 " Max ".$mmConfig->getVar('MAXLENGTH_DIRKEY')." characters allowed";
    }
    $ndirkey = normstring($dirkey);
 }
# if ($error == 0) {
#     $dirinfo = get_dirinfo($filepath);
#    if (is_bool($dirinfo) && $dirinfo == FALSE) {
#       mmPutLog("Function get_dirinfo returned FALSE");
#       $errmsg = "[Create/Update] failed. Internal error";
#       $error = 1;
#       $nextpage = 1;
#    }
# }
 if ($error == 0) {
    $opendappath = get_repository_path() . "/" . $institution . "/" . $dirname;
    $dir_count = count(glob(get_repository_path() . "/*/" . $dirname));
    if (file_exists($opendappath) && $dir_count == 1) {
#
#      Directory already exists. No need to create
#
    } else if ($dir_count > 0) {
       mmPutLog('Create/Update: Repository directory used by another user ' . $opendappath);
       $errmsg = "Directory name already used by another user";
       $error = 1;
       $nextpage = 3;
    } else if (!create_directory($opendappath)) {
       $error = 2;
       $nextpage = 1;
       mmPutLog('Create/Update: Could not create directory ' . $opendappath);
       $errmsg = "[Create/Update] failed. Internal error";
    } else {
       $htaccess_source = get_repository_path() . "/.htaccess";
       $htaccess_dest = $opendappath . "/.htaccess";
       if (file_exists($htaccess_source) && copy($htaccess_source,$htaccess_dest)) {
          $errmsg = "Directory successfully created";
          $nextpage = 3;
       } else {
          mmPutLog('Create/Update: Failed: Copy of .htaccess to' . $opendappath);
          $errmsg = "[Create/Update] failed. Internal error";
          $error = 2;
          $nextpage = 1;
       }
    }
 }
 if ($error == 0) {
    $dirpath = get_upload_path() . "/" . $institution . "/" . $dirname;
    if (file_exists($dirpath)) {
       if (array_key_exists($dirname,$dirinfo)) {
          if ($dirinfo[$dirname] == $ndirkey) {
             $errmsg = "Directory already exists with the directory key you asked for";
          } else {
             $dirinfo[$dirname] = $ndirkey;
             $errmsg = "Directory key updated";
             $update_dirinfo_needed = TRUE;
          }
       } else {
          $dirinfo[$dirname] = $ndirkey;
          $errmsg = "Directory name already used by another user";
          $error = 1;
       }
       $nextpage = 3;
    } else if (count(glob(get_upload_path() . "/*/" . $dirname)) > 0) {
       mmPutLog('Create/Update: Attempted create directory used by another institution ' . $dirpath);
       $errmsg = "Directory name already in use by another institution";
       $error = 1;
       $nextpage = 3;
    } else if (!create_directory($dirpath)) {
       $error = 2;
       $nextpage = 1;
       mmPutLog('Create/Update: Could not create directory ' . $dirpath);
       $errmsg = "[Create/Update] failed. Internal error";
    } else {
       $errmsg = "Directory successfully created";
       $dirinfo[$dirname] = $ndirkey;
       $update_dirinfo_needed = TRUE;
       $nextpage = 3;
    }
 }
 if ($error == 0) {
    if ($update_dirinfo_needed) {
       $bytecount = put_dirinfo($filepath,$dirinfo);
       if ($bytecount == 0) {
          mmPutLog('Could not update the user file with dir info. 0 bytes written');
          $errmsg = 'Sorry. Internal error';
          $error = 2;
          $nextpage = 1;
       }
    }
 }
?>
