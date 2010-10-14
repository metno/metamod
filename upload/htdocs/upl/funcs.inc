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

function check_credentials()
{
   global $error, $errmsg, $nextpage, $normemail, $sessioncode, $runpath, $filepath,
          $filecontent, $debug, $dirinfo;
   $error = 0;
   if (!array_key_exists("normemail", $_POST) || !array_key_exists("sessioncode", $_POST)) {
      mmPutLog('Keys "normemail" or "sessioncode" not found in $_POST');
      $errmsg = 'Sorry. Internal error';
      $error = 1;
      $nextpage = 1;
   }
   if ($error == 0) { // Get existing file info from the user file
      $normemail = conditional_decode($_POST["normemail"]);
      $sessioncode = conditional_decode($_POST["sessioncode"]);
      $runpath = mmGetRunPath();
      $filepath = $runpath . '/u2/' . $normemail . '.' . $sessioncode;
      $filecontent = get_fileinfo($filepath);
      if (is_bool($filecontent) && $filecontent == FALSE) {
         mmPutLog("Function get_fileinfo returned FALSE");
         $errmsg = 'Sorry, no active user session. You have to log in again.';
         $error = 1;
         $nextpage = 1;
      } else {
         $dirinfo = get_dirinfo($filepath);
         if (is_bool($dirinfo) && $dirinfo == FALSE) {
            mmPutLog("Function get_dirinfo returned FALSE");
            $error = 1;
            $nextpage = 1;
            $errmsg = "Sorry, internal error";
         }
      }
   }
}

function file_put_contents1($filepath,$string)
{
# Implementation of system routine 'file_put_contents' to appear in PHP 5
   $f1 = fopen($filepath,'wb');
   if ($f1 == FALSE) {
      return FALSE;
   }
   fwrite($f1,$string);
   fclose($f1);
   return TRUE;

}

function normstring($strn)
{
   if (strlen($strn) > 0) {
      $new = "";
      $a1 = preg_split('//',trim($strn),-1,PREG_SPLIT_NO_EMPTY);
      foreach ($a1 as $ch1) {
         if (preg_match ('/[a-zG-Z]/',$ch1)) {
            $new .= $ch1;
         } else {
            $new .= strtoupper(bin2hex($ch1));
         }
      }
      return $new;
   } else {
      return '';
   }
}

function decodenorm($strn)
{
   if (strlen($strn) > 0) {
      $new = "";
      $numchar = "";
      $a1 = preg_split('//',trim($strn),-1,PREG_SPLIT_NO_EMPTY);
      foreach ($a1 as $ch1) {
         if (preg_match ('/[0-9A-F]/',$ch1)) {
            $numchar .= $ch1;
            if (strlen($numchar) == 2) {
               eval('$new .= chr(0x' . $numchar . ');');
               $numchar = '';
            }
         } else {
            $new .= $ch1;
            $numchar = '';
         }
      }
      return $new;
   } else {
      return '';
   }
}

function validate_absurl($url)
{
   $url_regexp = '!^https?://\w+(\.\w+)+(:\d+)?/[a-zA-Z0-9="&_.?/-]+$!';
   if (preg_match($url_regexp,$url)) {
      return true;
   } else {
      return false;
   }
}

function validate_abspath($path)
{
   $path_regexp = '!^/[a-zA-Z0-9/_.-]+$!';
   if (preg_match($path_regexp,$path)) {
      return true;
   } else {
      return false;
   }
}

function normfilename($strn)
{
   if (strlen($strn) > 0) {
      $new = "";
      $a1 = preg_split('//',trim($strn),-1,PREG_SPLIT_NO_EMPTY);
      foreach ($a1 as $ch1) {
         if (preg_match ('/[a-zA-Z0-9_.]/',$ch1)) {
            $new .= $ch1;
         } else {
            $new .= 'x';
         }
      }
      return $new;
   } else {
      return '';
   }
}

function mkpasswd()
{
   $charr = array('q','x','p','t','r','y','m','g','Q','X','P','T','R','Y','M','G','1','2','3','4','5','6','7','8','9');
   $paw = '';
   for ($i1=0; $i1 < 5; $i1++) {
      $paw .= $charr[rand(0,23)];
   }
   return $paw;
}

function send_welcome_mail($name,$emailadr,$paw)
{
	global $mmConfig;
	$appName = $mmConfig->getVar('APPLICATION_NAME');
	$signature = $mmConfig->getVar('EMAIL_SIGNATURE');
   $content = <<<END_TEXT
Dear $name,

Welcome to the $appName file upload service. Your initial password
for logging into this service will be: $paw
 
You may change the password when logging into the service, as long
as you initially provide the password given here.

$signature
END_TEXT;
   mail($emailadr,
        "Access to $appName file upload service",
        $content,
#        "From: ".$mmConfig->getVar('FROM_ADDRESS') . "\r\n" . 'Content-Type: text/plain; charset="utf-8"'
        "From: ".$mmConfig->getVar('FROM_ADDRESS')
       );
}

function mmGetRunPath () {
	global $mmConfig;
   return $mmConfig->getVar('WEBRUN_DIRECTORY');
}

function mmPutLog($string) {
   $logfile = mmGetRunPath() . '/userlog';
   $fd = fopen($logfile,"a");
   fwrite($fd,date("Y-m-d H:i: ") . $string . "\n");
   fflush($fd);
   fclose($fd);
}

function mmPutTest($string) {
   global $debug;
   if ($debug) {
      $logfile = mmGetRunPath() . '/testlog';
      $fd = fopen($logfile,"a");
      fwrite($fd,date("Y-m-d H:i: ") . $string . "\n");
      fflush($fd);
      fclose($fd);
   }
}


function create_directory($path)
{
   if (file_exists($path)) {
      return true;
   } else {
      if (@mkdir($path)) {
         return true;
      } else {
         $path1 = preg_replace(':/[^/]*$:','',$path);
         if ($path1 != $path) {
            if (! create_directory($path1)) {
               return false;
            } else {
               return mkdir($path);
            }
         } else {
            return false;
         }
      }
   }
}

function get_userinfo($filepath)
{
   // Returns an array $userinfo that has the attribute names in the heading tag
   // as keys, and the corresponding attribute values as values.
   // The first heading (and supposedly only) tag in the file will be used.
   global $debug;
   global $mmConfig;
   $error = 0;
   if ($debug) {
      mmPutTest("get_userinfo:");
   }
   $userinfo = array();
   $parts = explode(".",basename($filepath));
   $email_address =  utf8_encode(decodenorm($parts[0]));
   $application_id = $mmConfig->getVar('APPLICATION_ID');
   $userbase = new MM_Userbase();
   $user_properties = array('u_name', 'u_password', 'u_loginname', 'u_institution', 'u_telephone', 'u_session');
   if ($userbase->user_find($email_address, $application_id) === FALSE) {
      if ($userbase->exception_is_error()) {
         mmPutLog($userbase->get_exception());
      } else {
         mmPutLog("ERROR: User $email_address not found in User database");
      }
      $error = 1;
   }
   if ($error == 0) {
      reset($user_properties);
      foreach ($user_properties as $property) {
         $value = $userbase->user_get($property);
         if ($value === FALSE) {
            if ($userbase->exception_is_error()) {
               mmPutLog($userbase->get_exception());
               $error = 1;
            }
         } else {
            $userinfo[$property] = $value;
         }
      }
      $userinfo['u_email'] = $email_address;
   }
   if ($userbase->close() === FALSE) {;
      mmPutLog($userbase->get_exception());
      $error = 1;
   }
   if ($error == 1) {
      return FALSE;
   } else {
      return $userinfo;
   }
}

function put_userinfo($userinfo)
{
   // Adds a new entry into the UserTable database table in the User database.
   // IN: An array $userinfo that has the column names in the UserTable table
   // as keys, and the corresponding column values as values.
   global $debug;
   global $mmConfig;
   $error = 0;
   if ($debug) {
      mmPutTest("put_userinfo:");
   }
   $email_address = $userinfo["u_email"];
   $application_id = $mmConfig->getVar('APPLICATION_ID');
   $userbase = new MM_Userbase();
   if ($userbase->user_find($email_address, $application_id) === FALSE) {
      if ($userbase->exception_is_error()) {
         mmPutLog($userbase->get_exception());
         $error = 1;
      } else {
         if ($userbase->user_create($email_address, $application_id) === FALSE) {
            mmPutLog($userbase->get_exception());
            $error = 1;
         }
      }
   }
   if ($error == 0) {
      reset($userinfo);
      foreach ($userinfo as $property => $value) {
         if ($property != 'u_email') {
            mmPutTest("put_userinfo: About to user_put( $property , $value )");
            if ($userbase->user_put($property,$value) === FALSE) {
               if ($userbase->exception_is_error()) {
                  mmPutLog($userbase->get_exception());
                  $error = 1;
               }
            }
         }
      }
   }
   if ($userbase->close() === FALSE) {;
      mmPutLog($userbase->get_exception());
      $error = 1;
   }
   if ($error == 1) {
      return FALSE;
   } else {
      return TRUE;
   }
}

function get_fileinfo($filepath)
{
#
#   Returns an array, $fileinfo, containing info about each file uploaded by the user
#   whose E-mail address is encoded in $filepath. Each element in this array is another
#   array with keys equal to field names in the File table in the User database, and values
#   equal to the cooresponding values found in a row in the database. The rows in $fileinfo
#   is sorted in descending order of the f_timestamp field. 
#
   global $debug;
   global $mmConfig;
   $error = 0;
#   if ($debug) {
#      mmPutTest("get_fileinfo:");
#   }
   $fileinfo = array();
   if (!file_exists($filepath)) {
      return FALSE;
   }
   echo "filepath=" . $filepath . "\n";
   $parts = explode(".",basename($filepath));
   $email_address =  utf8_encode(decodenorm($parts[0]));
   echo "email_address=" . $email_address . "\n";
   $application_id = $mmConfig->getVar('APPLICATION_ID');
   $userbase = new MM_Userbase();
   $file_properties = array('f_name', 'f_timestamp', 'f_size', 'f_status', 'f_errurl');
   mmPutTest("get_fileinfo:: About to user_find( $email_address, $application_id ):");
   if ($userbase->user_find($email_address, $application_id) === FALSE) {
      if ($userbase->exception_is_error()) {
         mmPutLog($userbase->get_exception());
      } else {
         mmPutLog("ERROR: User $email_address not found in User database");
      }
      $error = 1;
   }
   if ($error == 0) {
       mmPutTest("get_fileinfo:: About to file_first():");
       if ($userbase->file_first() === FALSE) { # No files or error
          if ($userbase->exception_is_error()) {
             mmPutLog($userbase->get_exception());
             $error = 1;
          }
       } else {
          mmPutTest("get_fileinfo:: About to loop over all files");
          do {
             $onefile = array();
             reset($file_properties);
             foreach ($file_properties as $property) {
                $value = $userbase->file_get($property);
                if ($value === FALSE) {
                   mmPutLog($userbase->get_exception());
                } else if ($value != "") {
                   $onefile[$property] = $value;
                }
             }
             array_unshift($fileinfo,$onefile);
          } while ($userbase->file_next() === TRUE);
          if ($userbase->exception_is_error()) {
             mmPutLog($userbase->get_exception());
             $error = 1;
          }
       }
   }
   if ($userbase->close() === FALSE) {;
      mmPutLog($userbase->get_exception());
      $error = 1;
   }
   if ($error == 1) {
      mmPutTest("get_fileinfo:: About to return FALSE");
      return FALSE;
   } else {
      mmPutTest("get_fileinfo:: About to return fileinfo");
      return $fileinfo;
   }
}

function update_fileinfo($filepath,$existingname,$origname,$size)
{
   # Update info about the uploaded file in the User database. If $existingname != "", the
   # file has been uploaded before, and the file name may have changed. If $existingname is
   # empty, a new file has been uploaded, and a new file entry must be created in the User
   # database.
   #
   global $mmConfig;
   if (!file_exists($filepath)) {
      return FALSE;
   }
   $error = 0;
   $parts = explode(".",basename($filepath));
   $email_address =  utf8_encode(decodenorm($parts[0]));
   $application_id = $mmConfig->getVar('APPLICATION_ID');
   $userbase = new MM_Userbase();
   mmPutTest("update_fileinfo: About to user_find $email_address, $application_id");
   if ($userbase->user_find($email_address, $application_id) === FALSE) {
      if ($userbase->exception_is_error()) {
         mmPutLog($userbase->get_exception());
      } else {
         mmPutLog("ERROR: User $email_address not found in User database");
      }
      $error = 1;
   }
   if ($error == 0 and $existingname != "" and $existingname != $origname) {
      mmPutTest("update_fileinfo: About to file_find existingname: $existingname");
      if ($userbase->file_find($existingname) === FALSE) {
         if ($userbase->exception_is_error()) {
            mmPutLog($userbase->get_exception());
            $error = 1;
         }
      } else {
         mmPutTest("update_fileinfo: About to file_delete()");
         if ($userbase->file_delete() === FALSE) {
             mmPutLog($userbase->get_exception());
             $error = 1;
         }
      }
   }
   if ($error == 0 and $existingname == $origname) {
      mmPutTest("update_fileinfo: About to file_find origname: $origname");
      if ($userbase->file_find($origname) === FALSE) {
         mmPutLog($userbase->get_exception());
         $error = 1;
      }
   } else if ($error == 0) {
      mmPutTest("update_fileinfo: About to file_create origname: $origname");
      if ($userbase->file_create($origname) === FALSE) {
         mmPutLog($userbase->get_exception());
         $error = 1;
      }
      $status = "Initial upload " . gmdate('Y-m-d H:i') . ' UTC';
   }
   if ($existingname != "") {
      $status = "Repeated upload " . gmdate('Y-m-d H:i') . ' UTC';
   }
   if ($error == 0) {
      mmPutTest("update_fileinfo: About to file_put f_size $size");
      if ($userbase->file_put('f_size',$size) === FALSE) {
         mmPutLog($userbase->get_exception());
         $error = 1;
      }
      mmPutTest("update_fileinfo: About to file_put f_status $status");
      if ($userbase->file_put('f_status',$status) === FALSE) {
         mmPutLog($userbase->get_exception());
         $error = 1;
      }
   }
   mmPutTest("update_fileinfo: About to close()");
   if ($userbase->close() === FALSE) {;
      mmPutLog($userbase->get_exception());
      $error = 1;
   }
   if ($error == 1) {
      mmPutTest("update_fileinfo: About to return FALSE");
      return FALSE;
   } else {
      mmPutTest("update_fileinfo: About to return TRUE");
      return TRUE;
   }
}

function put_fileinfo($filepath,$fileinfo)
{
   // Substitutes all lines containing <file> tags in the XML file
   // given by $filepath with <file> tag lines constructed from the
   // $fileinfo array. All other lines in the XML file are left unchanged.
   $filerecords = array();
   $lines = file($filepath);
   array_push($lines,"DUMMY\n");
   $newcontent = '';
   $found_heading = FALSE;
   foreach ($lines as $line) {
      if (preg_match (':<file\b[^>]+/>:',$line)) {
         // Do nothing
      } else if (preg_match (':<heading\b[^>]+/>:',$line)) {
         $found_heading = TRUE;
         $newcontent .= $line;
      } else {
         if ($found_heading) {
            foreach ($fileinfo as $filerec) {
               $fline = '<file ';
               foreach ($filerec as $key => $value) {
                  $fline .= $key . '="' . $value . '" ';
               }
               $fline .= '/>';
               $newcontent .= $fline . "\n";
            }
            $found_heading = FALSE;
         } 
         if ($line != "DUMMY\n") {
            $newcontent .= $line;
         }
      }
   }
   $result = file_put_contents1($filepath,$newcontent);
   return $result;
}

function update_dirinfo($email,$dirname,$info)
{
   global $mmConfig;
   $ok_to_now = TRUE;
   $application_id = $mmConfig->getVar('APPLICATION_ID');
   $userbase = new MM_Userbase();
   if ($userbase->dset_find($application_id, $dirname) === FALSE) {
      if ($userbase->exception_is_error()) {
         mmPutLog($userbase->get_exception());
         $ok_to_now = FALSE;
      } else {
         if ($userbase->user_find($email,$application_id) === FALSE) {
             mmPutLog($userbase->get_exception());
             $ok_to_now = FALSE;
         } else if ($userbase->dset_create($dirname, $info["DSKEY"]) === FALSE) {
             mmPutLog($userbase->get_exception());
             $ok_to_now = FALSE;
         }
      }
   }
   reset($info);
   foreach ($info as $key => $value) {
       if ($ok_to_now) {
           if ($userbase->dset_put($key,$value) === FALSE and $userbase->exception_is_error()) {
              mmPutLog($userbase->get_exception());
              $ok_to_now = FALSE;
           }
       }
   }
   if ($userbase->close() === FALSE) {;
      mmPutLog($userbase->get_exception());
      $ok_to_now = FALSE;
   }
   return $ok_to_now;
}

function get_dirinfo($filepath)
{
   global $debug, $mmConfig;
   $error = 0;
#   if ($debug) {
#      mmPutTest("get_dirinfo:");
#   }
   $dirinfo = array();
   $parts = explode(".",basename($filepath));
   $email_address =  utf8_encode(decodenorm($parts[0]));
   $application_id = $mmConfig->getVar('APPLICATION_ID');
   $userbase = new MM_Userbase();
   $dset_properties = array('DSKEY','LOCATION','CATALOG','WMS_URL','WMS_XML');
   if ($userbase->user_find($email_address, $application_id) === FALSE) {
      if ($userbase->exception_is_error()) {
         mmPutLog($userbase->get_exception());
      } else {
         mmPutLog("ERROR: User $email_address not found in User database");
      }
      $error = 1;
   }
   if ($error == 0) {
      if ($userbase->dset_first() === FALSE) { # No datasets or error
         if ($userbase->exception_is_error()) {
            mmPutLog($userbase->get_exception());
            $error = 1;
         }
      } else {
         do {
            $dsname = $userbase->dset_get('ds_name');
            $dirinfo[$dsname] = array();
            if ($dsname === FALSE) {
               mmPutLog($userbase->get_exception());
               $error = 1;
            }
            reset($dset_properties);
            foreach ($dset_properties as $property) {
               $value = $userbase->dset_get($property);
               if ($value === FALSE) {
                  if ($userbase->exception_is_error()) {
                     mmPutLog($userbase->get_exception());
                     $error = 1;
                  }
               } else if ($value != "") {
                  $dirinfo[$dsname][$property] = $value;
               }
            }
         } while ($userbase->dset_next() === TRUE);
         if ($userbase->exception_is_error()) {
            mmPutLog($userbase->get_exception());
            $error = 1;
         }
      }
   }
   if ($userbase->close() === FALSE) {;
      mmPutLog($userbase->get_exception());
      $error = 1;
   }
   if ($error == 1) {
      return FALSE;
   } else {
      return $dirinfo;
   }
}

function get_unique_filename ($namefile)
{
   $linkname = $namefile . '_lock';
   $max_tries = 10;
   while (!link($namefile,$linkname) && $max_tries > 0) {
      $max_tries--;
      sleep(1);
   }
   if ($max_tries > 0) {
      $prevname = file_get_contents($linkname);
      $today = date('Ymd');
      $pdate = substr($prevname,1,8);
      if ($pdate == $today) {
         $num = substr($prevname,9,3) + 1;
      } else {
         $num = 1;
      }
      $snum = sprintf('%03d',$num);
      $newname = 'f' . $today . $snum;
      if (!file_put_contents1($linkname,$newname)) {
         return FALSE;
      }
      unlink($linkname);
      return $newname;
   } else {
      return FALSE;
   }
}

function get_upload_path()
{
	global $mmConfig;
   return $mmConfig->getVar('UPLOAD_DIRECTORY');
}

function get_repository_path()
{
	global $mmConfig;
   return $mmConfig->getVar('OPENDAP_DIRECTORY');
}

function create_user_session($filename)
{
   // The user may already have an active session. As updates to the user file
   // are sent after each user action, there is no danger closing the existing
   // session and let the user continue with a new session. The user should
   // only have one session active at any time.
   $u1path = mmGetRunPath() . '/u1';
   $u2path = mmGetRunPath() . '/u2';
   $parts = explode(".",$filename);
   $normemail = $parts[0];
   $matching = glob($u2path . '/' . $normemail . '.*'); // An array of all matching links
                                                        // in the u2 directory, each of which
                                                        // represents an existing user session.
   foreach ($matching as $match) { // Remove all existing user sessions for this user:
      echo 'Matching: ' . $match . "<br>\n";
      if (!unlink($match)) {
         return FALSE;
      }
   }

   // Use the mkpasswd routine to create a session code:
   $sessioncode = mkpasswd();

/*
   // Theoretically, this may collide with the former session code. To avoid this:
   while (count(preg_match('/' . $sessioncode . '/', $matching)) > 0) {
      $sessioncode = mkpasswd();
   }
*/
   if (!link($u1path . '/' . $filename,
             $u2path . '/' . $normemail . '.' . $sessioncode)) {
      echo 'Could not link: ' . $u2path . '/' . $normemail . '.' . $sessioncode . "<br>\n";
      echo 'u1path = ' . $u1path . "\n";
      echo 'u2path = ' . $u2path . "\n";
      echo 'filename = ' . $filename . "\n";
      return FALSE;
   }
   return $sessioncode;
}

function get_buttonname()
{
   $matches1 = preg_grep('/^BTN_/',array_keys($_POST));
   if (count($matches1) == 1) {
      $matches2 = array_values($matches1);
      return $matches2[0];
   } else {
      return FALSE;
   }
}

function conditional_decode($string)
{
   global $mmConfig;
   if ($mmConfig->getVar('DECODE_FROM_UTF8') == "TRUE") {
      return utf8_decode($string);
   } else {
      return $string;
   }
}

function get_postvar($varname)
{
   if (array_key_exists($varname,$_POST)) {
      $value = $_POST[$varname];
      if (get_magic_quotes_gpc()) {
         $value = stripslashes($value);
      }
      return $value;
   } else {
      return "";
   }
}

/**
 * Check if the currently active user (set by check_credentials()) is allowed to access a directory
 * @param $directory name of the directory
 * @param $key optional directory key
 * @param $errMsg optional string which will be filled with return message
 * @return institution name if directory belongs to another user, and dataset key is OK. Othervise true for success, false for access-failure
 */
function checkDirectoryPermission($directory, $key = "", &$errMsg = "") {
	global $filepath;
	if (strlen($directory) == 0) {
	   $errMsg .= "no directory given";
	   return false;
	}
   $dirinfo = get_dirinfo($filepath);
   if (array_key_exists($directory, $dirinfo)) {
      // $directory belongs to current user
      return true; 
   }
   if (strlen($key) == 0) {
       $errMsg .= "dataset $directory not found";
       return false;
   }
   	// check all other directories
    $userbase = new MM_Userbase();
    $ok_to_now = true;
    if ($userbase->dset_find($application_id,$directory) === FALSE) {
       if ($userbase->exception_is_error()) {
          mmPutLog($userbase->get_exception());
       }
       $errMsg .= "dataset $directory not found";
       $ok_to_now = false;
    }
    if ($ok_to_now) {
       $dskey = $userbase->dset_get("DSKEY");
       if ($dskey === FALSE) {
          if ($userbase->exception_is_error()) {
             mmPutLog($userbase->get_exception());
          }
          $errMsg .= "key does not match";
          $ok_to_now = false;
       }
       if ($dskey != $key) {
          $errMsg .= "key does not match";
          $ok_to_now = false;
       }
    }
    if ($ok_to_now) {
        if ($userbase->user_dsync() === FALSE) {
            if ($userbase->exception_is_error()) {
                mmPutLog($userbase->get_exception());
            }
            $errMsg .= "internal error";
            $ok_to_now = false;
        }
    }
    if ($ok_to_now) {
        $institution = $userbase->user_get("u_institution");
        if ($institution === FALSE) {
            if ($userbase->exception_is_error()) {
                mmPutLog($userbase->get_exception());
            }
            $errMsg .= "internal error";
            $ok_to_now = false;
        }
    }
    if ($userbase->close() === FALSE) {;
       mmPutLog($userbase->get_exception());
       $ok_to_now = FALSE;
    }
    if ($ok_to_now) {
       return $institution;
    } else {
       return false;
    }
}
function changePassword($filepath,$newpassword) {
    global $mmConfig;
    $normpasswd = normstring($newpassword);
    $parts = explode(".",basename($filepath));
    $normemail = $parts[0];
    $newfilepath = dirname($filepath) . '/' . $normemail . '.' . $normpasswd;
    if (!rename($filepath,$newfilepath)) {
       mmPutLog("Function rename returned FALSE. $filepath -> $newfilepath");
       return FALSE;
    }
    $email_address =  decodenorm($normemail);
    $application_id = $mmConfig->getVar('APPLICATION_ID');
    $userbase = new MM_Userbase();
    if ($userbase->user_find($email_address, $application_id) === FALSE) {
       if ($userbase->exception_is_error()) {
          mmPutLog($userbase->get_exception());
       } else {
          mmPutLog("ERROR: User $email_address not found in User database");
       }
    } else {
        if ($userbase->user_put('u_password',$newpassword) === FALSE) {
           mmPutLog($userbase->get_exception());
        }
    }
    if ($userbase->close() === FALSE) {;
       mmPutLog($userbase->get_exception());
    }
    return TRUE;
}
?>
