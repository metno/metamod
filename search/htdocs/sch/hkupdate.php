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
#  The user has just clicked on a [+] or [-] button in an hierarchical search page
#  for the search category given by $mmCategoryNum.
#
#  Update list of nodes visible to the user in the tree structure shown
#  in the search page. This list is contained in array
#  $mmSessionState->sitems["$mmCategoryNum,HK"]. $mmSelectedNum (the HK_id field in
#  the database) identifies which node the user has clicked. 
#
$s1 = $mmCategoryNum . ",HK";
if (!isset($mmSessionState->sitems) || !array_key_exists($s1, $mmSessionState->sitems)) {
#
#  No node-list is inherited from the session state. Initialize new
#  node-list containing only the top level nodes:
#
   $mmSessionState->sitems[$s1] = array();
   foreach (mmGetHK($mmCategoryNum) as $hkid => $hkvalue) {
      $mmSessionState->sitems[$s1][] = 10;
      $mmSessionState->sitems[$s1][] = 0;
      $mmSessionState->sitems[$s1][] = $hkid;
      $mmSessionState->sitems[$s1][] = $hkvalue;
   }
}
#
#  Get the old node list from the session state (or the just initialized list):
#
$oldlist = $mmSessionState->sitems[$s1];
$icount = count($oldlist);
#
#  Add new dummy node at the end of the list (just 2 of 4 numbers comprising a node):
#  (This dummy element will be removed later. It is used for loop technical reasons).
#
$oldlist[] = $oldlist[$icount-4];
$oldlist[] = 1;
#
#  Compute the following switches:
#
#  $expand_new_level   - Set to 1 if the user has clicked on a [+] button, and the old
#                        node list does not contain the next level of nodes. Then, the 
#                        nodes on the next level has to be retrieved from the database.
#  $show_hidden_level  - Set to 1 if the user has clicked on a [+] button, and the 
#                        nodes on the next level already exist in the list (but are
#                        hidden).
#  $hide_level         - Set to 1 if the user has clicked on a [-] button. The nodes
#                        on the next level will then be hidden (but not removed from
#                        the list).
#
#  Note: Testing on which type of button the user has clicked ([+] or [-]) is only
#  indirectly done, by comparing the levels of consecutive nodes in the old list. 
#  If the next node (compared to the $mmSelectedNum-node) is not hidden and is on a
#
#  deeper level, then the user has clicked a [-] button.
#
$expand_new_level = 0;
$show_hidden_level = 0;
$hide_level = 0;
for ($i1=4; $i1 <= $icount;$i1 += 4) {
   if ($oldlist[$i1-2] == $mmSelectedNum) {
      if ($oldlist[$i1-4] < 99) {
         if ($oldlist[$i1-4] >= $oldlist[$i1]) {
            $expand_new_level = 1;
         } else if ($oldlist[$i1+1] == 1) {
            $show_hidden_level = 1;
         } else {
            $hide_level = 1;
         }
      }
   }
}
#
array_pop($oldlist);
array_pop($oldlist);
#
#  If neccessary, fetch the child nodes of the clicked-on node from the database. These
#  are either taken from the HierarchicalKey table or from the BasicKey table (if no nodes
#  are found in the HierarchicalKey table).
#
#  The results are stored in two arrays:
#
#  $hkresult   - Results from the HierarchicalKey table.
#  $bkresult   - Results from the BasicKey table.
#
if ($expand_new_level == 1) {
   $sqlsentence = 'SELECT HK_level, HK_id, HK_name FROM HierarchicalKey WHERE HK_parent = ' .
            $mmSelectedNum . ' ORDER BY HK_name';
   $hkresult = do_select($sqlsentence);
   $hkresultcount = count($hkresult);
   if ($hkresultcount == 0) {
      $sqlsentence = 'SELECT BasicKey.BK_id, BK_name FROM BasicKey, HK_Represents_BK WHERE ' .
            'HK_id = ' . $mmSelectedNum . ' AND BasicKey.BK_id = HK_Represents_BK.BK_id ' .
            'ORDER BY BasicKey.BK_name';
      $bkresult = do_select($sqlsentence);
   }
}
#
$ctname = mmGetCategoryFncValue($mmCategoryNum,"name");
$ctname = str_replace(' ','_',$ctname);
unset($mmSessionState->sitems[$s1]);
$mmSessionState->sitems[$s1] = array();
#
#  Loop through the node list. A new node list is computed and stored in the session state
#  ($mmSessionState->sitems["$mmCategoryNum,HK"]).
#
#  Each existing node comprise four elements in the $oldlist array.
#  The following variables represents one node:
#
#  $newlev     - The level ( >= 1 ). High levels are deep levels.
#  $newchecked - Tells if the checkbox corresponding to this node is checked. If so,
#                $newchecked == 1, othervise $newchecked == 0.
#  $newhidden  - =1 if the node is hidden (0 othervise)
#  $newid      - Database id for the node (HK_id or BK_id).
#  $newname    - Keyword for the node (the text shown to the user).
#
#  These variables are modified and used to construct the new node.
#
#  Throughout this loop, the following swiches controls the execution:
#
#  $modifylevel   - If > 0, the current node is a node having the clicked-on node as
#                   an anchestor. In that case, $modifylevel represents the level that
#                   has to be modified, i.e. the level at which the hidden status has
#                   to be changed. This is the level which is one unit deeper compared
#                   to the level of the clicked-on node.
#  $parentlevel   - Level of the parent node (=0 for nodes at level 1)
#  $hidinglevel   - > 0 if the current node is hidden (directly or indirectly by a hidden
#                   ancestral node). = 0 othervise.
#
$modifylevel = 0;
$parentlevel = 0;
$hidinglevel = 0;
# echo 'Start: $ctname $newname $newlev $newhidden $newid $modifylevel $show_hidden_level $hide_level $expand_new_level $parentlevel<BR />' . "\n";
#
while ($newlevch = array_shift($oldlist)) {
   $newlev = round($newlevch / 10);
   $newchecked = $newlevch % 10;
   $newhidden = array_shift($oldlist);
   $newid = array_shift($oldlist);
   $newname = array_shift($oldlist);
   if ($newhidden == 1 && $hidinglevel == 0) {
      $hidinglevel = $newlev;
   } else if ($newhidden == 0 && $hidinglevel >= $newlev) {
      $hidinglevel = 0;
   }
   if ($newlev < 99) {
      $parentlevel = $newlev - 1;
   }
   $key1 = $ctname . '_' . $newid;
   $key2 = $ctname . '_hk' . $newid;
   if (array_key_exists($key1,$_POST) || array_key_exists($key2,$_POST)) {
      $newchecked = 1;
   } else if ($newchecked == 1 && $hidinglevel == 0) {
      if (!array_key_exists($key1,$_POST) && !array_key_exists($key2,$_POST)) {
         $newchecked = 0;
      }
   }
   if ($modifylevel > 0 && $parentlevel + 1 == $modifylevel) {
      if ($show_hidden_level == 1) {
         $newhidden = 0;
      }
      if ($hide_level == 1) {
         $newhidden = 1;
      }
   }
#   echo 'loop: ' . $ctname . ' ' . $newname . ' ' . $newlev . ' ' . $newhidden . ' ' . $newid . ' ' . $modifylevel . ' ' . $show_hidden_level . ' ' . $hide_level . ' ' . $expand_new_level . ' ' . $parentlevel . '<BR />' . "\n";
   $newlevch = 10*$newlev + $newchecked;
   $mmSessionState->sitems[$s1][] = $newlevch;
   $mmSessionState->sitems[$s1][] = $newhidden;
   $mmSessionState->sitems[$s1][] = $newid;
   $mmSessionState->sitems[$s1][] = $newname;
   if ($newid == $mmSelectedNum && $newlev < 99 && $expand_new_level == 1) {
      if ($hkresultcount > 0) {
         foreach ($hkresult as $arr1) {
            $mmSessionState->sitems[$s1][] = $arr1[0] * 10;
            $mmSessionState->sitems[$s1][] = 0;
            $mmSessionState->sitems[$s1][] = $arr1[1];
            $mmSessionState->sitems[$s1][] = $arr1[2];
         }
      } else {
         foreach ($bkresult as $arr1) {
            $mmSessionState->sitems[$s1][] = 990;
            $mmSessionState->sitems[$s1][] = 0;
            $mmSessionState->sitems[$s1][] = $arr1[0];
            $mmSessionState->sitems[$s1][] = $arr1[1];
         }
      }
   }
   if ($newid == $mmSelectedNum && $newlev < 99 &&
            ($hide_level == 1 || $show_hidden_level == 1)) {
      $modifylevel = $newlev + 1;
   } else if ($newlev < $modifylevel) {
      $modifylevel = 0;
   }
   if ($newlev < 99) {
      $parentlevel = $newlev;
   }
}
?>
