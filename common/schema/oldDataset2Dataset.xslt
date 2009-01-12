<?xml version="1.0" encoding="ISO-8859-1"?>

<!--
    Author     : heikok
    Description: Transformation of an old dataset to the aktual dataset-format
                 Postprocessing needed: The creationDate and status cannot be set
		                        automatically. Using some defaults.
		    
		Try i.e.
		    xsltproc -o newDataset.xml oldDataset2Dataset.xslt oldDataset.xml

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

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
    <xsl:output method="xml" indent="yes" encoding="iso8859-1"/>
    
    <xsl:template match="/">
        <xsl:apply-templates select="dataset"/>
    </xsl:template>

    <xsl:template match="dataset">
		<xsl:element name="dataset" xmlns="http://www.met.no/schema/metamod/dataset">
			<xsl:attribute name="schemaLocation" namespace="http://www.w3.org/2001/XMLSchema-instance">http://www.met.no/schema/metamod/dataset https://wiki.met.no/_media/metamod/dataset.xsd</xsl:attribute>
        	<xsl:element name="info" xmlns="http://www.met.no/schema/metamod/dataset">
          		<xsl:attribute name="name"><xsl:value-of select="/dataset/drpath"/></xsl:attribute>
          		<xsl:attribute name="status">active</xsl:attribute>
          		<xsl:attribute name="creationDate">2008-10-01T00:00:00Z</xsl:attribute>
          		<xsl:attribute name="datestamp">2008-10-01T00:00:00Z</xsl:attribute>
          		<xsl:attribute name="ownertag"><xsl:value-of select="@ownertag"/></xsl:attribute>
          		<xsl:attribute name="metadataFormat">MM2</xsl:attribute>
        	</xsl:element>
        	<xsl:apply-templates select="quadtree_nodes"/>
		</xsl:element>    
    </xsl:template>

    <xsl:template match="quadtree_nodes">
        <xsl:element name="quadtree_nodes" xmlns="http://www.met.no/schema/metamod/dataset">
           <xsl:value-of select="."/>
        </xsl:element>
    </xsl:template>
</xsl:stylesheet>
