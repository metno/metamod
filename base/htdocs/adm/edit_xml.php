<?php
/*
 * Created on Jan 27, 2009
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
require_once("../funcs/mmDataset.inc");
/**
 * depending on php-setup, it will at \ to all ' or ", will be removed here
 * I'm not afraid of sql-injection in adm
 */
function raw_param( $str ) {
	return ini_get( 'magic_quotes_gpc' ) ? stripslashes( $str ) : $str;
}
/**
 * htmlentities will fail silently if not all
 * characters are given in the set character-set.
 * This function will work around that problem, and translate
 * then without character-set.
 */
function htmlEncodeUtf8 ( $str ) {
	$encStr = htmlentities($str, ENT_QUOTES, 'UTF-8');
	if (strlen($encStr) < strlen($str)) {
		$encStr = htmlentities($str, ENT_QUOTES);
	}
	return $encStr;
}

?>
<html>
<head>
<title>Edit .xmd and .xml dataset files</title>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
</head>
<body>
<h1>XML-Editor for</h1>
<?php
	if (strlen($_REQUEST["file"]) && is_file($_REQUEST["file"])) {
		echo "<pre>".$_REQUEST["file"]."</pre>";
		$xml = html_entity_decode(raw_param($_REQUEST["xmlContent"],ENT_QUOTES, 'UTF-8'));
		$xmd = html_entity_decode(raw_param($_REQUEST["xmdContent"],ENT_QUOTES, 'UTF-8'));	
		if (strlen($_REQUEST["submitValue"]) && $_REQUEST["submitValue"] == "Save") {
			mmWriteDataset(mmGetBasename($_REQUEST["file"]), $xmd, $xml);
			echo "<p>Data successfully saved</p>";
		} elseif (strlen($_REQUEST["submitValue"]) && $_REQUEST["submitValue"] == "Validate") {
			// nothing to do, always validate
		} else {
			list($xmd, $xml) = mmGetDatasetFileContent($_REQUEST["file"]); 
		}
		$validXMD = false;
		$validXML = false;
		$domXMD = new DOMDocument();
		$loadXMD = $domXMD->loadXML($xmd); 
		if ($loadXMD) {
			$domXMD->encoding = "UTF-8";
			$xmd = $domXMD->saveXML(); // save as utf-8
			echo "<p>Dataset is well-defined</p>";
			$validXMD = $domXMD->schemaValidate(MM_ForeignDataset::DATASET_SCHEMA); 
			if ($validXMD) {
				echo "<p>Dataset is valid</p>";
			} else {
				echo "<p style=\"color: red\">Dataset is invalid</p>";
			}
		} else {
			echo "<p style=\"color: red\">Dataset is not well-defined. PLEASE CHECK!</p>";
		}
		$domXML = new DOMDocument();
		$loadXML = $domXML->loadXML($xml); 
		if ($loadXML) {
			$domXML->encoding = "UTF-8";
			$xml = $domXML->saveXML(); // save as utf-8
			echo "<p>xml-file is well-defined</p>";
			$validXML = $domXML->schemaValidate(MM_Dataset::MM2_SCHEMA); 
			if ($validXML) {
				echo "<p>xml-file is valid MM2 file.</p>";
			} else {
				echo "<p style=\"color: blue\">xml-file is not valid MM2 file.</p>";
			}
		} else {
			echo "<p style=\"color: red\">xml-file is not well-defined. PLEASE CHECK!</p>";
		}
?>
<form action="edit_xml.php" method="POST">
	<input type="hidden" name="file" value="<?php echo $_REQUEST["file"]; ?>" />
	<h2>Dataset Content</h2>
	<textarea name="xmdContent" rows="15" cols="100"><?php echo htmlEncodeUtf8($xmd); ?></textarea>
	<h2>Metadata Content</h2>
	<textarea name="xmlContent" rows="40" cols="100"><?php echo htmlEncodeUtf8($xml); ?></textarea>
	<p>
	<input type="submit" name="submitValue" value="Validate" />
	<input type="submit" name="submitValue" value="Save" />
	<a href="show_xml.php">Back to xml overview</a>
	</p> 
</form>


<?php		
	} else {
		echo "No such file: ". $_REQUEST["file"];
	}
?>
</body>
</html>

