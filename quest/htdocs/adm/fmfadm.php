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
require_once("../funcs/mmConfig.inc");
?>
<html>

<head>
<META http-equiv="Generator" content="Øystein Godøy, METNO/FOU">
<META http-equiv="Content-Type" content="text/html; charset=ISO-8859-1">
<style type="text/css">
.fmerrmsg {
    color: red;
}
.fmmsg {
    color: blue;
}
h1,h2,h3,h4 {
    font-family: sans serif;
}
div,span,p {
    font-family: sans serif;
}
div.fmheader {
    background: url(<?PHP echo $mmConfig->getVar('QUEST_ADM_BACKGROUND') ?>);
    margin-bottom: 2em;
    padding-left: 5px;
    border-bottom: solid thin;
}
div.fmsection {
    /*background: #ffffff;*/
    background: #000000;
    color: #aaaaaa;
    padding: 5px;
    margin-left: 20px;
    border: solid thin;
    clear: both;
}
div.fmrecordbright {
    padding: 5px;
    color: black;
    background: #e3df96;
    border: none;
    clear: both;
}
div.fmrecorddark {
    padding: 5px;
    color: black;
    background: #d1cd8a;
    border: none;
    clear: both;
}
div.fminput {
    float: right;
    text-align: left;
    width: 78%;
    border: none;
}
div.fmlabel {
    float: left;
    text-align: right;
    font-size: 80%;
    width: 20%;
    border: none;
}
</style>
<title>FMADM</title>
</head>

<body>
<!--
<div class="fmheader">
<a href="http://ipycoord.met.no/"><img src="profil/ipy-logo.gif"
style="clear:left;border: none;" alt="IPY logo"></a>
<br>
</div>
-->

<?PHP
$fmfadmdir=$mmConfig->getVar('QUEST_ADM_TOPDIR');
# $validuser="steingod";
# $validpw="moose";

require("../qst/funcs/fmquestfuncs.php");

function fmfadm_readdir($dirname) {

    #echo("Now within fmfadm_readdir<br>");
    $myarray = array(
		"filename" => array(),
		"filetype" => array()
		);
    $myrec = 0;
    if (is_dir($dirname)) {
	if ($dh = opendir($dirname)) {
	    while (($file = readdir($dh)) !== false) {
		$myarray["filename"][$myrec] = $file;
		$myarray["filetype"][$myrec] = filetype($dirname.'/'.$file);
		$myrec++;
	    }
	    closedir($dh);
	}
    } else {
	echo(fmcreateerrmsg($dirname." is no directory..."));
    }

    return($myarray);
}

function fmfadm_createview($dirname) {

    $mycontent = fmfadm_readdir($dirname);

    #echo(count($mycontent["filename"]));
    sort($mycontent["filename"]);
    foreach ($mycontent["filename"] as $myrecord) {
	$mylist .= $myrecord."|";
    }

    echo(fmstartform());
    if ($_POST["action"] == "Choose file") {
	echo(fmcreateradio("action","Action","Choose directory|Choose file",2));
    } else {
	echo(fmcreateradio("action","Action","Choose directory|Choose file",1));
    }
    if ($_POST["action"]=="Choose directory") {
	echo(fmcreateselect("mylist[]","Directory listing",$mylist,5,"no",0));
    } else {
	echo(fmcreateselect("mylist[]","File listing",$mylist,5,"yes",0));
    }
    echo(fmcreatehidden("wdir",$dirname));
    if ($_POST["action"]=="Choose file") {
	echo(fmcreatebutton("Submit","Remove files"));
    } else {
	echo(fmcreatebutton("Submit","Continue"));
    }
    echo(fmcreatebutton("Clear","Reset"));
    echo(fmendform());

    return($myselection);
}

function fmfadm_remove_files() {

    $mylist = preg_grep("/^\./",$_POST["mylist"],PREG_GREP_INVERT);

    print_r($mylist);
    echo("<br>");

    foreach ($mylist as $item) {
	if (is_file($_POST["wdir"]."/".$item)) {
	    if (! unlink($_POST["wdir"]."/".$item)) {
		echo(fmcreateerrmsg("Could not remove ".$item));
	    }
	} else {
	    echo(fmcreateerrmsg($item." is not a file within ".$_POST["wdir"]));
	}
    }
}

# if (!isset($_SERVER['PHP_AUTH_USER'])) {
#    header('WWW-Authenticate: Basic realm="My Realm"');
#    header('HTTP/1.0 401 Unauthorized');
#    echo 'You are not allowed to use this service';
#    exit;
# } else {
#    if ($_SERVER["PHP_AUTH_USER"] == "$validuser" && $_SERVER["PHP_AUTH_PW"] == "$validpw") {
#	echo "<p>Logged in as {$_SERVER['PHP_AUTH_USER']}</p>";
#    } else {
#	echo 'You are not allowed to use this service';
#	exit;
#    }
# }

echo(fmcreateh1("FMFADM"));
if ($_POST["Submit"]=="Continue") {
    if (isset($_POST["wdir"])) {
	$mydir = $_POST["wdir"];
	if (! ereg("/$",$mydir)) {
	    $mydir .= "/";
	}
	$mydir .= $_POST["mylist"][0];
    } else {
	$mydir = $fmfadmdir;
	$mydir .= '/' . $_POST["mylist"][0];
    }
    echo(fmcreaterecordstart());
    echo(fmlabelstart());
    echo(fmcreatep("Directory being handled"));
    echo(fmlabelend());
    echo(fminputstart());
    echo(fmcreatep("$mydir"));
    echo(fminputend());
    echo(fmcreaterecordend());
    fmfadm_createview($mydir);
} else if ($_POST["Submit"] == "Remove files") {
    fmfadm_remove_files();
} else {
    fmfadm_createview($fmfadmdir);
}

?>

</body>
</html>
