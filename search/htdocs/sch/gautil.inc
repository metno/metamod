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
   function mmGenlist ($depth,$ilow,$ihigh) {
      $lst = array();
      $i1 = $ilow;
      while ($i1 <= $ihigh) {
         $i2 = $i1;
         $dp = $depth;
         $i2len = 1;
         $i2newlen = 0;
         $i2last = 0;
         $i2prev = $i2;
         while ($i2prev >= 0 && $i2last == 0 && $i1 + $i2newlen - 1 <= $ihigh) {
            $i2last = $i2 % 2;
            $i2prev = $i2;
            $i2 = $i2 >> 1;
            $i2newlen = 2 * $i2len;
            if ($i2prev >= 0 && $i2last == 0 && $i1 + $i2newlen - 1 <= $ihigh) {
               $i2len = $i2newlen;
               $dp -= 1;
            } else {
               array_push($lst,array($i1,$dp));
               $i1 += $i2len;
            }
         }
      }
      return $lst;
   }
   function mmNewqtnode ($depth,$xval,$yval,$dp) {
      $xval = $xval >> ($depth - $dp);
      $yval = $yval >> ($depth - $dp);
      $digits = "";
      while ($dp > 0) {
         $digit = ($xval % 2) + 2*($yval % 2) + 1;
         $digits = "$digit$digits";
         $xval = $xval >> 1;
         $yval = $yval >> 1;
         $dp -= 1;
      }
      return $digits;
   }
   function mmGetqtnodes ($depth,$dsid,$dsarr = array()) {
      global $mmDebug, $mmError, $mmErrorMessage, $mmDbConnection, $mmSessionState;
      $x1 = $mmSessionState->sitems["9,GA"][2];
      $y1 = $mmSessionState->sitems["9,GA"][3];
      $x2 = $mmSessionState->sitems["9,GA"][4];
      $y2 = $mmSessionState->sitems["9,GA"][5];
      $xx1 = floor(($x1 - 0.99)/5) + 8;
      $yy1 = floor(($y1 - 0.99)/5) + 16;
      $xx2 = floor(($x2 - 0.99)/5) + 8;
      $yy2 = floor(($y2 - 0.99)/5) + 16;
      $qtnodes = array();
      $xlist = mmGenlist($depth,$xx1,$xx2);
      $ylist = mmGenlist($depth,$yy1,$yy2);
      foreach ($ylist as $ypar) {
         $y1 = $ypar[0];
         $ydp = $ypar[1];
         foreach ($xlist as $xpar) {
            $x1 = $xpar[0];
            $xdp =  $xpar[1];
            if ($xdp == 0 && $ydp == 0) {
               $middle = 1 << ($depth - 1);
               array_push($qtnodes,mmNewqtnode($depth,0,0,1));
               array_push($qtnodes,mmNewqtnode($depth,$middle,0,1));
               array_push($qtnodes,mmNewqtnode($depth,0,$middle,1));
               array_push($qtnodes,mmNewqtnode($depth,$middle,$middle,1));
            } elseif ($xdp == $ydp) {
               array_push($qtnodes,mmNewqtnode($depth,$x1,$y1,$xdp));
            } elseif ($xdp > $ydp) {
               $ystep = 1 << ($depth - $xdp);
               $yrange = 1 << ($depth - $ydp);
               for ($yadd = 0; $yadd < $yrange; $yadd += $ystep) {
                  array_push($qtnodes,mmNewqtnode($depth,$x1,$y1 + $yadd,$xdp));
               }
            } else {
               $xstep = 1 << ($depth - $ydp);
               $xrange = 1 << ($depth - $xdp);
               for ($xadd = 0; $xadd < $xrange; $xadd += $xstep) {
                  array_push($qtnodes,mmNewqtnode($depth,$x1 + $xadd,$y1,$ydp));
               }
            }
         }
      }
      $gdarr = array();
      $sql_dslist = "";
      if (count($dsarr) > 0) {
         $sql_dslist = " DataSet.DS_id IN (" . implode(", ",$dsarr) . ") AND\n";
      }
      $sqlsentence = "SELECT DISTINCT GD_id, DataSet.DS_id FROM GA_Contains_GD, GA_Describes_DS, DataSet\n" .
                     "WHERE $sql_dslist DataSet.DS_parent = $dsid AND DataSet.DS_id = GA_Describes_DS.DS_id AND\n" .
                     "GA_Contains_GD.GA_id = GA_Describes_DS.GA_id ORDER BY GD_id\n";
      if (strpos($mmDebug,"mapsearch") !== false) {
         echo "<pre>sqlsentence:\n\n$sqlsentence\n</pre>";
      }
      $result1 = pg_query ($mmDbConnection, $sqlsentence);
      if (!$result1) {
         mmPutLog(__FILE__ . __LINE__ . " Could not $sqlsentence");
         $mmErrorMessage = $msg_start . "Internal application error";
         $mmError = 1;
      } else {
         $num = pg_numrows($result1);
         if (strpos($mmDebug,"mapsearch") !== false) {
            echo "<pre>result count = $num</pre>\n";
         }
         if ($num > 0) {
            for ($i1=0; $i1 < $num;$i1++) {
               $rowarr = pg_fetch_row($result1,$i1);
               $gdarr[] = $rowarr[0] . 'E' . $rowarr[1];
            }
         }
      }
      $drhash = array();
      foreach ($qtnodes as $node) {
         $rex = "/^((";
         $jlim = strlen($node) - 1;
         $endstr = "?";
         for ($i1 = 0; $i1 <= $jlim; $i1++) {
            $rex .= substr($node,$i1,1);
            if ($i1+1 < $jlim) {
               $rex .= '(';
               $endstr .= ')?';
            }
         }
         if ($jlim > 0) {
            $rex .= $endstr;
         }
         $rex .= ')|(' . $node . '\d*))E/';
         foreach (preg_grep($rex,$gdarr) as $gdelt) {
            $pos = strpos($gdelt,'E')+1;
            $drid = substr($gdelt,$pos);
            $drhash[$drid] = $drid;
         }
      }
      sort($drhash);
      return $drhash;
   }
