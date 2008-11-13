<?xml version="1.0" encoding="ISO-8859-1"?>

<!--
    Document   : dif2dataset.xsl
    Created on : November 12, 2008, 1:26 PM
    Author     : heikok
    Description:
        Purpose of transformation follows.
-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
xmlns:dif="http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/"
version="1.0">
    <xsl:output method="xml" encoding="UTF-8" indent="yes"/>

    <xsl:template match="/">
    	<xsl:processing-instruction name="xml-stylesheet">href="dataset.xsl" type="text/xsl"</xsl:processing-instruction>
        <xsl:apply-templates select="dif:DIF"/>
    </xsl:template>
<!-- TODO: DS_datestamp in database is XXX in info? -->
    <xsl:template match="dif:DIF">
        <xsl:element name="dataset" xmlns="http://www.met.no/schema/metamod/dataset">
            <xsl:attribute name="schemaLocation" namespace="http://www.w3.org/2001/XMLSchema-instance">http://www.met.no/schema/metamod/dataset https://wiki.met.no/_media/metamod/dataset.xsd</xsl:attribute>
            <xsl:element name="info">
                <xsl:attribute name="name"><xsl:value-of select="dif:Entry_ID"/></xsl:attribute>
                <xsl:attribute name="status">active</xsl:attribute>
                <xsl:attribute name="creationDate"><xsl:value-of select="dif:DIF_Creation_Date"/>T00:00:00Z</xsl:attribute>
                <xsl:attribute name="ownertag"><xsl:value-of select="dif:Project/dif:Short_Name"/></xsl:attribute>
                <xsl:attribute name="metadataFormat">DIF</xsl:attribute>
            </xsl:element>
         </xsl:element>                
    </xsl:template>


</xsl:stylesheet>
