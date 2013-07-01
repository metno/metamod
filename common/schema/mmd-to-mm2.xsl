<?xml version="1.0" encoding="UTF-8"?>

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:mm2="http://www.met.no/schema/metamod/MM2"
    xmlns:mmd="http://www.met.no/schema/mmd"
    xmlns="http://www.met.no/schema/mmd"
    xmlns:mapping="http://www.met.no/schema/metamod/mmd2mm2"
    xmlns:xmd="http://www.met.no/schema/metamod/dataset" version="1.0">

    <xsl:output method="xml" encoding="UTF-8" indent="yes" />
    <xsl:strip-space elements="*"/>

    <xsl:template match="/mmd:mmd">
        <xsl:element name="mm2:mm2">

            <xsl:apply-templates select="mmd:title[@xml:lang='en']" />
            <xsl:apply-templates select="mmd:abstract[@xml:lang='en']" />
            <xsl:apply-templates select="mmd:last_metadata_update" />
            <xsl:apply-templates select="mmd:iso_topic_category" />
            <xsl:apply-templates select="mmd:keywords" />
            <xsl:apply-templates select="mmd:project" />
            <xsl:apply-templates select="mmd:temporal_extent" />
            <xsl:apply-templates select="mmd:geographic_extent/mmd:rectangle" />
            <xsl:apply-templates select="mmd:data_access" />
            <xsl:apply-templates select="mmd:access_constraint" />
            <xsl:apply-templates select="mmd:personnel[mmd:role='Investigator']"/>

        </xsl:element>
    </xsl:template>


    <xsl:template match="mmd:title[@xml:lang='en']">
        <xsl:element name="mm2:metadata">
            <xsl:attribute name="name">title</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>

    <xsl:template match="mmd:abstract[@xml:lang='en']">
        <xsl:element name="mm2:metadata">
            <xsl:attribute name="name">abstract</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>

    <xsl:template match="mmd:last_metadata_update">
        <xsl:element name="mm2:metadata">
            <xsl:attribute name="name">dif:Last_DIF_Revision_Date</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>

    <xsl:template match="mmd:iso_topic_category">
        <xsl:element name="mm2:metadata">
            <xsl:attribute name="name">topiccategory</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>

    <xsl:template match="mmd:temporal_extent">

        <xsl:element name="mm2:metadata">
            <xsl:attribute name="name">datacollection_period_from</xsl:attribute>
            <xsl:value-of select="mmd:start_date" />
        </xsl:element>
        <xsl:element name="mm2:metadata">
            <xsl:attribute name="name">datacollection_period_to</xsl:attribute>
            <xsl:value-of select="mmd:end_date" />
        </xsl:element>

    </xsl:template>

    <xsl:template match="mmd:data_access">
        <xsl:element name="mm2:metadata">
            <xsl:attribute name="name">dataref</xsl:attribute>
            <xsl:value-of select="mmd:resource" />
        </xsl:element>
    </xsl:template>

    <xsl:template match="mmd:geographic_extent/mmd:rectangle">
        <!-- MM2 bounding box format is ESWN -->
        <xsl:element name="mm2:metadata">
            <xsl:attribute name="name">bounding_box</xsl:attribute>
            <xsl:value-of select="mmd:east" />,<xsl:value-of select="mmd:south" />,<xsl:value-of select="mmd:west" />,<xsl:value-of select="mmd:north" />
        </xsl:element>
    </xsl:template>

    <xsl:template match="mmd:access_constraint">
        <xsl:element name="mm2:metadata">
            <xsl:attribute name="name">distribution_statement</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>

    <xsl:template match="mmd:project">
        <xsl:element name="mm2:metadata">
            <xsl:attribute name="name">project_name</xsl:attribute>
            <xsl:value-of select="mmd:long_name" />
        </xsl:element>
    </xsl:template>

    <xsl:template match="mmd:keywords[@vocabulary='none']">

        <xsl:for-each select="mmd:keyword">
            <xsl:element name="mm2:metadata">
                <xsl:attribute name="name">keywords</xsl:attribute>
                <xsl:value-of select="." />
            </xsl:element>
        </xsl:for-each>
    </xsl:template>

    <xsl:template match="mmd:keywords[@vocabulary='cf']">
        <xsl:element name="mm2:metadata">
            <xsl:attribute name="name">variable</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>

    <xsl:template match="mmd:keywords[@vocabulary='gcmd']">
        <xsl:element name="mm2:metadata">
            <xsl:attribute name="name">variable</xsl:attribute>
            <xsl:value-of select="keyword" />
        </xsl:element>
    </xsl:template>

    <xsl:template match="mmd:personnel[mmd:role='Investigator']">

        <xsl:element name="mm2:metadata">
            <xsl:attribute name="name">PI_name</xsl:attribute>
            <xsl:value-of select="mmd:name" />
        </xsl:element>
        <xsl:element name="mm2:metadata">
            <xsl:attribute name="name">contact</xsl:attribute>
            <xsl:value-of select="mmd:email" />
        </xsl:element>


    </xsl:template>


</xsl:stylesheet>
