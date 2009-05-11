<?php
/*
 * Created on Oct 28, 2008
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
/**
 * Fetch a DBO connection for a user.
 * @param $user the database-user
 * @param $password the database-password
 * @return DBO-connection
 * @throws DBOException
 */
function getDBOConnection($user="", $password="") {
	global $mmConfig;
	if (strlen($user) == 0) {
		$user = $mmConfig->getVar('PG_WEB_USER');
	}
	static $mmDBOConnection = array();
	if (! isset($mmDBOConnection[$user])) {
		$mmDBOConnection[$user] = new DBO("pgsql:".$mmConfig->getVar('PG_CONNECTSTRING_PERL'), $user, $password);
	}
	return $mmDBOConnection[$user];
}

/**
 * Get the information of a dataset as xml.
 * @param $drpath the identifiere of the dataset
 * @return xml-string of dataset2
 * @throws DBOException on dataset-problems
 */
function getDataset2($dsName) {
	$dbo = getDBOConnection();
	$sth = $dbo->prepare("SELECT DS_id, DS_name, DS_parent, DS_status, DS_datestamp, DS_owernertag " .
			"FROM DataSet WHERE DS_name = :dsname");
	$sth->bindValue(":dsname", $dsName);
	while ($row = $sth->fetch()) {
		list($id, $name, $parent, $status, $datestamp, $ownertag) = $row;
	}
	// TODO
}

?>
