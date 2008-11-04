<?xml version="1.0" encoding="ISO-8859-1"?>

<!--
    Author     : heikok
    Description: Transformation of an old dataset to the aktual dataset-format
                 Postprocessing needed: The creationDate and status cannot be set
		                        automatically. Using some defaults.
		    
		Try i.e.
		    xsltproc -o newDataset.xml oldDataset2Dataset.xslt oldDataset.xml
-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
    <xsl:output method="xml" indent="yes" encoding="iso8859-1"/>
    
    <xsl:template match="/">
    	<xsl:processing-instruction name="xml-stylesheet">href="https://wiki.met.no/_media/metamod/dataset.xsl" type="text/xsl"</xsl:processing-instruction>
        <xsl:apply-templates select="dataset"/>
    </xsl:template>

    <xsl:template match="dataset">
		<xsl:element name="dataset" xmlns="http://www.met.no/schema/metamod/dataset">
			<xsl:attribute name="schemaLocation" namespace="http://www.w3.org/2001/XMLSchema-instance">http://www.met.no/schema/metamod/dataset2/ metamodDataset2.xsd</xsl:attribute>
        	<xsl:element name="info">
          		<xsl:attribute name="name"><xsl:value-of select="/dataset/drpath"/></xsl:attribute>
          		<xsl:attribute name="status">active</xsl:attribute>
          		<xsl:attribute name="creationDate">2008-10-01T00:00:00Z</xsl:attribute>
          		<xsl:attribute name="ownertag"><xsl:value-of select="@ownertag"/></xsl:attribute>
          		<xsl:attribute name="metadataFormat">MM2</xsl:attribute>
        	</xsl:element>
        	<xsl:apply-templates select="quadtree_nodes"/>
		</xsl:element>    
    </xsl:template>

    <xsl:template match="quadtree_nodes">
        <xsl:element name="quadtree_nodes">
           <xsl:value-of select="."/>
        </xsl:element>
    </xsl:template>
</xsl:stylesheet>
