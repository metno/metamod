<?xml version="1.0" encoding="UTF-8"?>

<xsl:stylesheet version="1.0" xmlns="http://www.met.no/schema/mmd" xmlns:dif="http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:gco="http://www.isotc211.org/2005/gco" xmlns:gmd="http://www.isotc211.org/2005/gmd"
    xmlns:gml="http://www.opengis.net/gml"
    xmlns:mapping="http://www.met.no/schema/mmd/iso2mmd"
    >

    <xsl:output method="xml" indent="yes" />

    <xsl:template match="/gmd:MD_Metadata">
        <xsl:element name="MMD">
            <xsl:apply-templates select="gmd:identificationInfo/gmd:MD_DataIdentification/gmd:citation" />
            <xsl:apply-templates select="gmd:identificationInfo/gmd:MD_DataIdentification/gmd:abstract" />
            <xsl:apply-templates select="gmd:fileIdentifier/gco:CharacterString" />
            <xsl:apply-templates select="gmd:identificationInfo/gmd:MD_DataIdentification/gmd:language/gmd:LanguageCode" />
            <xsl:apply-templates select="gmd:status"/>
            <xsl:apply-templates select="gmd:identificationInfo/gmd:MD_DataIdentification/gmd:topicCategory/gmd:MD_TopicCategoryCode" />
            <xsl:apply-templates select="gmd:identificationInfo/gmd:MD_DataIdentification/gmd:extent/gmd:EX_Extent/gmd:temporalElement/gmd:EX_TemporalExtent/gmd:extent" />
            
            <xsl:element name="geographic_extent">
                <xsl:apply-templates select="gmd:identificationInfo/gmd:MD_DataIdentification/gmd:extent/gmd:EX_Extent/gmd:geographicElement/gmd:EX_GeographicBoundingBox" />
                <xsl:apply-templates select="gmd:identificationInfo/gmd:MD_DataIdentification/gmd:extent/gmd:EX_Extent/gmd:geographicElement/gmd:EX_BoundingPolygon/gmd:polygon" />
            </xsl:element>
            
            <xsl:apply-templates select="gmd:identificationInfo/gmd:MD_DataIdentification/gmd:resourceConstraints/gmd:MD_LegalConstraints/gmd:accessConstraints" />
            <xsl:apply-templates select="gmd:identificationInfo/gmd:MD_DataIdentification/gmd:resourceConstraints/gmd:MD_LegalConstraints/gmd:useConstraints" />
            
        </xsl:element>
    </xsl:template>

    <xsl:template match="gmd:fileIdentifier/gco:CharacterString">
        <xsl:element name="metadata_identifier">
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>

    <xsl:template match="gmd:citation">
        <xsl:element name="title">
            <xsl:attribute name="xml:lang">en_GB</xsl:attribute>
            <xsl:value-of select="gmd:CI_Citation/gmd:title/gco:CharacterString" />
        </xsl:element>
    </xsl:template>

    <xsl:template match="gmd:abstract">
        <xsl:element name="abstract">
            <xsl:attribute name="xml:lang">en_GB</xsl:attribute>
            <xsl:value-of select="gco:CharacterString" />
        </xsl:element>
    </xsl:template>

    <xsl:template match="gmd:language/gmd:LanguageCode">
        <xsl:element name="dataset_language">
            <xsl:value-of select="." />
        </xsl:element>    
    </xsl:template>

    <xsl:template match="gmd:status">        
        <xsl:variable name="iso_status" select="normalize-space(.)" />
        <xsl:variable name="iso_status_mapping" select="document('')/*/mapping:dataset_status[@iso=$iso_status]" />
        <xsl:value-of select="$iso_status_mapping" />
        <xsl:element name="dataset_status">
            <xsl:value-of select="$iso_status_mapping/@mmd"></xsl:value-of>                    
        </xsl:element>    
    </xsl:template>


    <!-- mapping between iso and mmd dataset statuses -->
    <mapping:dataset_status iso="completed" mmd="Complete" />
    <mapping:dataset_status iso="historicalArchive" mmd="Complete" />
    <mapping:dataset_status iso="obsolete" mmd="Complete" />
    <mapping:dataset_status iso="onGoing" mmd="In Work" />
    <mapping:dataset_status iso="planned" mmd="Planned" />
    <mapping:dataset_status iso="required" mmd="Planned" />
    <mapping:dataset_status iso="underDevelopment" mmd="In Work" />

    <xsl:template match="gmd:identificationInfo/gmd:MD_DataIdentification/gmd:topicCategory/gmd:MD_TopicCategoryCode">
        <xsl:element name="iso_topic_category">
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>    
    
    <xsl:template match="gmd:identificationInfo/gmd:MD_DataIdentification/gmd:extent/gmd:EX_Extent/gmd:temporalElement/gmd:EX_TemporalExtent/gmd:extent">    
        <xsl:element name="temporal_extent">        
            <xsl:element name="start_date">
                <xsl:value-of select="gml:TimePeriod/gml:beginPosition" />
            </xsl:element>
            <xsl:element name="end_date">
                <xsl:value-of select="gml:TimePeriod/gml:endPosition" />
            </xsl:element>
        </xsl:element>    
    </xsl:template>
    
    <xsl:template match="gmd:identificationInfo/gmd:MD_DataIdentification/gmd:extent/gmd:EX_Extent/gmd:geographicElement/gmd:EX_GeographicBoundingBox">    
        <xsl:element name="rectangle">
            <xsl:element name="north">
                <xsl:value-of select="gmd:northBoundLatitude/gco:Decimal" />
            </xsl:element>
            <xsl:element name="south">
                <xsl:value-of select="gmd:southBoundLatitude/gco:Decimal" />
            </xsl:element>
            <xsl:element name="west">
                <xsl:value-of select="gmd:westBoundLongitude/gco:Decimal" />
            </xsl:element>
            <xsl:element name="east">
                <xsl:value-of select="gmd:eastBoundLongitude/gco:Decimal" />
            </xsl:element>    
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="gmd:identificationInfo/gmd:MD_DataIdentification/gmd:extent/gmd:EX_Extent/gmd:geographicElement/gmd:EX_BoundingPolygon/gmd:polygon">
        <xsl:element name="polygon">
            <xsl:copy-of select="gml:Polygon" />                
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="gmd:identificationInfo/gmd:MD_DataIdentification/gmd:resourceConstraints/gmd:MD_LegalConstraints/gmd:accessConstraints">
        <xsl:element name="access_constraint">
            <xsl:choose>
                <xsl:when test="gmd:MD_RestrictionCode[@codeListValue='otherConstraints']">
                    <xsl:value-of select="../gmd:otherConstraints/gco:CharacterString" />
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="gmd:MD_RestrictionCode/@codeListValue" />
                </xsl:otherwise>
            </xsl:choose>        
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="gmd:identificationInfo/gmd:MD_DataIdentification/gmd:resourceConstraints/gmd:MD_LegalConstraints/gmd:useConstraints">
        <xsl:element name="use_constraint">
            <xsl:choose>
                <xsl:when test="gmd:MD_RestrictionCode[@codeListValue='otherConstraints']">
                    <xsl:value-of select="../gmd:otherConstraints/gco:CharacterString" />
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="gmd:MD_RestrictionCode/@codeListValue" />
                </xsl:otherwise>
            </xsl:choose>        
        </xsl:element>
    </xsl:template>    
    
</xsl:stylesheet>
