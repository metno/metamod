<?xml version="1.0" encoding="ISO-8859-1"?>

<!--
    Document   : dif2dataset.xsl
    Created on : November 12, 2008, 1:26 PM
    Author     : heikok
    Description: Transformation of DIF to dataset (.xmd) format
    License    :
METAMOD - Web portal for metadata search and upload

Copyright (C) 2008 met.no
Contact information:
Norwegian Meteorological Institute
Box 43 Blindern
0313 OSLO
NORWAY
email: Heiko.Klein@met.no

This file is part of METAMOD

METAMOD is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

METAMOD is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with METAMOD; if not, write to the Free Software
Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
xmlns:dif="http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/"
version="1.0">
    <xsl:output method="xml" encoding="UTF-8" indent="yes"/>

    <xsl:template match="/">
        <xsl:apply-templates select="dif:DIF"/>
    </xsl:template>
    <xsl:template match="dif:DIF">
        <xsl:element name="dataset" xmlns="http://www.met.no/schema/metamod/dataset">
            <xsl:attribute name="schemaLocation" namespace="http://www.w3.org/2001/XMLSchema-instance">http://www.met.no/schema/metamod/dataset https://wiki.met.no/_media/metamod/dataset.xsd</xsl:attribute>
            <xsl:element name="info">
                <xsl:attribute name="name"><xsl:value-of select="dif:Entry_ID"/></xsl:attribute>
                <xsl:attribute name="status">active</xsl:attribute>
                <xsl:attribute name="creationDate"><xsl:value-of select="dif:DIF_Creation_Date"/></xsl:attribute>
                <xsl:attribute name="datestamp"><xsl:value-of select="dif:Last_DIF_Revision_Date"/></xsl:attribute>
                <xsl:attribute name="ownertag"><xsl:value-of select="dif:Project/dif:Short_Name"/></xsl:attribute>
                <xsl:attribute name="metadataFormat">DIF</xsl:attribute>
            </xsl:element>
         </xsl:element>                
    </xsl:template>


</xsl:stylesheet>
