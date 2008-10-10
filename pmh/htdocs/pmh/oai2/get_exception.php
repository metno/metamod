<?
/*
* +----------------------------------------------------------------------+
* | PHP Version 5                                                        |
* +----------------------------------------------------------------------+
* | Copyright (c) 2008 Egil Støren, met.no                               |
* |                                                                      |
* | get_exception.php -- Utilities for the OAI Data Provider             |
* |                                                                      |
* | This is free software; you can redistribute it and/or modify it under|
* | the terms of the GNU General Public License as published by the      |
* | Free Software Foundation; either version 2 of the License, or (at    |
* | your option) any later version.                                      |
* | This software is distributed in the hope that it will be useful, but |
* | WITHOUT  ANY WARRANTY; without even the implied warranty of          |
* | MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the         |
* | GNU General Public License for more details.                         |
* | You should have received a copy of the GNU General Public License    |
* | along with  software; if not, write to the Free Software Foundation, |
* | Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA         |
* |                                                                      |
* +----------------------------------------------------------------------+
* | Written for METAMOD2 by Egil Støren, August 2008                     |
* |            egil.storen@met.no                                        |
* +----------------------------------------------------------------------+
*/
//
//

function get_exception($mtname, $exception, $value) {
   include 'var_topic.php'; // Includes arrays $topics and $areas
   if ($mtname == 'variable') {
      if (array_key_exists($value, $topics)) {
         $parts = explode(" > ",$topics[$value][0]);
         if ($exception <= count($parts)) {
            return $parts[$exception - 1];
         }
      }
   }
   elseif ($mtname == "datacollection_period") {
      $parts = explode(" to ",$value);
      if (count($parts) >= $exception) {
         return $parts[$exception - 1];
      }
   }
   elseif ($mtname == "area") {
      if (array_key_exists($value, $areas)) {
         $parts = explode(" > ",$areas[$value]);
         if ($exception <= count($parts)) {
            return $parts[$exception - 1];
         }
         elseif ($exception == 4 && !in_array($value, $parts)) {
            return $value;
         }
      }
   }
   elseif ($mtname == "latitude_resolution" || $mtname == "longitude_resolution") {
      if ($exception == 1) {
         return "$value degrees";
      }
   }
   elseif ($mtname == "DS_ownertag") {
      if ($exception == 1) {
         if ($value == "DAM") {
            return "DAMOCLES";
         }
      }
   }
   elseif ($mtname == "DS_name") {
      if ($exception == 1) {
         return str_replace('/','_',$value);
      }
   }
   return FALSE;
}
?>
