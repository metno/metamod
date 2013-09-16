<?xml version="1.0" encoding="UTF-8"?>

<xsl:stylesheet version="1.0" xmlns="http://www.met.no/schema/mmd" xmlns:dif="http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:gco="http://www.isotc211.org/2005/gco" xmlns:gmd="http://www.isotc211.org/2005/gmd"
    xmlns:gml="http://www.opengis.net/gml"
    xmlns:mmd="http://www.met.no/schema/mmd"
    xmlns:mapping="http://www.met.no/schema/mmd/iso2mmd"
    >

    <xsl:output method="xml" indent="yes" />

    <xsl:template match="/gmd:MD_Metadata">
        <xsl:element name="mmd:mmd">
        
            <mmd:metadata_version>1</mmd:metadata_version>
        
            <xsl:apply-templates select="gmd:identificationInfo/gmd:MD_DataIdentification/gmd:citation" />
            <xsl:apply-templates select="gmd:identificationInfo/gmd:MD_DataIdentification/gmd:abstract" />
            <xsl:apply-templates select="gmd:fileIdentifier/gco:CharacterString" />
            <xsl:apply-templates select="gmd:identificationInfo/gmd:MD_DataIdentification/gmd:language" />
            <xsl:apply-templates select="gmd:identificationInfo/gmd:MD_DataIdentification/gmd:status"/>
            <xsl:apply-templates select="gmd:identificationInfo/gmd:MD_DataIdentification/gmd:topicCategory/gmd:MD_TopicCategoryCode" />
            <xsl:apply-templates select="gmd:identificationInfo/gmd:MD_DataIdentification/gmd:extent/gmd:EX_Extent/gmd:temporalElement/gmd:EX_TemporalExtent/gmd:extent" />
            
            <xsl:apply-templates select="gmd:contact/gmd:CI_ResponsibleParty" />
            
            <xsl:apply-templates select="gmd:identificationInfo/gmd:MD_DataIdentification/gmd:descriptiveKeywords/gmd:MD_Keywords" />
            
            <xsl:element name="mmd:geographic_extent">
                <xsl:apply-templates select="gmd:identificationInfo/gmd:MD_DataIdentification/gmd:extent/gmd:EX_Extent/gmd:geographicElement/gmd:EX_GeographicBoundingBox" />
                <xsl:apply-templates select="gmd:identificationInfo/gmd:MD_DataIdentification/gmd:extent/gmd:EX_Extent/gmd:geographicElement/gmd:EX_BoundingPolygon/gmd:polygon" />
            </xsl:element>
            
            <xsl:apply-templates select="gmd:distributionInfo/gmd:MD_Distribution/gmd:transferOptions/gmd:MD_DigitalTransferOptions/gmd:onLine" />
            
            <xsl:apply-templates select="gmd:identificationInfo/gmd:MD_DataIdentification/gmd:resourceConstraints/gmd:MD_LegalConstraints/gmd:accessConstraints" />
            <xsl:apply-templates select="gmd:identificationInfo/gmd:MD_DataIdentification/gmd:resourceConstraints/gmd:MD_LegalConstraints/gmd:useConstraints" />
                        
            
        </xsl:element>
    </xsl:template>

    <xsl:template match="gmd:fileIdentifier/gco:CharacterString">
        <xsl:element name="mmd:metadata_identifier">
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>

    <xsl:template match="gmd:citation">
        <xsl:element name="mmd:title">
            <xsl:attribute name="xml:lang">en</xsl:attribute>
            <xsl:value-of select="gmd:CI_Citation/gmd:title/gco:CharacterString" />
        </xsl:element>
    </xsl:template>

    <xsl:template match="gmd:abstract">
        <xsl:element name="mmd:abstract">
            <xsl:attribute name="xml:lang">en</xsl:attribute>
            <xsl:value-of select="gco:CharacterString" />
        </xsl:element>
    </xsl:template>

    <xsl:template match="gmd:language">
        <xsl:element name="mmd:dataset_language">
            <xsl:choose>
                <xsl:when test="gmd:LanguageCode">
                    <xsl:value-of select="gmd:LanguageCode" />    
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="gco:CharacterString" />
                </xsl:otherwise>
            </xsl:choose>
            
        </xsl:element>    
    </xsl:template>

    <xsl:template match="gmd:status">        
        <xsl:variable name="iso_status" select="normalize-space(gmd:MD_ProgressCode/@codeListValue)" />
        <xsl:variable name="iso_status_mapping" select="document('')/*/mapping:dataset_status[@iso=$iso_status]" />
        <xsl:value-of select="$iso_status_mapping" />
        <xsl:element name="mmd:dataset_production_status">
            <xsl:value-of select="$iso_status_mapping/@mmd"></xsl:value-of>                    
        </xsl:element>    
    </xsl:template>


    <!-- mapping between iso and mmd dataset statuses -->
    <mapping:dataset_status iso="completed" mmd="Complete" />
    <mapping:dataset_status iso="historicalArchive" mmd="Complete" />
    <mapping:dataset_status iso="obsolete" mmd="Obsolete" />
    <mapping:dataset_status iso="onGoing" mmd="In Work" />
    <mapping:dataset_status iso="planned" mmd="Planned" />
    <mapping:dataset_status iso="required" mmd="Planned" />
    <mapping:dataset_status iso="underDevelopment" mmd="Planned" />

    <xsl:template match="gmd:identificationInfo/gmd:MD_DataIdentification/gmd:topicCategory/gmd:MD_TopicCategoryCode">
        <xsl:element name="mmd:iso_topic_category">
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>    
    
    <xsl:template match="gmd:identificationInfo/gmd:MD_DataIdentification/gmd:extent/gmd:EX_Extent/gmd:temporalElement/gmd:EX_TemporalExtent/gmd:extent">    
        <xsl:element name="mmd:temporal_extent">        
            <xsl:element name="mmd:start_date">
                <xsl:value-of select="gml:TimePeriod/gml:beginPosition" />
            </xsl:element>
            <xsl:element name="mmd:end_date">
                <xsl:value-of select="gml:TimePeriod/gml:endPosition" />
            </xsl:element>
        </xsl:element>    
    </xsl:template>
    
    <xsl:template match="gmd:identificationInfo/gmd:MD_DataIdentification/gmd:extent/gmd:EX_Extent/gmd:geographicElement/gmd:EX_GeographicBoundingBox">    
        <xsl:element name="mmd:rectangle">
            <xsl:element name="mmd:north">
                <xsl:value-of select="gmd:northBoundLatitude/gco:Decimal" />
            </xsl:element>
            <xsl:element name="mmd:south">
                <xsl:value-of select="gmd:southBoundLatitude/gco:Decimal" />
            </xsl:element>
            <xsl:element name="mmd:west">
                <xsl:value-of select="gmd:westBoundLongitude/gco:Decimal" />
            </xsl:element>
            <xsl:element name="mmd:east">
                <xsl:value-of select="gmd:eastBoundLongitude/gco:Decimal" />
            </xsl:element>    
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="gmd:identificationInfo/gmd:MD_DataIdentification/gmd:extent/gmd:EX_Extent/gmd:geographicElement/gmd:EX_BoundingPolygon/gmd:polygon">
        <xsl:element name="mmd:polygon">
            <xsl:copy-of select="gml:Polygon" />                
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="gmd:identificationInfo/gmd:MD_DataIdentification/gmd:resourceConstraints/gmd:MD_LegalConstraints/gmd:accessConstraints">
        <xsl:element name="mmd:access_constraint">
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
        <xsl:element name="mmd:use_constraint">
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
    
    <xsl:template match="gmd:contact/gmd:CI_ResponsibleParty">
        <xsl:element name="mmd:personnel">
            <xsl:element name="mmd:role">
                <xsl:choose>
                    <xsl:when test="gmd:role/gmd:CI_RoleCode[@codeListValue='principalInvestigator']">
                        <xsl:text>Principal investigator</xsl:text>
                    </xsl:when>
                    <xsl:when test="gmd:role/gmd:CI_RoleCode[@codeListValue='pointOfContact']">
                        <xsl:text>Technical contact</xsl:text>
                    </xsl:when>
                    <xsl:when test="gmd:role/gmd:CI_RoleCode[@codeListValue='author']">
                        <xsl:text>Metadata author</xsl:text>
                    </xsl:when>                    
                    <xsl:otherwise>
                        <xsl:text>Technical contact</xsl:text>
                    </xsl:otherwise>
                </xsl:choose>            
            </xsl:element>
            
            <xsl:element name="mmd:name">
                <xsl:value-of select="gmd:individualName/gco:CharacterString" />
            </xsl:element>
            
            <xsl:element name="mmd:organisation">
                <xsl:value-of select="gmd:organisationName/gco:CharacterString" />
            </xsl:element>
            
            <xsl:element name="mmd:email">
                <xsl:value-of select="gmd:contactInfo/gmd:CI_Contact/gmd:address/gmd:CI_Address/gmd:electronicMailAddress/gco:CharacterString" />
            </xsl:element>

            <xsl:element name="mmd:phone">
                <xsl:value-of select="gmd:contactInfo/gmd:CI_Contact/gmd:phone/gmd:CI_Telephone/gmd:voice/gco:CharacterString" />
            </xsl:element>

            <xsl:element name="mmd:fax">
                <xsl:value-of select="gmd:contactInfo/gmd:CI_Contact/gmd:phone/gmd:CI_Telephone/gmd:facsimile/gco:CharacterString" />
            </xsl:element>

            <xsl:element name="mmd:contact_address">
                <xsl:element name="mmd:address">
                    <xsl:value-of select="gmd:contactInfo/gmd:CI_Contact/gmd:address/gmd:CI_Address/gmd:deliveryPoint/gco:CharacterString" />
                </xsl:element>
                <xsl:element name="mmd:city">
                    <xsl:value-of select="gmd:contactInfo/gmd:CI_Contact/gmd:address/gmd:CI_Address/gmd:city/gco:CharacterString" />
                </xsl:element>
                <xsl:element name="mmd:province_or_state">
                    <xsl:value-of select="gmd:contactInfo/gmd:CI_Contact/gmd:address/gmd:CI_Address/gmd:administrativeArea/gco:CharacterString" />
                </xsl:element>
                <xsl:element name="mmd:postal_code">
                    <xsl:value-of select="gmd:contactInfo/gmd:CI_Contact/gmd:address/gmd:CI_Address/gmd:postalCode/gco:CharacterString" />
                </xsl:element>
                <xsl:element name="mmd:country">
                    <xsl:value-of select="gmd:contactInfo/gmd:CI_Contact/gmd:address/gmd:CI_Address/gmd:country/gco:CharacterString" />
                </xsl:element>            
            </xsl:element>            
            
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="gmd:distributionInfo/gmd:MD_Distribution/gmd:transferOptions/gmd:MD_DigitalTransferOptions/gmd:onLine">
    
        <xsl:element name="mmd:data_access">
            <xsl:element name="mmd:type">
                <xsl:value-of select="gmd:CI_OnlineResource/gmd:protocol/gco:CharacterString" />
            </xsl:element>
            <xsl:element name="mmd:name">
                <xsl:value-of select="gmd:CI_OnlineResource/gmd:name/gco:CharacterString" />
            </xsl:element>
            <xsl:element name="mmd:resource">
                <xsl:value-of select="gmd:CI_OnlineResource/gmd:linkage/gmd:URL" />
            </xsl:element>                        
            <xsl:element name="mmd:description">
                <xsl:value-of select="gmd:CI_OnlineResource/gmd:description/gco:CharacterString" />
            </xsl:element>                                    
        </xsl:element>
    
    </xsl:template>
    
    <xsl:template match="gmd:descriptiveKeywords/gmd:MD_Keywords">
    
        <xsl:element name="mmd:keywords">
            <xsl:attribute name="vocabulary">none</xsl:attribute>
            <xsl:apply-templates select="gmd:keyword" />
        </xsl:element>
    
    </xsl:template>
    
    <xsl:template match="gmd:keyword">
        <xsl:element name="mmd:keyword">
            <xsl:value-of select="gco:CharacterString" />
        </xsl:element>
    </xsl:template>
    
</xsl:stylesheet>
