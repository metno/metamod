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
require_once("../funcs/mmLogging.inc");
require_once("../funcs/readDataset.inc");

function fmquestversion() {

    $version = "1.0";

    $questversion = "<div style=\"border-top:solid thin;font-size: 50%;\">";
    $questversion .= "METAMODQUEST v.".$version;
    $questversion .= "</div>";

    return($questversion);
}

function fmcreateform($outputdst, $filename, $edit=false) {

    if (! file_exists($filename)) {
		echo(fmcreateerrmsg("Could not open configuration file"));
		return("No form created");
    }
	# this quest goes defines the metadata for a metamod upload directory
	# it will be written in the metamod xml directory as $uploadDir.xml
	# not as md5 hash
	# TODO: check for password in this case
    $uploadDir = $_REQUEST["uploadDirectory"];
    $currentData = array();
    $ownertag = '';
    
    if ($edit) { // read data from session
    	$xmlString = $_SESSION["tempDataset"];
    	if (strlen($xmlString) > 0) {
    		list($ownertag, $currentData) = mmReadEssentialDatasetXml($xmlString);
    	}
    } elseif (strlen($uploadDir) != 0) { // read data from file
		$datasetFile = $outputdst . '/' . $uploadDir . ".xml";
		if (file_exists($datasetFile)) {
			list($ownertag, $currentData) = mmReadEssentialDataset($datasetFile);
		}
	}
	
	
    $mytempl = file($filename);

    echo(fmstartform());
    foreach ($mytempl as $line) {
		if (ereg('^\#',$line)) continue;
		// initialize all possible data from string
		$type = "";
		$name = "";
		$label = "";
		$value = "";
		$exclude = "";
		$include = "";
		$length = 25;
		$height = 1;
		$size = 0;
		$checked = 0;
		parse_str($line);
		echo(fmparsestr($type,$label,$name,$value,$length,$height,$size,$checked,$exclude,$include,$currentData));
		$pname = rtrim($name, "[]\n\r");
		unset($currentData[$pname]); // unset used fields
    }
    unset($currentData["drpath"]); // drpath will be set automatically
    echo(fmcreatebr());
    if (strlen($uploadDir) == 0) {
    	echo(fmcreatesectionstart(NULL));
    	echo(fmcreatetext("keyphrase","Key phrase (for unique identification)",NULL,25,50, $currentData));
   	 	echo(fmcreatesectionend());
    	echo(fmcreatebr());
    } else {
    	foreach ( $currentData as $name => $valArray ) {
       		// add the metadata field currently not used
       		$pname = $name;
       		if (count($valArray) > 1) {
       			$pname .= "[]";
       		}
       		foreach ($valArray as $value) {
       			echo(fmcreatehidden($pname, $value));
       		}
		}
    	echo(fmcreatehidden("uploadDirectory", $uploadDir));
    	echo(fmcreatehidden("institutionId", $_REQUEST["institutionId"]));
    	
    }
    echo(fmcreatebutton("Submit","Check form"));
    echo(fmcreatebutton("Reset","Clear form"));
    echo(fmendform());
    echo(fmquestversion());

    return;
}

function fmstartform() {

    $mystr = "\n<form action=\"".$_SERVER['SCRIPT_NAME']."\" method=\"post\">\n";

    return($mystr);
}

function fmendform() {
    return("\n</form>\n");
}

function fmparsestr($type,$label,$name,$value,$length,$height,$size,$checked,$exclude,$include,$curData) {
     $type = chop($type);
     $name = chop($name);
     $value = chop($value);

    switch ($type) {
    	// sectioning tags
    	case 'h1': $mystr = fmcreateh1($value); break;
    	case 'h2': $mystr = fmcreateh2($value); break;
    	case 'h3': $mystr = fmcreateh3($value); break;
    	case 'p':  $mystr = fmcreatep($value);  break;
    	case 'br': $mystr = fmcreatebr();       break;
    	// input tags
    	case 'text': $mystr = fmcreatetext($name,$label,$value,$length,$size,$curData); break;
    	case 'textarea': $mystr = fmcreatetextarea($name,$label,$value,$length,$height,$curData); break;
    	case 'button': $mystr = fmcreatebutton($name,$value,$curData); break;
    	case 'list': $mystr = fmcreatelist($name,$label,$value,$curData); break;
    	case 'radio': $mystr = fmcreateradio($name,$label,$value,$checked,$curData); break;
    	case 'checkbox': $mystr = fmcreatecheckbox($name,$label,$value,$checked,$curData); break;
    	case 'gcmdlist': $mystr = fmcreategcmdlist($name,$label,$value,$size,$exclude,$include,$curData); break;
    	// grouping tags
    	case 'sectionstart': $mystr = fmcreatesectionstart($value); break;
    	case 'sectionend': $mystr = fmcreatesectionend(); break;
    	case 'recordstart': $mystr = fmcreaterecordstart(); break;
    	case 'recordend': $mystr = fmcreaterecordend(); break;
    	default: $mystr = fmcreateerrmsg("Could not decode element [$type]");
    }

    return($mystr);
}

function fmcreatetitle($msg) {
    return("<title>\n".htmlspecialchars($msg)."\n</title>\n");
}

function fmcreateh1($msg) {
    return("<h1>\n".htmlspecialchars($msg)."\n</h1>\n");
}

function fmcreateh2($msg) {
    return("<h2>\n".htmlspecialchars($msg)."\n</h2>\n");
}

function fmcreateh3($msg) {
    return("<h3>\n".htmlspecialchars($msg)."\n</h3>\n");
}

function fmcreatep($msg) {
    return("<p>\n".htmlspecialchars($msg)."\n</p>\n");
}

function fmcreatebr() {
    return("<br>\n");
}

function fmcreatetext($myname,$label,$value,$length,$size,$curData) {
	$mname = chop($myname);
	if (isset($curData[$mname])) {
		list($value) = $curData[$mname];
	}
    $mystr = fmcreaterecordstart();
    $mystr .= fmlabelstart().htmlspecialchars($label).fmlabelend();
    $mystr .= fminputstart();
    $mystr .= "<input type=\"text\" name=\"".chop($myname)."\" ";
    $mystr .= "value=\"".htmlspecialchars($value)."\" ";
    $mystr .= "size=\"".chop($length)."\" maxlength=\"".chop($size)."\">\n";
    $mystr .= fminputend();
    $mystr .= fmcreaterecordend();

    return($mystr);
}

function fmcreatetextarea($myname,$label,$value,$length,$height,$curData) {
	$mname = chop($myname);
	if (isset($curData[$mname])) {
		foreach ( $curData[$mname] as $row ) {
			$value .= $row . "\n";
		}
   	}

    $mystr = fmcreaterecordstart();
    $mystr .= fmlabelstart().htmlspecialchars($label).fmlabelend();
    $mystr .= fminputstart();
    $mystr .= "<textarea name=\"".chop($myname)."\" ";
    $mystr .= "rows=\"".chop($height)."\" ";
    $mystr .= "cols=\"".chop($length)."\">";
    $mystr .= htmlspecialchars($value)."\n";
    $mystr .= "</textarea>\n";
    $mystr .= fminputend();
    $mystr .= fmcreaterecordend();

    return($mystr);
}

function fmcreatehidden($myname,$myvalue) {
    $mystr = "<input type=\"hidden\" name=\"$myname\" value=\"$myvalue\">\n";

    return($mystr);
}

function fmcreatebutton($myname,$myvalue,$curData = array()) {
	$mname = chop($myname);
	if (isset($curData[$mname])) {
		list($myvalue) = $curData[$mname];
	}
    if ($myvalue) {
		$mystr ="<button name=\"".chop($myname)."\" value=\"".chop($myvalue)."\" type=\"".chop($myname)."\">".chop($myvalue)."</button>\n";
    } else {
		$mystr ="<button name=\"".chop($myname)."\" value=\"".chop($myname)."\" type=\"".chop($myname)."\">".chop($myname)."</button>\n";
    }

    return($mystr);
}

function fmcreateradio($myname,$label,$mylist,$checked,$curData) {
	// assign curValue from curData
	$curValue = "";
	if (isset($curData[$myname])) {
		list($curValue) = $curData[$myname];
		$checked = -1; // unset $checked
	} 
    $myarr = split("\|",chop($mylist));
    $mystr = fmcreaterecordstart();
    $mystr .= fmlabelstart().htmlspecialchars($label).fmlabelend();
    $mystr .= fminputstart();
    $rec = 1;
    foreach ($myarr as $myrecord) {
		$mystr .= "<input type=\"radio\" name=\"$myname\" ";
		if (($checked == $rec) || ($curValue == $myrecord)) {
	    	$mystr .= "checked=\"checked\" ";
		}
		
		$mystr .= "value=\"$myrecord\">";
		$mystr .= " ".htmlspecialchars($myrecord)."<br>\n";
		$rec++;
    }
    $mystr .= fminputend();
    $mystr .= fmcreaterecordend();

    return($mystr);
}

function fmcreatecheckbox($myname,$label,$mylist,$checked,$curData) {
	// read curdata, php requires multivalues names to end with [], remove
	$mname = rtrim($myname, "[]");
	$curValues = array();
	if (isset($curData[$mname])) {
		// unset $checked
		$checked = -1;
		foreach ($curData[$mname] as $value) {
			$curValues[$value] = 1;
		}
	}

    $myarr = split("\|",chop($mylist));
    $mystr = fmcreaterecordstart();
    $mystr .= fmlabelstart().htmlspecialchars($label).fmlabelend();
    $mystr .= fminputstart();
    $rec = 1;
    foreach ($myarr as $myrecord) {
		$mystr .= "<input type=\"checkbox\" name=\"$myname\" ";
		if (($checked == $rec) || ($curValues[$myrecord])) {
	    	$mystr .= "checked=\"checked\" ";
		}
		$mystr .= "value=\"$myrecord\">";
		$mystr .= " ".htmlspecialchars($myrecord)."<br>\n";
		$rec++;
    }
    $mystr .= fminputend();
    $mystr .= fmcreaterecordend();

    return($mystr);
}

function fmcreateselect($myname,$label,$mylist,$size,$selected,$curData=array()) {
	// read curdata, php requires multilist names to end with [], remove
	$mname = rtrim($myname, "[]");
	$curValues = array();
	if (isset($curData[$mname])) {
		foreach ( $curData[$mname] as $value ) {
			$curValues[$value] = 1;
		}
		$selected = -1;
	}

    $myarr = split("\|",chop($mylist));
    $mystr = fmcreaterecordstart();
    $mystr .= fmlabelstart().htmlspecialchars($label).fmlabelend();
    $mystr .= fminputstart();
    $mystr .= "<select name=\"$myname\" multiple=\"multiple\" size=".$size.">\n";
    $rec = 1;
    foreach ($myarr as $myrecord) {
		$mystr .= "<option value=\"$myrecord\" ";
		if (($selected == $rec) or (strlen($curValues[$myrecord]))) {
			$mystr .= "selected=\"selected\" ";
		}
		$mystr .= ">";
		$mystr .= htmlspecialchars($myrecord);
		$mystr .= "</option>\n";
		$rec++;
    }
    $mystr .= "</select>\n";
    $mystr .= fminputend();
    $mystr .= fmcreaterecordend();
    return($mystr);
}

function fmcreatelist($myname,$label,$mylist,$curData) {
	if (isset($curData[$myname])) {
		list($curValue) = $curData[$myname];
	}

    $myarr = split("\|",chop($mylist));

    $mystr = fmcreaterecordstart();
    $mystr .= fmlabelstart().htmlspecialchars($label).fmlabelend();
    $mystr .= fminputstart();
    $mystr .= "<select name=\"".htmlspecialchars($myname)."\">\n";
    foreach ($myarr as $myrecord) {
		$mystr .= "<option ";
		if ($curValue == $myrecord) {
			$mystr .= "selected=\"selected\" ";
		}
		$mystr .= ">".htmlspecialchars($myrecord)."</option>\n";
    }
    $mystr .= "</select>\n";
    $mystr .= fminputend();
    $mystr .= fmcreaterecordend();

    return($mystr);
}

function fmcreategcmdlist($myname,$mylabel,$myvalue,$size,$exclude,$include,$curData) {
	// read curdata, php requires multilist names to end with [], remove
	$mname = rtrim($myname, "[]");
	$curValues = array();
	if (isset($curData[$mname])) {
		foreach ( $curData[$mname] as $value ) {
			$curValues[$value] = 1;
		}
	}
    $mystr = fmcreaterecordstart();
    $mystr .= fmlabelstart().htmlspecialchars($mylabel).fmlabelend();
    $mystr .= fminputstart();
    #$mystr .= $myvalue;
    if (file_exists($myvalue)) {
		$myarr = file($myvalue);
    } else {
		return(fmcreateerrmsg("Could not open ".$myvalue));
    }
    $myarr = preg_grep('/^#/',$myarr,PREG_GREP_INVERT);
    if (strlen($exclude) > 0) {
		$mysearcharr = split("\|",rtrim($exclude));
		foreach ($mysearcharr as $mysearchstr) {
	    	$mysearchstr = "/^".rtrim($mysearchstr)."/";
	    	$myarr = preg_grep($mysearchstr,$myarr,PREG_GREP_INVERT);
		}
    }
    if (strlen($include) > 0) {
		$mysearcharr = split("\|",rtrim($include));
		foreach ($mysearcharr as $mysearchstr) {
           $myarr[] = $mysearchstr;
        }
    }
    $mystr .= "<select name=\"$myname\" multiple size=".$size.">\n";
    foreach ($myarr as $myrecord) {
    	$myrecord = rtrim($myrecord);
		$mystr .= "<option value=\"$myrecord\" ";
		if ($curValues[$myrecord]) {
			$mystr .= "selected=\"selected\" ";
		}
		$mystr .= ">";
		$mystr .= " ".htmlspecialchars($myrecord);
		$mystr .= "</option>\n";
    }
    $mystr .= "</select>\n";
    $mystr .= fminputend();
    $mystr .= fmcreaterecordend();

    return($mystr);
}

function fmcreatesectionstart($mymsg) {

##    $mystr = "<div style=\"background: #eeeeee; ";
##    $mystr .= "padding: 5px; ";
##    $mystr .= "margin-left: 20px; ";
##    $mystr .= "border: solid thin;clear:both;\">\n";
##    $mystr = "<div class=\"fmsection\">\n";
    if (strlen($mymsg) > 0) {
	$mystr = "<fieldset>\n<legend>".$mymsg."</legend>\n";
    } else {
	$mystr = "<fieldset>\n";
    }

    return($mystr);
}

function fmcreatesectionend() {

    #$mystr = "</div>\n";
    $mystr = "</fieldset>\n";

    return($mystr);
}

function fmcreaterecordstart() {

    static $calls=0;

##    $mystr = "<div style=\"";
##    $mystr .= "padding: 5px; ";
##    if (fmod($calls,2) == 0) {
##	$mystr .= "background: #e0e0e0; ";
##    }
##    $mystr .= "border: none;clear: both;\">\n";

    if (fmod($calls,2) == 0) {
	$mystr = "<div class=\"fmrecorddark\">\n";
    } else {
	$mystr = "<div class=\"fmrecordbright\">\n";
    }

    $calls++;

    return($mystr);
}

function fmcreaterecordend() {

    $mystr = "<div style=\"clear: both;margin: 0;padding:0;width:auto;\"></div>\n";
    $mystr .= "</div>\n";

    return($mystr);
}

function fmlabelstart() {

    $mystr = "<div class=\"fmlabel\">";

    return($mystr);
}

function fmlabelend() {

    $mystr = "</div>\n";

    return($mystr);
}

function fminputstart() {

    $mystr = "<div class=\"fminput\">";

    return($mystr);
}

function fminputend() {

    $mystr = "</div>\n";

    return($mystr);
}

function fmcreatemsg($mymsg) {

    $myformattedmsg = "<p class=\"fmmsg\">\n$mymsg\n</p>\n";

    return($myformattedmsg);
}

function fmcreateerrmsg($mymsg) {

    $myformattedmsg = "<p class=\"fmerrmsg\">\nERROR: $mymsg\n</p>\n";

    return($myformattedmsg);
}

/**
 * @brief convert the POST array to xml and html
 * @param addititions array with additional xml rows, right below the root node
 * @return array($xml, $html)
 */
function fmForm2XmlHtml($additions = array()) {
	$xml = <<<EOF
<?xml version="1.0" encoding="ISO-8859-1"?>
<dataset ownertag="[==QUEST_OWNERTAG==]">
EOF;
	foreach ($additions as $row) {
		$xml .= "$row\n";
	}
    $html = "<html>\n<head>\n</head>\n<body>\n";
	
	foreach ($_POST as $mykey=>$myvalue) {
		if ($mykey == "Submit" || $mykey == "cmd" || $mykey == "institutionId" || $mykey == "uploadDirectory" || $mykey == "drpath") {
	    	continue;
		}
		# escape user-entered values
		$mykey = htmlspecialchars($mykey);
    	if (is_array($myvalue)) {
			foreach ($myvalue as $myitem => $singleval) {
		   		$myvalue[$myitem] = htmlspecialchars($singleval);
			}
    	} else {
			$myvalue = htmlspecialchars($myvalue);
    	}
	
		if (is_array($myvalue)) {
	    	$html .= "<b>$mykey</b><br/>\n";
	    	foreach ($myvalue as $singleitem) {
				$xml .= "\t<$mykey>$singleitem</$mykey>\n";
				$html .= "<p>".wordwrap(ereg_replace("\n","<br />\n",$singleitem."<br />"),70)."</p>\n";
	    	}
		} else {
	    	$html .= "<b>$mykey</b><br />\n<p>".wordwrap(ereg_replace("\n","<br />\n",$myvalue),70)."</p>\n";
	    	if ($mykey == "abstract") {
				$xml .= "\t<$mykey>\n$myvalue\n\t</$mykey>\n";
	    	} else {
				$xml .= "\t<$mykey>$myvalue</$mykey>\n";
	    	}
		}
    }
    $html .= "</body>\n</html>\n";
    $xml .= "</dataset>\n";
    return array($xml, $html);
}

#
# Process the information submitted, generate HTML email message and
# METAMOD XML message locally
#
function fmprocessform($outputdst,$mystdmsg,$mysender,$myrecipents) {

    $mymsg = $mystdmsg;
	
	if (! is_dir($outputdst)) {
   		$mymsg = "Output destination could not be configured, inform the administrator!";
   		echo(fmcreateerrmsg($mymsg));
   		return;
	}

	$outputfile = "";
	if ($_REQUEST["uploadDirectory"]) {
		if (! $_REQUEST["institutionId"]) {
			$mysmg = "information missing during quest metadata configuration, please enter through the admin portal!";
       		echo(fmcreateerrmsg($mymsg));
			echo(fmcreatebutton("Submit", "Edit form"));
       		return;
		}
    	$outputfile = "$outputdst/".$_REQUEST["uploadDirectory"].".xml";
    	# automatically set the following parameters
    	if (! (isset($_REQUEST["drpath"]) && strlen($_REQUEST["drpath"]))) {
    		if (preg_match ('/\/([^\/]+)$/',$outputdst,$matches1)) {
       			$drpath = $matches1[1].'/'.$_REQUEST["uploadDirectory"];
    		}
    	}
		if (! (isset($_REQUEST["dataref"]) && strlen($_REQUEST["dataref"]))) {
			$_POST["dataref"] = "[==OPENDAP_URL==]" . '/' . $_REQUEST["institutionId"] . '/' . $_REQUEST["uploadDirectory"];
		}
		# unset parameters which should not be used in xml-generation
		unset($_POST["institutionId"]);
		unset($_POST["uploadDirectory"]);
	} else {
	    # Create output filename for local storage using name, email and keyphrase
    	$md5code = md5($_SERVER["name"].$_POST["email"].$_POST["keyphrase"]);
    	if (preg_match ('/\/([^\/]+)$/',$outputdst,$matches1)) {
       		$drpath = $matches1[1].'/'.$md5code;
    	}
    	$outputfile = "$outputdst/$md5code.xml";
    	if (file_exists($outputfile)) {
			echo(fmcreateerrmsg("You have submitted information using the same keyphrase before"));
			echo(fmcreatebutton("Submit", "Edit form"));
			return;
    	}
	}
	
	list($myxmlcontent, $myhtmlcontent) = fmForm2XmlHtml(array("<drpath>$drpath</drpath>"));

    # Removed FILE_TEXT flag. This flag is only available in PHP 6.
    # LOCK_EX|FILE_TEXT -> LOCK_EX
    if (file_put_contents($outputfile, $myxmlcontent,LOCK_EX) == FALSE) {
		$mymsg="Could not store data, have you submitted this information
		using the same keyphrase earlier? Sorry for the inconveniece";
		echo(fmcreateerrmsg($mymsg));
		return;
    };
    $mailheader = 'MIME-Version: 1.0' . "\r\n";
    $mailheader .= 'Content-type: text/html; charset=iso-8859-1' . "\r\n";
    $mailheader .= 'From: '.$mysender. "\r\n" .
	'Reply-To: '.$mysender . "\r\n" .
	'X-Mailer: PHP/' . phpversion();
    mail($myrecipents,"Message from ".$_SERVER["SERVER_NAME"],
	    $myhtmlcontent,$mailheader);

    echo(fmcreatemsg($mymsg));

    echo(fmquestversion());
    unset($_SESSION["tempDataset"]);
    return;
}

#
# Check the contents of the information submitted
#
function fmcheckform($outputdst, $filename) {
	list($xmlString, $htmlString) = fmForm2XmlHtml();
	$_SESSION["tempDataset"] = $xmlString; // store the dataset in a session

    $errors = FALSE;
    if (! file_exists($filename)) {
		echo(fmcreateerrmsg("Could not open configuration file"));
		return("No form created");
    } 

    $mytempl = file($filename);

	if (isset($_REQUEST["uploadDirectory"])) {
		if (! (isset($_REQUEST["institutionId"]) && strlen($_REQUEST["institutionId"]))) {
			$mysmg = "information missing during quest metadata configuration, please enter through the admin portal!";
       		echo(fmcreateerrmsg($mymsg));
       		return;
		}
	} elseif ( ! $_POST["keyphrase"]) {
		echo(fmcreateerrmsg("Record "."Key phrase"." is mandatory and missing"));
		$errors = TRUE;	
	}

    foreach ($mytempl as $line) {
		if (! ereg('mandatory',$line)) continue;
		parse_str($line);
		# check for string-length, so value 0 returns true
		if (! strlen($_POST[$name])) {
	    	echo(fmcreateerrmsg("Record ".$name." is mandatory and missing"));
	    	$errors = TRUE;
		}
    }
    if ($errors) {
		echo(fmcreateerrmsg("Please use your browser's back button ".
			"to correct these problems"));
		echo(fmquestversion());
		return;
    }

    echo(fmstartform());
    echo(fmcreatesectionstart(NULL));
    echo(fmcreatemsg("Please check contents and use the back button of the
		browser to correct any errors."));
    foreach ($_POST as $mykey=>$myvalue) {
		if ($mykey == "Submit" || $mykey == "cmd") {
	    	continue;
		}
		# escape user-entered values
		$mykey = htmlspecialchars($mykey);
    	if (is_array($myvalue)) {
			foreach ($myvalue as $myitem => $singleval) {
		    	$myvalue[$myitem] = htmlspecialchars($singleval);
			}
    	} else {
			$myvalue = htmlspecialchars($myvalue);
    	}
		echo(fmcreaterecordstart());

		# Check if refeences are valid URLs
##	if ($mykey == "reference") {
##	    if (! ereg("http://",$myvalue)) {
##		$mytmpstr = "http://".$myvalue;
##		if (@get_headers($mytmpstr)) {
##		    $myvalue = "http://".$myvalue;
##		}
##	    }
##	}

		# Check that geographical positions are numeric
		if ($mykey == "northernmost_latitude" || 
	    	$mykey == "southernmost_latitude" ||
	   		$mykey == "easternmost_longitude" ||
	    	$mykey == "westernmost_longitude") {
	    	if (! is_numeric($myvalue)) {
				$myvalue = "<span style=\"color: red;\">This field ".
					"should be a decimal number. Please use the ".
					"back button and correct errors</span>";
				$errors = TRUE;
	    	} else if (ereg("latitude",$mykey)) {
				if ($myvalue > 90. || $myvalue < -90.) {
		    		$myvalue .= " <span style=\"color: red;\">The ".
		    			"latitude domain is -90&#176; to 90&#176; North".
		    			"</span>";
		    		$errors = TRUE;
				}
	    	} else if (ereg("longitude",$mykey)) {
				if ($myvalue > 180. || $myvalue < -180.) {
		    		$myvalue .= " <span style=\"color: red;\">The ".
		    			"longitude domain is -180&#176; to 90&#176; East".
		    			"</span>";
		    		$errors = TRUE;
				}
	    	}
	    	if ($_POST["westernmost_longitude"] > 
		    	$_POST["easternmost_longitude"]) {
				$myvalue .= " <span style=\"color: red;\">Western ".
		    		"limit is East of Eastern limit</span>";
				$errors = TRUE;
	    	} else if ($_POST["southernmost_latitude"] >
		    	$_POST["northernmost_latitude"]) {
				$myvalue .= " <span style=\"color: red;\">Northern ".
		    		"limit is South of Southern limit</span>";
				$errors = TRUE;
	    	}
		}

		# Check that time specifications are of the correct format
		if ($mykey == "datacollection_period_from" ||
	    	$mykey == "datacollection_period_to") {
	    	if (!preg_match("/^\d\d\d\d-\d\d-\d\d \d\d:\d\d \w\w\w/",
				$myvalue)) {
				$myvalue = "<span style=\"color: red;\">This field ".
					"should be of the form YYYY-MM-DD HH:MM UTC, please use ".
					"the back button and correct errors. If time is not in ".
					"UTC please specify timezone by the correct three ".
					"letter abbreviation.</span>";
				$errors = TRUE;
	    	}
		}

		# Check that abstract is not too long
		if ($mykey == "abstract" ||
	    	$mykey == "description" ||
	    	$mykey == "comment") {
	    	if (strlen($myvalue) > 512) {
				$myvalue = "<span style=\"color: red;\">This is no ".
					"contest for the Nobel prize in literature, please ".
					"use the back button and shorten the text.</span>";
				$errors = TRUE;
	    	} else {
				$myvalue = ereg_replace("\n","<br><br>\n",htmlspecialchars($myvalue));
	    	}
		}

		# Check that history is of the correct format
		if ($mykey == "history") {
	    	if (!preg_match("/^\d\d\d\d-\d\d-\d\d /", $myvalue)) {
				$myvalue = "<span style=\"color: red;\">This should ".
					"be of the form YYYY-MM-DD Creation, Please use the ".
					"back button and correct the text. </span>";
				$errors = TRUE;
	    	}
		}

		# Create the output form for visual inspection by the user
		#
		# Label column
		if ($mykey == "keyphrase") {
	    	echo(fmlabelstart()."Key phrase".fmlabelend());
		} else {
	    	$searchstr = "/name=".$mykey."/";
	    	$templitem = preg_grep($searchstr,$mytempl);
	    	if (count($templitem) > 0) {
				parse_str(current($templitem));
	    		echo(fmlabelstart().$label.fmlabelend());
	    	} else {
	    		echo(fmlabelstart().$mykey.fmlabelend());
	    	}
		}
		# Data column
		if (is_array($myvalue)) {
	    	echo(fminputstart());
	    	foreach ($myvalue as $singleitem) {
				echo($singleitem."<br>");
	    	}
	    	echo(fminputend());
		} else {
	    	echo(fminputstart().$myvalue.fminputend());
		}
		echo(fmcreaterecordend());

		# Add hidden elements to transport information to the data dump
		# function
		if (!$errors) {
    		if (is_array($myvalue)) {
				foreach ($myvalue as $singleitem) {
	    			echo(fmcreatehidden($mykey."[]",$singleitem));
				}
			} else {
				echo(fmcreatehidden($mykey,$myvalue));
    		}
		}
    }
    echo(fmcreatesectionend());
    echo(fmcreatebr());

	if (!$errors) {
    	echo(fmcreatebutton("Submit","Write form"));
	}
	echo(fmcreatebutton("Submit", "Edit form"));
    echo(fmcreatebutton("Submit","Cancel write"));
    echo(fmendform());

    echo(fmquestversion());

    return;
}
