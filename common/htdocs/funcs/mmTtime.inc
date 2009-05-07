<?php
/*
 * Created on Oct 22, 2008
 *
 *---------------------------------------------------------------------------- 
 * METAMOD - Web portal for metadata search and upload 
 *
 * Copyright (C) 2008 met.no 
 *
 * Contact information: 
 * Norwegian Meteorological Institute 
 * Box 43 Blindern 
 * 0313 OSLO 
 * NORWAY 
 * email: heiko.klein@met.no 
 *  
 * This file is part of METAMOD 
 *
 * METAMOD is free software; you can redistribute it and/or modify 
 * it under the terms of the GNU General Public License as published by 
 * the Free Software Foundation; either version 2 of the License, or 
 * (at your option) any later version. 
 *
 * METAMOD is distributed in the hope that it will be useful, 
 * but WITHOUT ANY WARRANTY; without even the implied warranty of 
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the 
 * GNU General Public License for more details. 
 *  
 * You should have received a copy of the GNU General Public License 
 * along with METAMOD; if not, write to the Free Software 
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA 
 *--------------------------------------------------------------------------- 
 */
?>
<?php
if (! is_a($mmConfig,'MMConfig')) {
	trigger_error("\$mmConfig needs to be configure in your script with \$mmConfig = MMConfig::getInstance('configfile') before including mmTtime", E_USER_ERROR);
}

class mmTtime {
   function ttime($usetime = 0) {
   	global $mmConfig;
      if ($usetime == 0) {
         $realtime = time();
      } else {
         $realtime = $usetime;
      }
      $scaling = $mmConfig->getVar("TEST_IMPORT_SPEEDUP");
      if (strlen($scaling) == 0) {
      	 return $realtime; # no TEST_IMPORT_SPEEDUP given
      }
      if ($scaling <= 1) {
         return $realtime;
      } else {
         $basistime = $mmConfig->getVar("TEST_IMPORT_BASETIME");
         return $basistime + ($realtime - $basistime)*$scaling;
      }
   }
}
?>
