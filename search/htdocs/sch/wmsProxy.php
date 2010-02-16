<?php
/*
 * Created on Feb 16, 2010
 *
 *---------------------------------------------------------------------------- 
 * METAMOD - Web portal for metadata search and upload 
 *
 * Copyright (C) 2009 met.no 
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
 

 
 /**
  * Simple php proxy to work around javascript-restriction of not being able to fetch a document
  * from another server.
  * 
  * @param url original wms-server page, must be a GET document for an text/xml GetCapabilites document
  * @return return status from the original server
  */

function debug ($flag, $val) {
    if (false) error_log('wmsProxy.php: '. $flag . ": " . $val, 0);
}

function host_allowed($host) {
  // TODO: allow only urls from known web-servers to be fetched
  if (preg_match('/.met.no$/', $host)) {
     return true;
  } else {
     return false;
  }
}

unset($url);
if (!isset($_GET['url'])) {
   header("HTTP/1.1 404 Not Found");
   echo ("Parameter url required");
   debug("no url parameter");	
   exit;
}

$url = $_GET['url'];
debug("url",$url);
$purl = parse_url($url);
debug("parsed_url",$purl);
$req = "GET $url HTTP/1.1\r\n" .
       'Host: ' . $purl['host'] . ($purl['port'] ? ':'. $purl['port'] : '') .
       "\r\nConnection: close\r\n\r\n";
debug("request", $req);
if (!host_allowed($purl['host'])) {
   header("HTTP/1.1 403 Forbidden");
   echo ("not allowed to access $url");
   debug("not allowed to access", $url);
   exit;	   
}

$port = $purl['port'] ? $purl['port'] : '80';
$fp = fsockopen ($purl['host'], $port, $errno, $errstr, 30);
if (!$fp) {
    print "HTTP/1.0 500 $errstr ($errno)\r\n";
    print "Content-Type: text/html\r\n\r\n";
    print "<html><body><b>error</b></body></html>\n";
    exit;
}
stream_set_timeout($fp, 15);
$info = stream_get_meta_data($fp);
fwrite($fp, $req);
while (!feof($fp) && !$info['time_out']) {
    $response .= fread($fp, 2048);
    $info = stream_get_meta_data($fp);
}
fclose($fp);
if ($info['time_out']) {
	header("HTTP/1.1 504 Gateway timeout");
   echo('Connection timed out!');
} else {
   $endHeaderPos = strpos($response, "\r\n\r\n");
   $offset = 4;
   if (!$endHeaderPos) {
      // try an alternative header ending
      $endHeaderPos = strpos($response, "\n\n");
      $offset = 2;
   }
   if (!$endHeaderPos) {
      header("HTTP/1.1 500 Application Error");
      echo('No response-header');
   } else {
      $header .= substr($response, 0, $endHeaderPos);
      $text = substr($response, $endHeaderPos + $offset);
   }
	debug('header', $header);
   debug('response', $text);
   $headerArray = preg_split(':\r?\n:', $header);
   foreach ( $headerArray as $value ) {
      header($value);          
   }
   print $text;
}

?>
