<?
/*
* +----------------------------------------------------------------------+
* | PHP Version 4                                                        |
* +----------------------------------------------------------------------+
* | Copyright (c) 2002-2005 Heinrich Stamerjohanns                       |
* |                                                                      |
* | listrecords.php -- Utilities for the OAI Data Provider               |
* |                                                                      |
* | This is free software; you can redistribute it and/or modify it under|
* | the terms of the GNU General Public License as published by the      |
* | Free Software Foundation; either version 2 of the License, or (at    |
* | your option) any later version.                                      |
* | This software is distributed in the hope that it will be useful, but |
* | WITHOUT  ANY WARRANTY; without even the implied warranty of          |
* | MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the         |
* | GNU General Public License for more details.                         |
* | You should have received a copy of the GNU General Public License    |
* | along with  software; if not, write to the Free Software Foundation, |
* | Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA         |
* |                                                                      |
* +----------------------------------------------------------------------+
* | Derived from work by U. Müller, HUB Berlin, 2002                     |
* |                                                                      |
* | Written by Heinrich Stamerjohanns, May 2002                          |
* /            stamer@uni-oldenburg.de                                   |
* |                                                                      |
* | Adapted to METAMOD2 by Egil Støren, August 2008                      |
* |            egil.storen@met.no                                        |
* +----------------------------------------------------------------------+
*/
//
// $Id: listrecords.php,v 1.03 2004/07/02 14:24:21 stamer Exp $
//

// parse and check arguments
foreach($args as $key => $val) {

	switch ($key) {
		case 'from':
			// prevent multiple from
			if (!isset($from)) {
				$from = $val;
			} else {
				$errors .= oai_error('badArgument', $key, $val);
			}
			break;

		case 'until':
			// prevent multiple until
			if (!isset($until)) {
				$until = $val;
			} else {
				$errors .= oai_error('badArgument', $key, $val);
			}
			break;

		case 'metadataPrefix':
			if (is_array($METADATAFORMATS[$val])
					&& isset($METADATAFORMATS[$val]['myhandler'])) {
				$metadataPrefix = $val;
				$inc_record  = $METADATAFORMATS[$val]['myhandler'];
			} else {
				$errors .= oai_error('cannotDisseminateFormat', $key, $val);
			}
			break;

		case 'set':
			if (!isset($set)) {
				$set = $val;
			} else {
				$errors .= oai_error('badArgument', $key, $val);
			}
			break;

		case 'resumptionToken':
			if (!isset($resumptionToken)) {
				$resumptionToken = $val;
			} else {
				$errors .= oai_error('badArgument', $key, $val);
			}
			break;

		default:
			$errors .= oai_error('badArgument', $key, $val);
	}
}
if (!isset($from)) {
   $from = '';
}
if (!isset($until)) {
   $until = '';
}
if (!isset($set)) {
   $set = '';
}


// Resume previous session?
if (isset($args['resumptionToken'])) {
	if (count($args) > 1) {
		// overwrite all other errors
		$errors = oai_error('exclusiveArgument');
	} else {
		if (is_file("tokens/re-$resumptionToken")) {
			$fp = fopen("tokens/re-$resumptionToken", 'r');
			$filetext = fgets($fp, 255);
			$textparts = explode('#', $filetext);
			$deliveredrecords = (int)$textparts[0];
			$extquery = $textparts[1];
			$metadataPrefix = $textparts[2];
			if (is_array($METADATAFORMATS[$metadataPrefix])
					&& isset($METADATAFORMATS[$metadataPrefix]['myhandler'])) {
				$inc_record  = $METADATAFORMATS[$metadataPrefix]['myhandler'];
			} else {
				$errors .= oai_error('cannotDisseminateFormat', $key, $val);
			}
			fclose($fp);
			//unlink ("tokens/re-$resumptionToken");
		} else {
			$errors .= oai_error('badResumptionToken', '', $resumptionToken);
		}
	}
}
// no, we start a new session
else {
	$deliveredrecords = 0;
	if (!$args['metadataPrefix']) {
		$errors .= oai_error('missingArgument', 'metadataPrefix');
	}

	if (isset($args['from'])) {
		if (!checkDateFormat($from)) {
			$errors .= oai_error('badGranularity', 'from', $from);
		}
	}

	if (isset($args['until'])) {
		if (!checkDateFormat($until)) {
			$errors .= oai_error('badGranularity', 'until', $until);
		}
	}

   if (isset($args['from']) && isset($args['until'])) {
      if (!checkDateRange($from,$until)) {
		   $errors .= oai_error('badArgument','',"$from > $until");
      }
   }

	if (isset($args['set'])) {
		if (!is_array($SETS)) {
		   $errors .= oai_error('noSetHierarchy');
		   oai_exit();
		} else if (! array_key_exists($args['set'], $SETS)) {
		   $errors .= oai_error('noRecordsMatch');
		   $set = 'not_in_database';
		}
	}
}

if (empty($errors)) {
        $allrecords = getRecords('',$from,$until,$set);
        if ($allrecords === FALSE) {
	   $errors .= oai_error('internalDatabaseError');
        } else {
           $num_rows = count($allrecords);
           if (!$num_rows) {
              $errors .= oai_error('noRecordsMatch');
           }
        }
}

// break and clean up on error
if ($errors != '') {
	oai_exit();
}

$output .= " <ListRecords>\n";

// Will we need a ResumptionToken?
if ($num_rows - $deliveredrecords > $MAXRECORDS) {
	$token = get_token();
	$fp = fopen ("tokens/re-$token", 'w');
	$thendeliveredrecords = (int)$deliveredrecords + $MAXRECORDS;
	fputs($fp, "$thendeliveredrecords#");
	fputs($fp, "$extquery#");
	fputs($fp, "$metadataPrefix#");
	fclose($fp);
	$restoken =
'  <resumptionToken expirationDate="'.$expirationdatetime.'"
     completeListSize="'.$num_rows.'"
     cursor="'.$deliveredrecords.'">'.$token."</resumptionToken>\n";
}
// Last delivery, return empty ResumptionToken
elseif (isset($args['resumptionToken'])) {
	$restoken =
'  <resumptionToken completeListSize="'.$num_rows.'"
     cursor="'.$deliveredrecords.'"></resumptionToken>'."\n";
}

$maxrec = min($num_rows - $deliveredrecords, $MAXRECORDS);

// return records
$dsidarray = array_keys($allrecords);
$countrec  = 0;
$ix = $deliveredrecords;
while ($countrec++ < $maxrec) {
        $record = $allrecords[$dsidarray[$ix++]];

	$identifier = $oaiprefix.$record[$SQL['identifier']];
	$datestamp = formatDatestamp($record[$SQL['datestamp']]);

	if (isset($record[$SQL['deleted']]) && ($record[$SQL['deleted']] == 'true') &&
		($deletedRecord == 'transient' || $deletedRecord == 'persistent')) {
		$status_deleted = TRUE;
	} else {
		$status_deleted = FALSE;
	}

	$output .= '  <record>'."\n";
        if ($status_deleted) {
	   $output .= '   <header status="deleted">'."\n";
        } else {
	   $output .= '   <header>'."\n";
        }
	$output .= xmlformat($identifier, 'identifier', '', 4);
	$output .= xmlformat($datestamp, 'datestamp', '', 4);
	if (!$status_deleted and $SQL['set'] != '')
		// use xmlrecord since we use stuff from database
		$output .= xmlrecord($record[$SQL['set']], 'setSpec', '', 4);

	$output .= '   </header>'."\n";

// return the metadata record itself
	if (!$status_deleted)
		include('oai2/'.$inc_record);

	$output .= '  </record>'."\n";
}

// ResumptionToken
if (isset($restoken)) {
	$output .= $restoken;
}

// end ListRecords
$output .=
' </ListRecords>'."\n";

?>
