<?xml version="1.0" encoding="ISO-8859-1"?>

<!--
    Document   : metamodDatasetChanger.xsl
    Created on : October 21, 2008, 2:07 PM
    Author     : heikok
    Description: Transformation of dataset to dataset2
                 Postprocessing needed: The creationDate info cannot be set
		                        automatically!
		    
		Try i.e.
		    xsltproc -o dataset2.xml metamodDatasetChanger.xsl dataset.xml
-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
    <xsl:output method="xml" indent="yes" encoding="iso8859-1"/>
    
    <xsl:template match="/">
    	<xsl:processing-instruction name="xml-stylesheet">href="dataset2View.xsl" type="text/xsl"</xsl:processing-instruction>
        <xsl:apply-templates select="dataset"/>
    </xsl:template>

    <xsl:template match="dataset">
		<xsl:element name="dataset" xmlns="http://www.met.no/schema/metamod/dataset2/">
			<xsl:attribute name="schemaLocation" namespace="http://www.w3.org/2001/XMLSchema-instance">http://www.met.no/schema/metamod/dataset2/ metamodDataset2.xsd</xsl:attribute>
        	<xsl:element name="info">
          		<xsl:attribute name="status">active</xsl:attribute>
          		<xsl:attribute name="creationDate">YYYY-MM-DDTHH:MM:SSZ</xsl:attribute>
          		<xsl:attribute name="ownertag"><xsl:value-of select="@ownertag"/></xsl:attribute>
          		<xsl:attribute name="drpath"><xsl:value-of select="/dataset/drpath"/></xsl:attribute>
        	</xsl:element>
        	<xsl:apply-templates select="datacollection_period" />
        	<xsl:apply-templates select="datacollection_period_from"/>
        	<xsl:apply-templates select="quadtree_nodes"/>
        	<xsl:for-each select="*[not(self::datacollection_period|self::dataset|self::datacollection_period_from|self::datacollection_period_to|self::datacollection_period|self::drpath|self::quadtree_nodes)]">
           		<xsl:call-template name="metadata"/>
        	</xsl:for-each>
		</xsl:element>    
    </xsl:template>

    <xsl:template match="datacollection_period">
        <xsl:element name="datacollection_period">
           <xsl:attribute name="from"><xsl:value-of select="@from"/></xsl:attribute>
           <xsl:attribute name="to"><xsl:value-of select="@to"/></xsl:attribute>
         </xsl:element>
    </xsl:template>

    <xsl:template match="datacollection_period_from">
        <xsl:element name="datacollection_period">
           <xsl:attribute name="from"><xsl:value-of select="/dataset/datacollection_period_from"/></xsl:attribute>
          <xsl:attribute name="to"><xsl:value-of select="/dataset/datacollection_period_to"/></xsl:attribute>
        </xsl:element>
    </xsl:template>

    <xsl:template match="quadtree_nodes">
        <xsl:element name="quadtree_nodes">
           <xsl:value-of select="."/>
        </xsl:element>
    </xsl:template>

    
    <xsl:template name="metadata">
        <xsl:element name="metadata">
            <xsl:attribute name="name"><xsl:value-of select="name()"/></xsl:attribute>
            <xsl:value-of select="."/>
        </xsl:element>
    </xsl:template>
</xsl:stylesheet>
