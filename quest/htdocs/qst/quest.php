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
<title>[==QUEST_TITLE==]</title>
</head>

<body>
[==APP_HEADER_HTML==]

<?PHP
$fmquestconfig="[==QUEST_FORM_DEFINITON_FILE==]";
if ($_SERVER['SERVER_NAME'] == "tuba.oslo.dnmi.no") {
    $fmquestoutput=$_SERVER['DOCUMENT_ROOT']."/data/ipycoord";
} else {
    $fmquestoutput="[==QUEST_OUTPUT_DIRECTORY==]";
}
$mysender = "[==QUEST_SENDER_ADDRESS==]";
$myrecipents = "[==QUEST_RECIPIENTS==]";
$myokmsg = <<<END_STRING
[==QUEST_OKMESSAGE==]
END_STRING;

require("funcs/fmquestfuncs.php");

if ($_POST["Submit"] == "Check form") {
    fmcheckform($fmquestconfig);
} elseif ($_POST["Submit"] == "Write form") {
    fmprocessform($fmquestoutput,$myokmsg,$mysender,$myrecipents);
} else {
    fmcreateform($fmquestconfig);
}
?>

[==APP_FOOTER_HTML==]
</body>
</html>
