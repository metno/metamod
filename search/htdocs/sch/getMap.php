<?php
/*
 * Created on Feb 11, 2010
 *
 *---------------------------------------------------------------------------- 
 * METAMOD - Web portal for metadata search and upload 
 *
 * Copyright (C) 2010 met.no 
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
  * read a map in projection with the provided srid parameter from maps/map_#srid.png
  * add optional marks (corner-points) (x1, y1, x2, y2)
  * resize optionally to the provided sizeX, sizeY parameter
  * 
  * @param srid required, projection-id
  * @param sizeX scaling-size of the map, default size: 560x560
  * @param sizeY scaling-size of the map, default size: 560x560
  * @param x1 x-coordinate of first point of bounding-box (0<x1<560)
  * @param y1 y-coordinate of first point of bounding-box (0<y1<560)
  * @param x2 x-coordinate of second point of bounding-box (0<x2<560)
  * @param y2 y-coordinate of second point of bounding-box (0<y2<560)
  * 
  * @return the image
  * 
  */
  require_once("../funcs/mmConfig.inc");
  
  if (!strlen($_REQUEST["srid"])) {
     echo "please provide srid parameter";
     exit(1);
  }
  $srid = $_REQUEST["srid"] + 0;
  $mapFile = $mmConfig->getVar('TARGET_DIRECTORY').'/htdocs/img/map_'.$srid.'.png';
  if (!file_exists($mapFile)) {
     echo "no map for projection $srid";
     exit(1);
  }
  
  $map = imagecreatefrompng($mapFile);
  if (strlen($_REQUEST["x1"])) {
     if (strlen($_REQUEST["x2"])) {
     	  // create a gray bounding box
        $gray = imagecolorallocatealpha($map, 100, 100, 100, 64);
        imagefilledrectangle($map,
                             $_REQUEST["x1"], $_REQUEST["y1"],
                             $_REQUEST["x2"], $_REQUEST["y2"],
                             $gray);					        
     } else {
        // set a black dot
        $black = imagecolorallocate($map, 0, 0, 0);
        imagefilledrectangle($map,
                             $_REQUEST["x1"], $_REQUEST["y1"],
                             $_REQUEST["x1"]+5, $_REQUEST["y1"]+5,
                             $black);					                
     }
  }
  if (strlen($_REQUEST["sizeX"])) {
     $tmp = imagecreate($_REQUEST["sizeX"], $_REQUEST["sizeY"]);
     $width = imagesx($map);
     $height = imagesy($map);
     imagecopyresampled($tmp, $map, 0, 0, 0, 0, $_REQUEST["sizeX"], $_REQUEST["sizeY"], $width, $height);
     imagedestroy($map);
     $map = $tmp;     
  }
  header("Content-type: image/png");
  $expires = 60*60*24*14; # 14 days expiration
  header("Pragma: public");
  header("Cache-Control: maxage=".$expires);
  header('Expires: ' . gmdate('D, d M Y H:i:s', time()+$expires) . ' GMT');
  imagepng($map);
  imagedestroy($map);
    
?>
