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
<html>
<head>
</head><body>
<?php
#
#  This database manager displays a table of top level datasets within a database. The table
#  is based on the 'DataSet' database table.
#
#  In this table, any number of datasets can be marked as selected. Checkboxes in the first
#  column indicate which datasets are selected. Various methods are used to mark datasets as
#  selected or not:
#
#  - Individual datasets may be selected or deselected by clicking the checkbox in the first
#    column.
#
#  - Datasets can also be selected by posting a regular expression that are checked against
#    the DS_name field in the 'DataSet' database table.
#
#  - All datasets may be selected.
#
#  - All datasets that currently are unselected can be marked as selected, and currently
#    selected datasets can loose their selected status. This is done simultaneously by the
#    'Flip' command.
#
#  As a full table of all datasets can be quite large, options are provided for limiting
#  the table rows that are displayed to only those with selected datasets, or to only those
#  with unselected datasets ("Which datasets to show").
#
#  Three actions are provided to effectuate actual changes to the database and the XML files
#  it is based upon. These actions affects in the first place the XMD files corresponding to
#  the selected datasets. Subsequently, when the automatic update of the database takes place,
#  the actions will also affect the database. Since the automatic update usually takes some
#  time, the changes in the database will not be visible immediately.
#
#  These actions are:
#
#  - Delete: The selected datasets are marked as deleted in the XMD files.
#
#  - Activate: The selected datasets (presumably with a deleted status) are marked as active
#    in the XMD files.
#
#  - Change: Change ownertag on all selected datasets.
#
require_once("../funcs/mmConfig.inc");
require_once("../funcs/mmDataset.inc");
# print_r($_POST);
$mmDbConnection = @pg_Connect ("dbname=".$mmConfig->getVar('DATABASE_NAME')." user=".$mmConfig->getVar('PG_ADMIN_USER')." ".$mmConfig->getVar('PG_CONNECTSTRING_PHP'));
if ( $mmDbConnection ) {
?>
<p>Connection OK</p>
<?php
   $dbtable = 'DataSet';
   $rowstr = "DS_id,DS_name,DS_status,DS_ownertag,DS_filePath";
   $rownames = explode(",",$rowstr);
   $flipped_rownames = array_flip($rownames);
   $displayed_rownames = array("Id","Name","Status","Ownertag","File path");
   echo "<h2>Dataset manager:</h2>\n";
   $result = pg_query ($mmDbConnection, "select $rowstr from $dbtable where DS_parent = 0 order by DS_id");
   if ( !$result ) {
      echo "<p>Error: Could not get rows from table $dbtable<BR>";
   } else {
      $num = pg_numrows($result);
      echo '<form action="manage_datasets.php" method="post">' . "\n";
      echo '<table border="0" bgcolor="#f5f5dc" width="100%">' . "\n";
#
#     Select using regular expression:
#
      echo "<tr>\n";
      echo '<td align="right">Select datasets with names corresponding to regular expression: </td>' . "\n";
      if (array_key_exists("exp",$_POST) && array_key_exists("regexp",$_POST)) {
         $regexp_value = $_POST["regexp"];
         if (get_magic_quotes_gpc()) { # The magic quote directive is used in the PHP installation.
                                       # Remove the extra backslashes inserted by this directive:
            $regexp_value = stripcslashes($regexp_value);
         }
      } else {
         $regexp_value = "";
      }
      echo '<td>&nbsp;</td>' . "\n";
      echo '<td><input type="text"  size="40" name="regexp" value="'. $regexp_value .'"/></td>' . "\n";
      echo '<td><input type="submit" name="exp" value="Use regexp" /></td>' . "\n";
      echo "</tr>\n";
#
#     Select all:
#
      echo "<tr>\n";
      echo '<td align="right">Select all datasets: </td>';
      echo '<td>&nbsp;</td>';
      echo '<td>&nbsp;</td>';
      echo '<td><input type="submit" name="all" value="Select all" /></td>' . "\n";
      echo "</tr>\n";
#
#     Flip selected/unselected:
#
      echo "<tr>\n";
      echo '<td align="right">Flip selected/unselected: </td>';
      echo '<td>&nbsp;</td>';
      echo '<td>&nbsp;</td>';
      echo '<td><input type="submit" name="flip" value="Flip" /></td>' . "\n";
      echo "</tr>\n";
#
#     Show all / only selected / only unselected:
#
      echo "<tr>\n";
      echo '<td align="right">Which datasets to show: </td>';
      echo '<td>&nbsp;</td>';
      echo '<td>';
      foreach (array("All","Selected","Unselected") as $value) {
         if (! array_key_exists("which",$_POST) && $value == "All") {
            $checked = "checked ";
         } elseif (array_key_exists("which",$_POST) && $_POST["which"] == $value) {
            $checked = "checked ";
         } else {
            $checked = "";
         }
         echo $value . ': ';
         echo '<input type="radio" name="which" '. $checked .'value="'. $value .'" />';
         echo '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;';
      }
      echo '</td>' . "\n";
      echo '<td><input type="submit" name="refresh" value="Refresh" /></td>' . "\n";
      echo "</tr>\n";
#
      echo '<tr><td colspan="4">&nbsp;</td></tr>' . "\n";
#
#     Mark selected datasets as deleted:
#
      echo "<tr>\n";
      echo '<td align="right">Mark selected datasets as deleted: </td>';
      echo '<td>&nbsp;</td>';
      echo '<td>&nbsp;</td>';
      echo '<td><input type="submit" name="mdel" value="Delete" /></td>' . "\n";
      echo "</tr>\n";
#
#     Mark selected datasets as active:
#
      echo "<tr>\n";
      echo '<td align="right">Mark selected datasets as active: </td>';
      echo '<td>&nbsp;</td>';
      echo '<td>&nbsp;</td>';
      echo '<td><input type="submit" name="activate" value="Activate" /></td>' . "\n";
      echo "</tr>\n";
#
#     Change ownertag:
#
      echo "<tr>\n";
      echo '<td align="right">Change ownertag on all selected datasets. New ownertag: </td>';
      if (array_key_exists("owner",$_POST) && array_key_exists("newtag",$_POST)) {
         $newtag = $_POST["newtag"];
      } else {
         $newtag = "";
      }
      echo '<td>&nbsp;</td>';
      echo '<td><input type="text"  size="40" name="newtag" value="'. $newtag .'"/></td>' . "\n";
      echo '<td><input type="submit" name="owner" value="Change" /></td>' . "\n";
      echo "</tr>\n";
#
      echo '<tr><td colspan="4">&nbsp;</td></tr>' . "\n";
      echo "<tr>\n";
      echo '<td colspan="3"><small><i><b>Note:</b> The last three actions (Delete, Activate and Change) ' .
           'will not be effectuated until the next automatic database update.' .
           '<br />Accordingly, no change in the status or ownertag column ' .
           'will be seen immideately.</i></small></td>';
      echo '<td>&nbsp;</td>';
      echo "</tr>\n";
#
      echo "</table>\n";
      echo "<br />\n";
#
#     Dataset table:
#
      echo '<table border="1" cellspacing="0" width="100%">' . "\n";
      echo "<tr>\n";
      echo '<th bgcolor="#f5f5dc">Select</th><th>' . implode("</th><th>",$displayed_rownames) . "</th>\n";
      echo "</tr>\n";
      $dsidix = $flipped_rownames["DS_id"];
      $dsnameix = $flipped_rownames["DS_name"];
      $dsstatusix = $flipped_rownames["DS_status"];
      $dsfilepathix = $flipped_rownames["DS_filePath"];
      $dsotagix = $flipped_rownames["DS_ownertag"];
      for ($i1=0; $i1<$num; $i1++) {
         $rowarr = pg_fetch_row($result, $i1);
         $checked = "";
         if (array_key_exists("all",$_POST)) {
            $checked = " checked";
         } elseif (array_key_exists("flip",$_POST)) {
            if (! array_key_exists("d".$rowarr[$dsidix],$_POST)) {
               $checked = " checked";
            }
         } elseif (array_key_exists("d".$rowarr[$dsidix],$_POST)) {
            $checked = " checked";
         } elseif ($regexp_value != "" && preg_match ('/'.$regexp_value.'/',$rowarr[$dsnameix])) {
            $checked = " checked";
         }
         $show = true; # Indicates if this table row should be displayed or not. Some table rows
                       # will not be shown if the "Which datasets to show" option is set to
                       # 'Selected' or 'Unselected'.
         $type = "checkbox";
         if (array_key_exists("which",$_POST) && $_POST["which"] == "Selected" && $checked == "") {
            $show = false;
            $type = "hidden";
         }
         if (array_key_exists("which",$_POST) && $_POST["which"] == "Unselected" && $checked != "") {
            $show = false;
            $type = "hidden";
         }
         if ($show) {
	        echo "<tr>\n";
            echo '<td bgcolor="#f5f5dc">';
         }
#
#        The following input element, normally of type "checkbox", might be hidden. If hidden,
#        it looses its checkbox properties. A checkbox will only post its name-value pair
#        if it is checked, while a hidden element will post its name-value pair allways.
#        Concequently, it is neccessary to suppress the inclusion of hidden elements 
#        representing checkboxes that are not checked:
#
         if ($type == "checkbox" || $checked == " checked") {
            echo '<input type="'. $type .'"' . $checked . ' name="d'. $rowarr[$dsidix] .
                 '" value="' . $rowarr[$dsidix] .'" />';
         }
         if ($show) {
            echo '</td>' . "\n";
         }
         if ($rowarr[$dsstatusix] == 1) {
            $rowarr[$dsstatusix] = "active";
         } else {
            $rowarr[$dsstatusix] = "deleted";
         }
         $basename = mmGetBasename($rowarr[$dsfilepathix]);
         if ($checked == " checked" && array_key_exists("mdel",$_POST)) {
            list($xmd, $xml) = mmGetDatasetFileContent($rowarr[$dsfilepathix]);
            $newxmd = str_replace('status="active"','status="deleted"',$xmd);
            mmWriteDataset($basename, $newxmd, $xml);
         }
         if ($checked == " checked" && array_key_exists("activate",$_POST)) {
            list($xmd, $xml) = mmGetDatasetFileContent($rowarr[$dsfilepathix]);
            $newxmd = str_replace('status="deleted"','status="active"',$xmd);
            mmWriteDataset($basename, $newxmd, $xml);
         }
         if ($checked == " checked" && array_key_exists("owner",$_POST)) {
            list($xmd, $xml) = mmGetDatasetFileContent($rowarr[$dsfilepathix]);
            $oldtag = $rowarr[$dsotagix];
            $newxmd = str_replace('ownertag="'.$oldtag.'"','ownertag="'.$newtag.'"',$xmd);
            mmWriteDataset($basename, $newxmd, $xml);
         }
         if ($show) {
	        echo "<td>" . implode("</td><td>",$rowarr) . "</td>\n";
	        echo "</tr>\n";
         }
      }
      echo "</table>\n";
      echo "</form>\n";
   }
}
?>
</body>
</html>
