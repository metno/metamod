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
session_start(  );
/** session-data:
 *  tempDataset: temporary dataset-information
 *               - generated on checking
 *               - read on re-edit
 *               - deleted after writing dataset to permanent storage in fmprocessform 
 */
 
 require_once("../funcs/mmConfig.inc"); # defines also $mmConfig
?>
<html>

<head>
<META http-equiv="Generator" content="Øystein Godøy, METNO/FOU">
<META http-equiv="Content-Type" content="text/html; charset=UTF-8">
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
div.fmsection {
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
fieldset {
    color: black;
    border: solid thin;
    padding: 3px;
}
legend {
    font-family: Sans serif;
    font-weight: bold;
    font-size: 14pt;
}
</style>
<title><?PHP echo $mmConfig->getVar('QUEST_TITLE','htdocs/qst/quest.php', __FILE__) ?></title>
</head>

<body>
<?PHP echo $mmConfig->getVar('APP_HEADER_HTML') ?>



<?PHP
$fmquestconfig=$mmConfig->getVar('QUEST_FORM_DEFINITON_FILE','htdocs/qst/quest.php', __FILE__);
$fmquestoutput=$mmConfig->getVar('QUEST_OUTPUT_DIRECTORY','htdocs/qst/quest.php', __FILE__);
$mysender = $mmConfig->getVar('QUEST_SENDER_ADDRESS');
$myrecipents = $mmConfig->getVar('QUEST_RECIPIENTS');
$myokmsg = $mmConfig->getVar('QUEST_OKMESSAGE');

require("funcs/fmquestfuncs.php");

if ($_POST["Submit"] == "Check form") {
    fmcheckform($fmquestoutput, $fmquestconfig);
} elseif ($_POST["Submit"] == "Write form") {
    fmprocessform($fmquestoutput,$myokmsg,$mysender,$myrecipents);
} elseif ($_POST["Submit"] == "Edit form") {
	fmcreateform($fmquestoutput, $fmquestconfig, true);
} else {
    fmcreateform($fmquestoutput, $fmquestconfig);
}
?>

<?PHP echo $mmConfig->getVar('APP_FOOTER_HTML') ?>
</body>
</html>
