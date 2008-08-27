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
#
#   PHP code
#
#   
#     Read all lines in a file into an array:
#   
   $createdb = "../../init/createdb.sh";
   $createdbarr = file($createdb);
   $getrowname = 0;
#   
#     Create an empty array
#   
   $tables = array();
   $tablesrefs = array();
#   
#    foreach value in an array
#   
   reset($createdbarr);
   foreach ($createdbarr as $line) {
#      
#        Extract subexpressions in RE:
#      
      if (preg_match ('/^CREATE TABLE (\S+)/',$line,$result)) {
#      
#        First matching subexpression:
         $tablename = $result[1];
         $tables[$tablename] = array();
         $getrowname = 1;
      }
      else {
#         
#           Extract subexpressions in RE:
#         
         if ($getrowname == 1 && preg_match ('/^\s*(\w+)/',$line,$result2)) {
#         
#           First matching subexpression:
            $rowname = $result2[1];
            if ($rowname == "PRIMARY" || $rowname == "UNIQUE") {
               $getrowname = 0;
            }
            else {
               $tables[$tablename][] = $rowname;   # Next available integer key
               if (preg_match ('/REFERENCES\s+(\w+)/',$line,$result3)) {
                  $referenced = $result3[1];
                  if (array_key_exists($referenced,$tablesrefs)) {
                     $tablesrefs[$referenced] .= " $tablename $rowname";
                  } else {
                     $tablesrefs[$referenced] = "$tablename $rowname";
                  }
                  if (array_key_exists($tablename,$tablesrefs)) {
                     $tablesrefs[$tablename] .= " $referenced $rowname";
                  } else {
                     $tablesrefs[$tablename] = "$referenced $rowname";
                  }
               }
            }
         }
      }
   }
?>
