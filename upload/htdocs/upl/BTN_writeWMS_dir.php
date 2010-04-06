<?php 
#---------------------------------------------------------------------------- 
#  METAMOD - Web portal for metadata search and upload 
# 
#  Copyright (C) 2009 met.no 
# 
#  Contact information: 
#  Norwegian Meteorological Institute 
#  Box 43 Blindern 
#  0313 OSLO 
#  NORWAY 
#  email: heiko.klein@met.no 
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
// The user has pushed the BTN_writeWMS_dir button in the "Edit WMS" page
// 
// check the directory, set the nextpage to 6 (wmsEdit.php) and set the parameters
// @param $wmsDataset
// @param $wmsDatasetFile
// @param $directory
// @param $dirkey
// @param $wmsInfo
//
require_once("../funcs/mmDataset.inc");
require_once("../funcs/mmWMS2.inc");
check_credentials(); // Sets $error, $errmsg, $nextpage, $normemail, $sessioncode,
                     // $runpath, $filepath, $filecontent and $dirinfo (globals).
if ($error == 0) {
	$dirkey = conditional_decode($_REQUEST["dirkey"]);   
	$directory = conditional_decode($_REQUEST["dirname"]);
	$wmsInput = trim(stripslashes(conditional_decode($_REQUEST["wmsInfo"])));
	if (checkDirectoryPermission($directory, $dirkey, &$errmsg)) {
		$wmsDatasetFile = mmGetRunPath() . "/XML/" . $mmConfig->getVar("APPLICATION_ID") . '/' . $directory . '.xmd';
		if (is_writable($wmsDatasetFile)) {
			try {
				if (strlen($wmsInput)) {
					// validate, throws on error
					try {
				   	new MM_WMSSetup($wmsInput, true);
					} catch (MM_DatasetException $mde) {
					   // do nothing, try next one
					   new MM_WMSSetup2($mwsInput, true);
					}
				}
				list($xmdContent, $xmlContent) = mmGetDatasetFileContent($wmsDatasetFile);
				$wmsDataset = new MM_ForeignDataset($xmdContent, $xmlContent, true);
		   	$wmsDataset->setWMSInfo($wmsInput);
		   	$wmsDataset->write(mmGetBasename($wmsDatasetFile));
				$errmsg .= "Successfully updated $directory";
		   	$nextpage = 3;
			} catch (MM_DatasetException $mde) {
			   $errmsg .= "Error on writing dataset $directory:". $mde->getMessage();
		   	mmPutLog("WMSInfo: $wmsInput");
			   $error = 2;
			}
		} else {
		   $errmsg .= "dataset-info at $wmsDatasetFile not writable, please contact " . $mmConfig->getVar('OPERATOR_EMAIL');
		   $error = 2;
		}
	} else {
		mmPutLog($errmsg);
	   $error = 2;
	}
}

if ($error > 0) {
 	$nextpage = 6;
}
?>
