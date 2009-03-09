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
#-----------------------------------------------------------------------------
#   The main page in the search web application.
#   ============================================
#
#   All pages presented to the user are generated through this file.
#
#-----------------------------------------------------------------------------
#   All functions and object classes used in the application are contained in
#   the following file:
#
   include_once "functions.inc";
#
#-----------------------------------------------------------------------------
#   Turn on output buffering. If any errors occur, $mmError will be set to 1,
#   and an error message (stored in $mmErrorMessage) will be sent to the user
#   and not the output buffer.
#-----------------------------------------------------------------------------
#
   ini_set("track_errors",1);
   $logfile = mmGetRunPath() . '/phplog';
   ini_set("error_log",$logfile);
   ini_set("log_errors",1);
   ini_set("display_errors",1);
   ob_start();
   $mmError = 0;
   $mmErrorMessage = "Error"; # Just to have some error text if this variable
                              # is not othervise set.
#
#  Debug option: Set the $mmDebug value to a blank-separated string of debug options:
#  $mmDebug="POST GET mmColumns options mmSessionState mmSubmitButton getdslist"
#  If no debug, set $mmDebug to the empty string.
#
   $mmDebug = "";
#
#  Initialize the mmButtons array:
#
   $mmButtons = array( "index"    => array("",              "presentation.php","NOFORM"),
                       "show"     => array("",              "doshow.php",      "NOFORM"),
                       "showex"   => array("showdone.php",  "doshow.php",      "NOFORM"),
                       "options"  => array("",              "dooptions.php",   "FORM"),
                       "optsdone" => array("optsdone.php",  "current",         "NOFORM"),
                       "cross"    => array("",              "docross.php",     "NOFORM"),
                       "help"     => array("",              "dohelp.php",      "NOFORM"),
                       "bk"       => array("",              "bk.php",          "FORM"),
                       "bkdone"   => array("bkdone.php",    "current",         "NOFORM"),
                       "bkclear"  => array("bkclear.php",   "current",         "NOFORM"),
                       "hkstart"  => array("",              "hk.php",          "FORM"),
                       "hkdone"   => array("hkdone.php",    "current",         "NOFORM"),
                       "hkclear"  => array("hkclear.php",   "current",         "NOFORM"),
                       "hk"       => array("hkupdate.php",  "hk.php",          "FORM"),
                       "ni"       => array("",              "ni.php",          "FORM"),
                       "nidone"   => array("nidone.php",    "current",         "NOFORM"),
                       "niremove" => array("niremove.php",  "current",         "NOFORM"),
                       "ga"       => array("",              "ga.php",          "FORM"),
                       "gaget"    => array("gaupdate.php",  "ga.php",          "FORM"),
                       "garemove" => array("garemove.php",  "current",         "NOFORM"),
                       "gadone"   => array("gadone.php",    "current",         "NOFORM")
                     );
#
#  Initialize the mmColumns array:
#
   $s1 = <<<END_OF_STRING
[==SEARCH_APP_SHOW_COLUMNS==]
END_OF_STRING;
   mmCreate_mmColumns($s1);
   if (strpos($mmDebug,"mmColumns") !== false) {
      echo "<pre>\nmmColumns ---------\n";
      print_r($mmColumns);
      echo "</pre>\n";
   }
?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
   <title>[==SEARCH_APP_TITLE==]</title>
   <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
   <link href="style.css" rel="stylesheet" type="text/css" />
   <link href="[==LOCAL_URL==]/style.css" rel="stylesheet" type="text/css" />
</head>
<body>
<?php
if (strpos($mmDebug,"POST") !== false) {
#
#  DEBUG: List all POST variables: 
#
   echo '========= POST-variables =========<BR />';
   while (list($key, $var) = each ($_POST)) {
      echo $key. '=>' .$var. "<BR />\n";
   }
   echo '==================================<BR />';
}
if (strpos($mmDebug,"GET") !== false) {
#
#  DEBUG: List all GET variables: 
#
   echo '========= GET-variables =========<BR />';
   while (list($key, $var) = each ($_GET)) {
      echo $key. '=>' .$var. "<BR />\n";
   }
   echo '==================================<BR />';
}

   $mmDbConnection = @pg_Connect ("dbname=[==DATABASE_NAME==] user=[==PG_WEB_USER==] [==PG_CONNECTSTRING_PHP==]");
   if ( !$mmDbConnection ) {
       mmPutLog("Error. Could not connect to database: $php_errormsg");
       $mmErrorMessage = "Error: Could not connect to database";
       $mmError = 1;
   } else {
#
#  Include updsession.php for processing user input (through POST and GET data) and
#  for updating the session state accordingly. This file do not normally generate 
#  any HTML output.
#
      include "updsession.php";
#
      if ($mmError == 0) {
         if (strpos($mmDebug,"options") !== false) {
            echo "<pre>\n";
            print_r($mmSessionState->options);
            echo "</pre>\n";
         }
#
#  DEBUG: List all key - value pairs in the $mmSessionState object: 
#
         if (isset($mmSessionState) && strpos($mmDebug,"mmSessionState") !== false) {
	    echo "<P>mmSessionState:<BR>\n";
	    $a1 = get_object_vars ($mmSessionState);
            while (list($key, $var) = each ($a1)) {
	       if (is_array($var)) {
                  foreach ($var as $k1 => $v1) {
                     if (is_array($v1)) {
                        foreach ($v1 as $k2 => $v2) {
                           if (is_array($v2)) {
	                      $s2 = implode(', ',$v2);
                              echo $key. '=>' .$k1. '=>' .$k2. '=>(' .$s2. ")<BR>\n";
                           } else {
                              echo $key. '=>' .$k1. '=>' .$k2. '=>' .$v2. "<BR>\n";
                           }
                        }
                     } else {
                        echo $key. '=>' .$k1. '=>' .$v1. "<BR>\n";
                     }
                  }
	       } else {
                  echo $key. '=>' .$var. "<BR>\n";
	       }
            }
         }
#
#  Include normal.php for presenting a new HTML page to the user:
#
         include "normal.php";
      }
   }
?>
</body>
</html>
<?php
   if ($mmError == 1) {
      if ($mmDebug == "") {
         mmEndSession();
         ob_end_clean();
         include "normal.php";
      } else {
         echo '<p>' . $mmErrorMessage . '</p>' . "\n";
         ob_end_flush();
      }
   } else {
      ob_end_flush();
   }
?>
