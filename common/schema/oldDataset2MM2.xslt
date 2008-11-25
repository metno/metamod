<?xml version="1.0" encoding="ISO-8859-1"?>

<!--
    Author     : heikok
    Description: Transformation of old dataset to MM2
		    
		Try i.e.
		    xsltproc -o newMM2.xml oldDataset2MM2.xslt oldDataset.xml
-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
    <xsl:output method="xml" indent="yes" encoding="iso8859-1"/>
    
    <xsl:template match="/">
    	<xsl:processing-instruction name="xml-stylesheet">href="dataset.xsl" type="text/xsl"</xsl:processing-instruction>
        <xsl:apply-templates select="dataset"/>
    </xsl:template>

    <xsl:template match="dataset">
		<xsl:element name="MM2" xmlns="http://www.met.no/schema/metamod/MM2">
			<xsl:attribute name="schemaLocation" namespace="http://www.w3.org/2001/XMLSchema-instance">http://www.met.no/schema/metamod/MM2 https://wiki.met.no/_media/metamod/mm2.xsd</xsl:attribute>
        	<xsl:apply-templates select="datacollection_period" />
        	<!-- select the bounding box if one of the borders is found -->
			<xsl:apply-templates select="easternmost_longitude" /> 
        	<!--  quadtree_nodes in dataset, not in metadata -->
        	<xsl:for-each select="*[not(self::dataset|self::datacollection_period|self::drpath|self::quadtree_nodes|self::northernmost_latitude|self::southernmost_latitude|self::easternmost_longitude|self::westernmost_longitude)]">
           		<xsl:call-template name="metadata"/>
        	</xsl:for-each>
		</xsl:element>    
    </xsl:template>

    <xsl:template match="datacollection_period">
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
           <xsl:attribute name="name">datacollection_period_from</xsl:attribute>
           <xsl:value-of select="@from"/>
        </xsl:element>
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
           <xsl:attribute name="name">datacollection_period_to</xsl:attribute>
           <xsl:value-of select="@to"/>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="easternmost_longitude">
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
           <xsl:attribute name="name">bounding_box</xsl:attribute>
           <xsl:value-of select="."/>,<xsl:value-of select="/dataset/southernmost_latitude"/>,<xsl:value-of select="/dataset/westernmost_longitude"/>,<xsl:value-of select="/dataset/northernmost_latitude"/>
        </xsl:element>
    </xsl:template>

    
    <xsl:template name="metadata">
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name"><xsl:value-of select="name()"/></xsl:attribute>
            <xsl:value-of select="."/>
        </xsl:element>
    </xsl:template>
</xsl:stylesheet>
