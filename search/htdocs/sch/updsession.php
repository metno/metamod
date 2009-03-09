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
if (isset($_POST['mmSubmitButton'])) {
   $mmSubmitButton = $_POST['mmSubmitButton'];
} elseif (isset($_GET['mmSubmitButton'])) {
   $mmSubmitButton = $_GET['mmSubmitButton'];
} else {
   $submitbtn = preg_grep('/^mmSubmitButton_/',array_keys($_POST));
#   print_r($submitbtn);
   if (count($submitbtn) == 1) {
      foreach ($submitbtn as $val) {
         if (preg_match ('/^mmSubmitButton_(.*)$/',$val,$matches)) {
            $mmSubmitButton = $matches[1];
         }
      }
   }
}
if (isset($_POST['mmSessionId'])) {
   $mmSessionId = $_POST['mmSessionId'];
} elseif (isset($_GET['mmSessionId'])) {
   $mmSessionId = $_GET['mmSessionId'];
}
if (!isset($mmSessionId)) {
   $msg_start = "Your attempt to enter [==SEARCH_APP_NAME==] did not succeed. ";
} else {
   $msg_start = "Your previous session was terminated because of: ";
}
$timeofday = gettimeofday ();
$timeof_idle_reject = $timeofday['sec'] - 60*60*24;
$sqlsentence = "DELETE FROM Sessions WHERE CAST(accesstime AS INTEGER) < $timeof_idle_reject";
$result = pg_query ($mmDbConnection, $sqlsentence);
if (!$result) {
   mmPutLog(__FILE__ . __LINE__ . " Could not $sqlsentence");
   $mmErrorMessage = $msg_start . "Database error";
   $mmError = 1;
}
if ($mmError == 0) {
#
#  Remove images in directory ./maps that are no longer in use:
#
   $sqlsentence = "SELECT sessionid FROM Sessions";
   $result = pg_query ($mmDbConnection, $sqlsentence);
   if (!$result) {
      mmPutLog(__FILE__ . __LINE__ . " Could not $sqlsentence");
      $mmErrorMessage = $msg_start . "Database error";
      $mmError = 1;
   } else {
      $num = pg_numrows($result);
      $sidarr = array();
      if ($num > 0) {
         for ($i1=0; $i1 < $num;$i1++) {
            $rowarr = pg_fetch_row($result,$i1);
            $sidarr[] = $rowarr[0];
         }
      }
      $globarr = glob("maps/*");
      foreach ($globarr as $fn) {
         if (strpos($fn,"orig") === false) {
            if (preg_match (':^maps/[mt](\d+)_\d+\.png$:',$fn,$matching)) {
               $sid = $matching[1];
               if (! in_array($sid, $sidarr)) {
                  unlink($fn);
               }
            }
         }
      }
   }
}
if ($mmError == 0) {
    mmInitCategories();
    if (!isset($mmSubmitButton)) {
       mmPutLog(__FILE__ . __LINE__ . " mmSubmitButton is not set");
       $mmErrorMessage = $msg_start . "Internal application error";
       $mmError = 1;
    }
}
if ($mmError == 0) {
    if (!isset($mmSessionId)) {
       $mmSessionState = new SessionState;
       $mmSessionState->QueryResultOffset = 0;
       $mmSessionState->state = 'presentation.php';
       $mmSessionState->options = mmInitialiseOptions();
       $mmSessionState->exploded = array();
       $mmSessionId = $timeofday['usec'];
       $AccessTime = $timeofday['sec'];
       $s1 = serialize($mmSessionState);
       $sqlsentence = "INSERT INTO Sessions VALUES ('$mmSessionId',$AccessTime,'$s1')";
       $result = pg_query ($mmDbConnection, $sqlsentence);
       if (!$result) {
          mmPutLog(__FILE__ . __LINE__ . " Could not $sqlsentence");
          $mmErrorMessage = $msg_start . "Database error";
          $mmError = 1;
       }
    } else {
       $sqlsentence = 
             "SELECT sessionstate FROM Sessions WHERE sessionid = '$mmSessionId'";
       $result = pg_query ($mmDbConnection, $sqlsentence);
       if (!$result) {
          mmPutLog(__FILE__ . __LINE__ . " Could not $sqlsentence");
          $mmErrorMessage = $msg_start . "Database error";
          $mmError = 1;
       } else {
          if (pg_numrows($result) != 1) {
	     mmPutLog("Session time out");
             $mmErrorMessage = $msg_start . "Session timeout";
             $mmError = 1;
          } else {
             $rowarr = pg_fetch_row($result, 0);
	     $mmSessionState = unserialize($rowarr[0]);
          }
       }
    }
}
# 
#  Decompose the value of $mmSubmitButton (BN_CT) into
#  $mmButtonName (BN) and $mmCategoryNum (CT)
# 
if ($mmError == 0) {
    if (preg_match ('/^([^_0-9]+)_(\d+)$/',$mmSubmitButton,$a1)) {
       $mmButtonName = $a1[1];
       $mmSelectedNum = 0;
       $mmCategoryNum = $a1[2];
       $mmCategoryName = mmGetCategoryFncValue($mmCategoryNum,"name");
    } else if (preg_match ('/^([^_0-9]+)(\d+)_(\d+)$/',$mmSubmitButton,$a1)) {
       $mmButtonName = $a1[1];
       $mmSelectedNum = $a1[2];
       $mmCategoryNum = $a1[3];
       $mmCategoryName = mmGetCategoryFncValue($mmCategoryNum,"name");
    } else if (preg_match ('/^([^_0-9]+)(\d+)$/',$mmSubmitButton,$a1)) {
       $mmButtonName = $a1[1];
       $mmSelectedNum = $a1[2];
       $mmCategoryNum = 0;
       $mmCategoryName = "";
    } else {
       $mmButtonName = $mmSubmitButton;
       $mmCategoryNum = 0;
       $mmSelectedNum = 0;
       $mmCategoryName = "";
    }
    if (strpos($mmDebug,"mmSubmitButton") !== false) {
       echo "<br />======== mmSubmitButton and derived variables: ====<br />\n";
       echo "mmSubmitButton => " . $mmSubmitButton . "<br />\n";
       echo "mmButtonName => " . $mmButtonName . "<br />\n";
       echo "mmSelectedNum => " . $mmSelectedNum . "<br />\n";
       echo "mmCategoryNum => " . $mmCategoryNum . "<br />\n";
       echo "mmCategoryName => " . $mmCategoryName . "<br />\n";
       echo "============<br />\n";
    }
# 
#  Process forms filled in by the user on the just visited page.
#  The processing is done in a separate file ($fname below). The name of
#  this file is taken from the $mmButtons array (documented in search.php).
#
#  This will lead to changes in $mmSessionState.
# 
    reset ($_POST);
    if (array_key_exists($mmButtonName, $mmButtons)) {
       $fname = $mmButtons[$mmButtonName][0];
       if (file_exists($fname)) {
          include $fname;
       }
       if (in_array($mmButtonName, array('show','cross','help'))) {
          $mmSessionState->state = 'do' . $mmButtonName . '.php';
       } else {
          $mmSessionState->state = 'doshow.php';
       }
    } else {
       mmPutLog(__FILE__ . __LINE__ . " No such button: $mmButtonName");
       $mmErrorMessage = $msg_start . "Internal application error";
       $mmError = 1;
    }
# 
#  Store updates in $mmSessionState to the database:
# 
    if ($mmError == 0) {
       $AccessTime = $timeofday['sec'];
       $s1 = serialize($mmSessionState);
       $sqlsentence = 
          "UPDATE Sessions SET sessionstate = '$s1', accesstime = $AccessTime \n" .
          "WHERE sessionid = '$mmSessionId'";
       $result = pg_query ($mmDbConnection, $sqlsentence);
       if (!$result) {
          mmPutLog(__FILE__ . __LINE__ . " Could not $sqlsentence");
          $mmErrorMessage = $msg_start . "Database error";
          $mmError = 1;
       }
    }
}
?>
