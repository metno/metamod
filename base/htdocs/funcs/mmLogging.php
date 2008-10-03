<?php
/*
 * Created on Oct 3, 2008
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

# function: mm_log
# it can be configured here via the MM_LOGLEVEL and the $logFile
# usage: mm_log(MM_DEBUG, "my message", __FILE__, __LINE__);
# log-levels are MM_ERROR, MM_WARNING, MM_INFO, MM_DEBUG

$logFile = "[==LOGFILE==]";
 
 // availabe log-levels
define('MM_ERROR','ERROR');
define('MM_WARNING','WARNING');
define('MM_INFO','INFO');
define('MM_DEBUG', 'DEBUG');
define('MM_NONE', 'NONE');

$mmLogLevel[MM_ERROR] = 40;
$mmLogLevel[MM_WARNING] = 30;
$mmLogLevel[MM_INFO] = 20;
$mmLogLevel[MM_DEBUG] = 10;
$mmLogLevel[MM_NONE] = 0;

// current log-level, change this according to your needs
define('MM_LOGLEVEL', $mmLogLevel[MM_WARNING]);


// generic logging function
function mm_log($level, $message, $file, $line) {
	$levelId = 40;
	if (isset($mmLogLevel[$level])) {
		$levelId = $mmLogLevel[$level];
	}
    if ($levelId >= MM_LOGLEVEL) {
   		$date = strftime('%c');
    	$msg = "$level in $file at $line ($date): $message"; 
		error_log($msg, 3, $logFile);
    }
}
 
 
?>
