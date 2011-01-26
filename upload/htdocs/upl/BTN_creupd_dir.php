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
 // Two cases: Normal.   The user provides no THREDDS location or catalog
 //                      information. Repostiory and upload directories are
 //                      created.
 //            External. The user provides THREDDS location and catalog information.
 //                      No creation of the directory in the repository or in the
 //                      upload area. Used if the configuration variable
 //                      EXTERNAL_REPOSITORY is set to true.
 //
 require_once("../funcs/mmDataset.inc");
 if ($debug) {
    mmPutTest("--------- User pushed Create/Update");
 }
 check_credentials(); // Sets $error, $errmsg, $nextpage, $normemail, $sessioncode,
                      // $runpath, $filepath, $filecontent and $dirinfo (globals).
 $external_repository = (strtolower($mmConfig->getVar('EXTERNAL_REPOSITORY')) == "true");
 mmPutTest("BTN_creupd_dir.php: starting, external_repository = $external_repository");
 if ($error == 0) { // Check that institution exists and set $institution var.
    $nextpage = 3;
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
 if ($error == 0) {
 // Check the directory name provided by the user:

    $dirname = get_postvar("dirname");
    if (strlen($dirname) == 0) {
       $error = 1;
       $nextpage = 3;
       $errmsg = "[Create/Update] No directory name. Use Retrieve button";
    } else if (!preg_match ('!^[a-zA-Z0-9.-]+$!',$dirname)) {
       $error = 1;
       $nextpage = 3;
       mmPutLog('Create/Update: Illegal character in directory name: |' . $dirname . '|');
       $errmsg = "[Create/Update] failed. Illegal character in directory name." .
                 " Use only: a-z A-Z 0-9 . -";
    } else if (strlen($dirname) > $mmConfig->getVar('MAXLENGTH_DIRNAME')) {
       $error = 1;
       $nextpage = 3;
       mmPutLog('Create/Update: Illegal directory name');
       $errmsg = "[Create/Update] failed. Directory name too long." .
                 " Max ".$mmConfig->getVar('MAXLENGTH_DIRNAME')." characters allowed";
    }
    $newdirname = $dirname; // This will be the new value of dirname that will be shown in
                            // the next incarnation of the administration page. It will be
                            // set to an empty string if no more actions on the directory
                            // seem to be neccessary.
 }
 mmPutTest("BTN_creupd_dir.php: directory name = $dirname");
 if ($error == 0) {
 // If directory/dataset information exists in the user database, fetch it and
 // eventually populate variables $odirkey, $olocation and $othreddscatalog:

    $odirkey = "";
    $olocation = "";
    $othreddscatalog = "";
    $owmsurl = "";
    if (array_key_exists($dirname,$dirinfo)) {
       $dirattributes = $dirinfo[$dirname];
       foreach (array('DSKEY','LOCATION','CATALOG','WMS_URL') as $k1) {
          if (array_key_exists($k1, $dirattributes)) {
             $val = $dirattributes[$k1];
             if ($k1 == 'DSKEY') {
                $odirkey = $val;
             } else if ($k1 == 'LOCATION') {
                $olocation = $val;
             } else if ($k1 == 'CATALOG') {
                $othreddscatalog = $val;
             } else if ($k1 == 'WMS_URL') {
                $owmsurl = $val;
             }
          }
       }
       mmPutTest("BTN_creupd_dir.php: old directory attributes found");
    }
 }
 $update_dirinfo_needed = FALSE;
 if ($error == 0) {
 // Get fields provided by user from $_POST array:

    $dirkey = get_postvar("dirkey");
    $location = get_postvar("location");
    $threddscatalog = get_postvar("threddscatalog");
    $wmsurl = get_postvar("wmsurl");
    mmPutTest("BTN_creupd_dir.php: new directory attributes taken from POST");
 }
 if ($error == 0) {
 // Get a new value for the directory key if provided by the user. Check it
 // and make a normalized string out of it ($ndirkey):

    if (strlen($dirkey) == 0 && $external_repository) {
       $error = 1;
       $nextpage = 3;
       mmPutLog('Create/Update: User provided empty directory key');
       $errmsg = "[Create/Update] failed. You must provide  a Directory key.";
    } elseif (strlen($dirkey) > $mmConfig->getVar('MAXLENGTH_DIRKEY')) {
       $error = 1;
       $nextpage = 3;
       mmPutLog('Create/Update: Illegal directory key');
       $errmsg = "[Create/Update] failed. Directory access key too long." .
                 " Max ".$mmConfig->getVar('MAXLENGTH_DIRKEY')." characters allowed";
    }
    if ($dirkey != $odirkey) {
       $update_dirinfo_needed = TRUE;
    }
    $ndirkey = $dirkey;
    mmPutTest("BTN_creupd_dir.php: directory key checked");
 }
 if ($error == 0 && $external_repository) {
 // If the user has provided a location string (absolute directory path) and
 // an URL for the THREDDS catalog corresponding to the directory,
 // check them and normalize:

    if (strlen($location) == 0) {
       $error = 1;
       $nextpage = 3;
       mmPutLog('Create/Update: User provided no value for the location field');
       $errmsg = "[Create/Update] failed. You must provide a value for the Dataset location field";
    } elseif (!validate_abspath($location)) {
       $error = 1;
       $nextpage = 3;
       mmPutLog('Create/Update: Illegal location: ' . $location);
       $errmsg = "[Create/Update] failed. Dataset location field not accepted. It must start with a / " .
                 "character and only contain characters A-Za-z0-9/_-.";
    }
    if ($location != $olocation) {
       $update_dirinfo_needed = TRUE;
    }
    $nlocation = $location;
    if ($error == 0) {
       if (strlen($threddscatalog) == 0) {
          $error = 1;
          $nextpage = 3;
          mmPutLog('Create/Update: User provided no value for the threddscatalog field');
          $errmsg = "[Create/Update] failed. You must provide a value for the Dataset catalog (THREDDS) field";
       } elseif (!validate_absurl($threddscatalog)) {
          $error = 1;
          $nextpage = 3;
          mmPutLog('Create/Update: Illegal threddscatalog: ' . $threddscatalog);
          $errmsg = "[Create/Update] failed. Dataset catalog field (THREDDS) not accepted.\n" .
                    "Use something like http://host/path?dataset=datasetpath";
       }
       if ($threddscatalog != $othreddscatalog) {
          $update_dirinfo_needed = TRUE;
       }
    }
    $nthreddscatalog = $threddscatalog;
    mmPutTest("BTN_creupd_dir.php: THREDDS catalog checked");
 }
 $repositorypath = get_repository_path();
 if ($error == 0 && strlen($mmConfig->getVar("WMS_XML"))) {
 // If the user has provided an URL to WMS check it and normalize:

    if (strlen($wmsurl) == 0) {
       $error = 1;
       $nextpage = 3;
       mmPutLog('Create/Update: User provided no value for the wmsurl field');
       $errmsg = "[Create/Update] failed. You must provide a value for the URL to WMS field";
    } elseif (!validate_absurl($wmsurl)) {
       $error = 1;
       $nextpage = 3;
       mmPutLog('Create/Update: Illegal URL to WMS: ' . $wmsurl);
       $errmsg = "[Create/Update] failed. URL to WMS field not accepted";
    }
    if ($wmsurl != $owmsurl) {
       $update_dirinfo_needed = TRUE;
    }
    $nwmsurl = $wmsurl;
    mmPutTest("BTN_creupd_dir.php: URL to WMS checked");
 }
 if ($error == 0 && ! $external_repository) {
 // Normal case. No THREDDS location and catalog information entered.
 // Check if directory name is in use by another user
 // Create eventually the directory 

    $opendappath = $repositorypath . "/" . $institution . "/" . $dirname;
    $dir_count = count(glob($repositorypath . "/*/" . $dirname));
    if (file_exists($opendappath) && $dir_count == 1) {
#
#      Directory already exists. No need to create
#
    } else if ($dir_count > 0) {
       mmPutLog('Create/Update: Repository directory used by another user ' . $opendappath);
       $errmsg = "Directory $dirname already used by another user";
       $error = 1;
       $nextpage = 3;
       $newdirname = "";
    } else if (!create_directory($opendappath)) {
       $error = 2;
       $nextpage = 1;
       mmPutLog('Create/Update: Could not create directory ' . $opendappath);
       $errmsg = "[Create/Update] failed. Internal error";
    } else {
       $htaccess_source = $repositorypath . "/.htaccess";
       $htaccess_dest = $opendappath . "/.htaccess";
       if (file_exists($htaccess_source) && copy($htaccess_source,$htaccess_dest)) {
          $errmsg = "Directory $dirname successfully created";
          $nextpage = 3;
          $newdirname = "";
       } else {
          mmPutLog('Create/Update: Failed: Copy of .htaccess to' . $opendappath);
          $errmsg = "[Create/Update] failed. Internal error";
          $error = 2;
          $nextpage = 1;
       }
    }
    mmPutTest("BTN_creupd_dir.php: Check on opendappath = $opendappath finished. Errmsg: $errmsg");
 }
 $uploadpath = get_upload_path();
 if ($error == 0 && strlen($uploadpath) > 0 && ! $external_repository) {
 // Normal case. Check if upload path already exists. If this is the case, but no
 // directory info are found for this user, then another user from the same institution
 // owns this directory. Reject the current user.
 // Otherwise, check if the upload directory name already exists for another institution.
 // In that case reject the current user.
 // Otherwise create the upload directory:

    $dirpath = $uploadpath . "/" . $institution . "/" . $dirname;
    if (file_exists($dirpath)) {
       if (array_key_exists($dirname,$dirinfo)) {
          if ($dirkey == $odirkey) {
             if ($dirkey == "") {
                $errmsg = "Directory $dirname already exists";
             } else {
             $errmsg = "Directory $dirname already exists with the directory key you asked for";
             }
          } else {
             $errmsg = "Directory key for directory $dirname updated";
             $update_dirinfo_needed = TRUE;
          }
          $newdirname = "";
       } else {
          $errmsg = "Directory $dirname already used by another user";
          $error = 1;
       }
       $nextpage = 3;
    } elseif (count(glob($uploadpath . "/*/" . $dirname)) > 0) {
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
       $errmsg = "Directory $dirname successfully created";
       $newdirname = "";
       $update_dirinfo_needed = TRUE;
       $nextpage = 3;
    }
    mmPutTest("BTN_creupd_dir.php: Check on uploadpath = $dirpath finished. Errmsg: $errmsg");
}
 if ($error == 0) {
 // If new directory, or any directory information has changed, update the user file in
 // the webrun/u1 directory:

    if ($update_dirinfo_needed) {
       if (! array_key_exists($dirname,$dirinfo)) {
          $dirinfo[$dirname] = array();
       }
       if (isset($ndirkey)) {
          $dirinfo[$dirname]['DSKEY'] = $ndirkey;
       }
       if (isset($nlocation) && isset($nthreddscatalog)) {
          $dirinfo[$dirname]['LOCATION'] = $nlocation;
          $dirinfo[$dirname]['CATALOG'] = $nthreddscatalog;
       }
       if (isset($nwmsurl)) {
          $dirinfo[$dirname]['WMS_URL'] = $nwmsurl;
       }
       if (! update_dirinfo(decodenorm($normemail),$dirname,$dirinfo[$dirname]) ) {
          mmPutLog('Could not update the user database with dir info.');
          $errmsg = 'Sorry. Internal error';
          $error = 2;
          $nextpage = 1;
       } else {
          if ($external_repository) {
             $errmsg = "Registration of directory $dirname accepted";
             $newdirname = "";
             $nextpage = 3;
          }
       }
       if ($error == 0 && $external_repository && $threddscatalog != $othreddscatalog) {
       // The user has changed the THREDDS catalog URL. This change must be propagated to the
       // XML metadata files for the directory and file level datasets:
          $application_id = $mmConfig->getVar("APPLICATION_ID");
          $datasetpath = "$runpath/XML/$application_id/$dirname";
          $file_found_and_dataset_ok = FALSE;
          if (file_exists($datasetpath . ".xmd")) {
             try {
                $dataset = new MM_Dataset($datasetpath . ".xmd");
                $file_found_and_dataset_ok = TRUE;
             } catch (MM_DatasetException $mde) {
                $errmsg .= "Sorry, internal error";
                $nextpage = 1;
                $error = 2;
                mmPutLog("BTN_creupd_dir.php: Error on reading dataset $datasetpath: ". $mde->getMessage());
                $file_found_and_dataset_ok = FALSE;
             }
          }
          if ($file_found_and_dataset_ok) {
             $newmetadata = array();
             //
             // This complex string manipulation is documented by using example strings with
             // assumed values:
             // Assume: $threddscatalog == 'http://thredds/catalog/catalog.html?dataset=dir'
             // Assume: $othreddscatalog == 'http://thredds/aaa/catalog.html?dataset=ooo'
             mmPutTest("BTN_creupd_dir.php: threddscatalog: $threddscatalog");
             mmPutTest("BTN_creupd_dir.php: othreddscatalog: $othreddscatalog");
             $j1 = strpos($threddscatalog,'?');
             $directory_dataref = substr($threddscatalog,0,$j1);
             // $directory_dataref == 'http://thredds/catalog/catalog.html'
             mmPutTest("BTN_creupd_dir.php: directory_dataref: $directory_dataref");
             $j1 = strpos($othreddscatalog,'?');
             $old_directory_dataref = substr($othreddscatalog,0,$j1);
             // $old_directory_dataref == 'http://thredds/aaa/catalog.html'
             mmPutTest("BTN_creupd_dir.php: old_directory_dataref: $old_directory_dataref");
             $j1 = strpos($othreddscatalog,'=');
             $initial_path_after_equal = substr($othreddscatalog,$j1+1) . '/';
             // $initial_path_after_equal == 'ooo/'
             mmPutTest("BTN_creupd_dir.php: initial_path_after_equal: $initial_path_after_equal");
             $newmetadata['dataref'] = array($directory_dataref);
             try {
                $dataset->removeMetadata(array_keys($newmetadata));
                $dataset->addMetadata($newmetadata);
                $dataset->write($datasetpath);
             } catch (MM_DatasetException $mde) {
                $errmsg .= "Sorry, internal error";
                $nextpage = 1;
                $error = 2;
                mmPutLog("BTN_creupd_dir.php: Error on writing dataset $datasetpath: ". $mde->getMessage());
             }
          }
          if ( $error == 0 && $file_found_and_dataset_ok) {
             $file_level_datasets = scandir($datasetpath);
             foreach ($file_level_datasets as $file) {
                if (preg_match ('/^(.*)\.xmd$/',$file,$matches)) {
                   $filedatasetpath = $datasetpath . "/" . $matches[1];
                   try {
                      $dataset = new MM_Dataset($filedatasetpath . ".xmd");
                      $metadata = $dataset->getMetadata();
                   } catch (MM_DatasetException $mde) {
                      $errmsg .= "Sorry, internal error";
                      $nextpage = 1;
                      $error = 2;
                      mmPutLog("BTN_creupd_dir.php: Error on reading dataset $filedatasetpath: ". $mde->getMessage());
                      break;
                   }
                   $old_file_dataref = $metadata['dataref'][0];
                   // Assume: $old_file_dataref == 'http://thredds/aaa/b/c/catalog.html?dataset=ooo/b/c/file.nc'
                   mmPutTest("BTN_creupd_dir.php: old_file_dataref: $old_file_dataref");
                   $j1 = strpos($old_file_dataref,'=');
                   $whole_path_after_equal = substr($old_file_dataref,$j1+1);
                   // $whole_path_after_equal == 'ooo/b/c/file.nc'
                   mmPutTest("BTN_creupd_dir.php: whole_path_after_equal: $whole_path_after_equal");
                   $old_filename = str_replace($initial_path_after_equal,"",$whole_path_after_equal);
                   // $old_filename == 'b/c/file.nc'
                   mmPutTest("BTN_creupd_dir.php: old_filename: $old_filename");
                   $j1 = strrpos($old_filename,'/');
                   if ($j1 !== false) {
                      $extra_dirpath = substr($old_filename,0,$j1+1);
                   } else {
                      $extra_dirpath = "";
                   }
                   // $extra_dirpath == 'b/c/'
                   mmPutTest("BTN_creupd_dir.php: extra_dirpath: $extra_dirpath");
                   $new_file_dataref = str_replace('catalog.html?',$extra_dirpath . 'catalog.html?',$threddscatalog);
                   // $new_file_dataref == 'http://thredds/catalog/b/c/catalog.html?dataset=dir'
                   $new_file_dataref .= '/' . $old_filename;
                   // $new_file_dataref == 'http://thredds/catalog/b/c/catalog.html?dataset=dir/b/c/file.nc'
                   mmPutTest("BTN_creupd_dir.php: new_file_dataref: $new_file_dataref");
                   $newmetadata['dataref'] = array($new_file_dataref);
                   try {
                      $dataset->removeMetadata(array_keys($newmetadata));
                      $dataset->addMetadata($newmetadata);
                      $dataset->write($filedatasetpath);
                   } catch (MM_DatasetException $mde) {
                       $errmsg .= "Sorry, internal error";
                       $nextpage = 1;
                       $error = 2;
                       mmPutLog("BTN_creupd_dir.php: Error on writing dataset $filedatasetpath: ". $mde->getMessage());
                       break;
                   }
                }
             }
          }
       }
       mmPutTest("BTN_creupd_dir.php: update dirinfo finished. Errmsg: $errmsg");
    }
 }
 $dirname = $newdirname;
 if (strlen($dirname) == 0) {
 // Empty fields:

    $dirkey = "";
    if (isset($location) && isset($threddscatalog)) {
       $location = "";
       $threddscatalog = "";
    }
    if (isset($wmsurl)) {
       $wmsurl = "";
    }
 }
?>
