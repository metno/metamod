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
   mail($emailadr, "Access to $appName file upload service",$content, "From: ".$mmConfig->getVar('FROM_ADDRESS'));
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
   if ($debug) {
      mmPutTest("get_userinfo:");
   }
   $userinfo = array();
   if (preg_match('/\.([^\.]+)$/',$filepath,$matches) == 1) {
      $userinfo["paw"] = decodenorm($matches[1]);
   }
   $content = file_get_contents($filepath);
   if (preg_match('/<heading[^>]*>/',$content,$matches) == 1) {
      if (preg_match_all('/\w+="\w*"/',$matches[0],$matches1) >= 1) {
         foreach ($matches1[0] as $match) {
            if (preg_match('/(\w+)="(\w*)"/',$match,$matches2) == 1) {
               $userinfo[$matches2[1]] = decodenorm($matches2[2]);
	       if ($debug) {
	          mmPutTest($matches2[1] . "=" . $userinfo[$matches2[1]]);
	       }
            }
         }
      }
   }
   return $userinfo;
}

function get_fileinfo($filepath)
{
   global $debug;
   if ($debug) {
      mmPutTest("get_fileinfo:");
   }
   $fileinfo = array();
   if (!file_exists($filepath)) {
      return FALSE;
   }
   $lines = file($filepath);
   if ($lines == FALSE) {
      return FALSE;
   }
   $filerecords = preg_grep(':<file\b[^>]+/>:',$lines);
   $ix = 0;
   foreach ($filerecords as $filerec) {
      $onefile = array();
      if (preg_match_all('/\w+="[^"]*"/',$filerec,$matches) >= 1) {
         foreach ($matches[0] as $match) {
            if (preg_match('/(\w+)="([^"]*)"/',$match,$matches2) == 1) {
               $onefile[$matches2[1]] = $matches2[2];
	       if ($debug) {
	          mmPutTest($matches2[1] . '=' . $onefile[$matches2[1]]);
	       }
            }
         }
      }
      $fileinfo[$ix++] = $onefile;
   }
   return $fileinfo;
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

function put_dirinfo($filepath,$dirinfo)
{
   // Substitutes all lines containing <dir> tags in the XML file
   // given by $filepath with <dir> tag lines constructed from the
   // $dirinfo array. All other lines in the XML file are left unchanged.
   $dirrecords = array();
   $lines = file($filepath);
   array_push($lines,"DUMMY\n");
   $newcontent = '';
   $found_heading = FALSE;
   foreach ($lines as $line) {
      if (preg_match (':<dir\b[^>]+/>:',$line)) {
         // Do nothing
      } else if (preg_match (':<heading\b[^>]+/>:',$line)) {
         $found_heading = TRUE;
         $newcontent .= $line;
      } else {
         if ($found_heading) {
            foreach ($dirinfo as $dirname => $ndirkey) {
               $fline = '<dir dirname="' . $dirname .'" key="' . $ndirkey . '" />';
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

function get_dirinfo($filepath)
{
   global $debug;
   if ($debug) {
      mmPutTest("get_dirinfo:");
   }
   $dirinfo = array();
   if (!file_exists($filepath)) {
      mmPutTest("get_dirinfo returns FALSE");
      return FALSE;
   }
   $lines = file($filepath);
   if ($lines == FALSE) {
      mmPutTest("get_dirinfo returns FALSE");
      return FALSE;
   }
   $dirrecords = preg_grep(':<dir\b[^>]+/>:',$lines);
   foreach ($dirrecords as $dirrec) {
      if (preg_match('/dirname="([^"]+)" key="([^"]*)"/',$dirrec,$matches2) == 1) {
         $dirinfo[$matches2[1]] = $matches2[2];
         if ($debug) {
            mmPutTest($matches2[1] . '=' . $dirinfo[$matches2[1]]);
         }
      }
   }
   return $dirinfo;
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
   $parts = explode('.',$filename);
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
   if ($mmConfig->getVar('DECODE_FROM_UTF8')) {
      return utf8_decode($string);
   } else {
      return $string;
   }
}
?>
