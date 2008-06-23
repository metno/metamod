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
div.fmheader {
    /*
    background: url("/logos/ipy_panorama_small.png");
    border-bottom: solid thin;
    */
    margin-bottom: 2em;
    padding-left: 5px;
}
div.fmsection {
    /*
    background: #ffffff;
    background: #000000;
    color: #aaaaaa;
    */
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
    /*
    background: black;
    */
}
legend {
    font-family: Sans serif;
    font-weight: bold;
    font-size: 14pt;
}
</style>
<title>IPY operational meta data form</title>
</head>

<body>
<div class="fmheader">
<a href="http://ipycoord.met.no/"><img src="/logos/ipy-logo.gif"
style="clear:left;border: none;" alt="IPY logo"></a><br>
<img src="/logos/ipy_panorama_small.png" alt="IPY Panorama" style="width:
100%; border: solid thin;margin-top: 5px;">
<br>
</div>

<?PHP
$fmquestconfig="config/metamod2-meta-config.txt";
if ($_SERVER['SERVER_NAME'] == "tuba.oslo.dnmi.no") {
    $fmquestoutput=$_SERVER['DOCUMENT_ROOT']."/data/ipycoord";
} else if ($_SERVER['SERVER_NAME'] == "ipycoord.met.no") {
    $fmquestoutput="/metno/ipycoord/data/fmmeta";
} else {
    $fmquestoutput=$_SERVER['DOCUMENT_ROOT']."/htdocs/test/data/ipycoord";
}
$mysender = "ipycoord@met.no";
$myrecipents = "o.godoy@met.no";
$myokmsg = "Thanks for submitting information! Push here to <a href=\"/\">get home</a>.";

require("funcs/fmquestfuncs.php");

if ($_POST["Submit"] == "Check form") {
    fmcheckform($fmquestconfig);
} elseif ($_POST["Submit"] == "Write form") {
    fmprocessform($fmquestoutput,$myokmsg,$mysender,$myrecipents);
} else {
    fmcreateform($fmquestconfig);
}
?>

</body>
</html>
