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
$max_secondlevel_rows = [==SEARCH_APP_MAXROWS_SCNDLEV==];
$key = array_key_exists($mmSelectedNum, $mmSessionState->exploded);
if ($key === FALSE) {
   $mmSessionState->exploded[$mmSelectedNum] = 1;
} else {
   if ($_POST["mmSubmitButton_showex" . $mmSelectedNum] == "Prev") {
      $mmSessionState->exploded[$mmSelectedNum] =
            $mmSessionState->exploded[$mmSelectedNum] - $max_secondlevel_rows;
   } elseif ($_POST["mmSubmitButton_showex" . $mmSelectedNum] == "Next") {
      $mmSessionState->exploded[$mmSelectedNum] =
            $mmSessionState->exploded[$mmSelectedNum] + $max_secondlevel_rows;
   } elseif (is_numeric($_POST["mmSubmitButton_showex" . $mmSelectedNum])) {
      $mmSessionState->exploded[$mmSelectedNum] = 
                $_POST["mmSubmitButton_showex" . $mmSelectedNum];
   } else {
      unset ($mmSessionState->exploded[$mmSelectedNum]);
   }
}
?>
