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
#  Initialize array
#
$menu = array( 'viewdbform.php' => 'View table'
   , 'highlight.html' => 'View source file'
   , 'showconfig.php' => 'View master_config.txt'
   , 'admusers.php' => 'User administration'
   , 'manage_datasets.php' => 'Dataset manager'
   , 'show_users.php' => 'Show File Upload users'
   , 'show_usererrors.php' => 'Show File Upload user errors'
   , 'show_syserrors.php' => 'Show File Upload system errors'
   , 'show_databaselog.php' => 'Database log'
   , 'show_xml.php' => 'Show XML dataset files'
   , 'dosql.php' => 'Perform SQL sentence'
   , 'userbase_sql.php' => 'Perform SQL sentence on userbase'
   , 'xxx.php' => 'Do xxx'
   , 'phptest.php' => 'Show PHP installation'
)
?>
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">
<html>
<head>
   <title>METAMOD - Metadata Catalogue - Administration</title>
   <style>
     .menu { line-height: 1.3; }
     .bgblue { background-color: #aaaaff; }
   </style>
</head>

<body bgcolor="#f5f5dc">

<table border=0 cellpadding=0 cellspacing=0 align="center">

<tr valign="top">
<td bgcolor="#f5f5dc">
<br>
</td>
</tr>
<tr valign="top">
<td>
<div style="border: solid thin olive; background: white">
<center>
<p><font size="+2">METAMOD2</font></p>
<p><font size="+2">&nbsp;&nbsp;System Administration&nbsp;&nbsp;</font></p>
</center>
</div>
</td>
<td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>
<td bgcolor="#f5f5dc">
<?php
   reset($menu);
   foreach ($menu as $phpfile => $menutext) {
      if (file_exists($phpfile)) {
         echo '<a href="' . $phpfile . '">' . $menutext . '</a><br>' . "\n";
      }
   }
?>
</td>
</tr>
</table>
</body>
</html>
