<?xml version="1.0" encoding="UTF-8"?>

<!-- WARNING! This XSL transformation relies on the following libxslt-specific functions: str:split, com:nodeset -->

<xsl:stylesheet version="1.0"
                xmlns:dif="http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:gco="http://www.isotc211.org/2005/gco"
                xmlns:gmd="http://www.isotc211.org/2005/gmd"
                xmlns:str="http://exslt.org/strings"
                xmlns:com="http://exslt.org/common"
                extension-element-prefixes="str com">

  <xsl:output method="xml" indent="yes"/>

  <xsl:template match="gmd:MD_Metadata">
    <DIF xsi:schemaLocation="http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/ http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/dif_v9.7.1.xsd"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xmlns="http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/">
      <Entry_ID>
        <xsl:value-of select="/gmd:MD_Metadata/gmd:fileIdentifier/gco:CharacterString"/>
      </Entry_ID>
      <Entry_Title>
        <xsl:copy-of select="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:citation/gmd:CI_Citation/gmd:title/gco:CharacterString/child::text()"/>
      </Entry_Title>
      <Data_Set_Citation>
        <xsl:if test="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:pointOfContact/gmd:CI_ResponsibleParty[gmd:role/gmd:CI_RoleCode/@codeListValue='principalInvestigator']/gmd:individualName">
          <Dataset_Creator>
             <xsl:value-of select="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:pointOfContact/gmd:CI_ResponsibleParty[gmd:role/gmd:CI_RoleCode/@codeListValue='principalInvestigator']/gmd:individualName/gco:CharacterString/child::text()"/>
          </Dataset_Creator>
        </xsl:if>
        <xsl:if test="/gmd:MD_Metadata/gmd:distributionInfo/gmd:MD_Distribution/gmd:transferOptions/gmd:MD_DigitalTransferOptions/gmd:onLine/gmd:CI_OnlineResource/gmd:linkage/gmd:URL">
          <Online_Resource>
            <xsl:copy-of select="/gmd:MD_Metadata/gmd:distributionInfo/gmd:MD_Distribution/gmd:transferOptions/gmd:MD_DigitalTransferOptions/gmd:onLine/gmd:CI_OnlineResource/gmd:linkage/gmd:URL/child::text()"/>
          </Online_Resource>
        </xsl:if>
      </Data_Set_Citation>
      <Personnel>
        <xsl:for-each select="/gmd:MD_Metadata/gmd:contact/gmd:CI_ResponsibleParty/gmd:role">
          <Role>
            <xsl:choose>
              <xsl:when test="gmd:CI_RoleCode/@CodeListValue = 'principalInvestigator'">
                <xsl:text>Investigator</xsl:text>
              </xsl:when>
              <xsl:when test="gmd:CI_RoleCode/@CodeListValue = 'author'">
                <xsl:text>DIF Author</xsl:text>
              </xsl:when>
              <xsl:otherwise>
                <xsl:text>Technical Contact</xsl:text>
              </xsl:otherwise>
            </xsl:choose>
          </Role>
        </xsl:for-each>
        <xsl:if test="/gmd:MD_Metadata/gmd:contact/gmd:CI_ResponsibleParty/gmd:individualName">
          <xsl:variable name="name-parts">
            <xsl:copy-of select="str:split(/gmd:MD_Metadata/gmd:contact/gmd:CI_ResponsibleParty/gmd:individualName/gco:CharacterString/child::text())"/>
          </xsl:variable>
          <xsl:variable name="number-name-parts">
            <xsl:value-of select="count(com:node-set($name-parts)/token)"/>
          </xsl:variable>
          <xsl:choose>
            <xsl:when test="$number-name-parts=1">
              <Last_Name>
                <xsl:value-of select="com:node-set($name-parts)/token[1]"/>
              </Last_Name>
            </xsl:when>
            <xsl:when test="$number-name-parts=2">
              <First_Name>
                <xsl:value-of select="com:node-set($name-parts)/token[1]"/>
              </First_Name>
              <Last_Name>
                <xsl:value-of select="com:node-set($name-parts)/token[2]"/>
              </Last_Name>
            </xsl:when>
            <xsl:otherwise>
              <First_Name>
                <xsl:value-of select="com:node-set($name-parts)/token[1]"/>
              </First_Name>
              <Middle_Name>
                <xsl:value-of select="com:node-set($name-parts)/token[2]"/>
              </Middle_Name>
              <Last_Name>
                <xsl:value-of select="com:node-set($name-parts)/token[position()=last()]"/>
              </Last_Name>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:if>
        <Contact_Address>
          <xsl:if test="/gmd:MD_Metadata/gmd:contact/gmd:CI_ResponsibleParty/gmd:contactInfo/gmd:CI_Contact/gmd:address/gmd:CI_Address/gmd:deliveryPoint/gco:CharacterString">
            <Address>
              <xsl:copy-of select="/gmd:MD_Metadata/gmd:contact/gmd:CI_ResponsibleParty/gmd:contactInfo/gmd:CI_Contact/gmd:address/gmd:CI_Address/gmd:deliveryPoint/gco:CharacterString/child::text()"/>
            </Address>
          </xsl:if>
          <xsl:if test="/gmd:MD_Metadata/gmd:contact/gmd:CI_ResponsibleParty/gmd:contactInfo/gmd:CI_Contact/gmd:address/gmd:CI_Address/gmd:city/gco:CharacterString">
            <City>
              <xsl:copy-of select="/gmd:MD_Metadata/gmd:contact/gmd:CI_ResponsibleParty/gmd:contactInfo/gmd:CI_Contact/gmd:address/gmd:CI_Address/gmd:city/gco:CharacterString/child::text()"/>
            </City>
          </xsl:if>
          <xsl:if test="/gmd:MD_Metadata/gmd:contact/gmd:CI_ResponsibleParty/gmd:contactInfo/gmd:CI_Contact/gmd:address/gmd:CI_Address/gmd:administrativeArea/gco:CharacterString">
            <Province_or_State>
              <xsl:copy-of select="/gmd:MD_Metadata/gmd:contact/gmd:CI_ResponsibleParty/gmd:contactInfo/gmd:CI_Contact/gmd:address/gmd:CI_Address/gmd:administrativeArea/gco:CharacterString/child::text()"/>
            </Province_or_State>
          </xsl:if>
          <xsl:if test="/gmd:MD_Metadata/gmd:contact/gmd:CI_ResponsibleParty/gmd:contactInfo/gmd:CI_Contact/gmd:address/gmd:CI_Address/gmd:postalCode/gco:CharacterString">
            <Postal_Code>
              <xsl:copy-of select="/gmd:MD_Metadata/gmd:contact/gmd:CI_ResponsibleParty/gmd:contactInfo/gmd:CI_Contact/gmd:address/gmd:CI_Address/gmd:postalCode/gco:CharacterString/child::text()"/>
            </Postal_Code>
          </xsl:if>
          <xsl:if test="/gmd:MD_Metadata/gmd:contact/gmd:CI_ResponsibleParty/gmd:contactInfo/gmd:CI_Contact/gmd:address/gmd:CI_Address/gmd:country/gco:CharacterString">
            <Country>
              <xsl:copy-of select="/gmd:MD_Metadata/gmd:contact/gmd:CI_ResponsibleParty/gmd:contactInfo/gmd:CI_Contact/gmd:address/gmd:CI_Address/gmd:country/gco:CharacterString/child::text()"/>
            </Country>
          </xsl:if>
        </Contact_Address>
      </Personnel>
      <xsl:for-each select="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:descriptiveKeywords">
        <xsl:variable name="name-parts">
          <xsl:copy-of select="str:split(/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:descriptiveKeywords/gmd:MD_Keywords/gmd:keyword/gco:CharacterString/child::text(), ' &gt; ')"/>
        </xsl:variable>
        <Parameters>
          <Category>
            <xsl:value-of select="com:node-set($name-parts)/token[1]"/>
          </Category>
          <Topic>
            <xsl:value-of select="com:node-set($name-parts)/token[2]"/>
          </Topic>
          <Term>
            <xsl:value-of select="com:node-set($name-parts)/token[3]"/>
          </Term>
          <xsl:if test="com:node-set($name-parts)/token[4]">
            <Variable_Level_1>
              <xsl:value-of select="com:node-set($name-parts)/token[4]"/>
            </Variable_Level_1>
            <xsl:if test="com:node-set($name-parts)/token[5]">
              <Variable_Level_2>
                <xsl:value-of select="com:node-set($name-parts)/token[5]"/>
              </Variable_Level_2>
              <xsl:if test="com:node-set($name-parts)/token[6]">
                <Variable_Level_3>
                  <xsl:value-of select="com:node-set($name-parts)/token[6]"/>
                </Variable_Level_3>
                <xsl:if test="com:node-set($name-parts)/token[7]">
                  <Detailed_Variable>
                    <xsl:value-of select="com:node-set($name-parts)/token[7]"/>
                  </Detailed_Variable>
                </xsl:if>
              </xsl:if>
            </xsl:if>
          </xsl:if>
        </Parameters>
      </xsl:for-each>
      <xsl:for-each select="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:topicCategory">
        <ISO_Topic_Category>
          <!-- TODO: Convert to proper DIF category codes. -->
          <xsl:choose>
            <xsl:when test="gmd:MD_TopicCategoryCode/child::text() = 'farming'">
              <xsl:text>Farming</xsl:text>
            </xsl:when>
            <xsl:when test="gmd:MD_TopicCategoryCode/child::text() = 'biota'">
              <xsl:text>Biota</xsl:text>
            </xsl:when>
            <xsl:when test="gmd:MD_TopicCategoryCode/child::text() = 'boundaries'">
              <xsl:text>Boundaries</xsl:text>
            </xsl:when>
            <xsl:when test="gmd:MD_TopicCategoryCode/child::text() = 'climatologyMeteorologyAtmosphere'">
              <xsl:text>Climatology/Meteorology/Atmosphere</xsl:text>
            </xsl:when>
            <xsl:when test="gmd:MD_TopicCategoryCode/child::text() = 'economy'">
              <xsl:text>Economy</xsl:text>
            </xsl:when>
            <xsl:when test="gmd:MD_TopicCategoryCode/child::text() = 'elevation'">
              <xsl:text>Elevation</xsl:text>
            </xsl:when>
            <xsl:when test="gmd:MD_TopicCategoryCode/child::text() = 'environment'">
              <xsl:text>Environment</xsl:text>
            </xsl:when>
            <xsl:when test="gmd:MD_TopicCategoryCode/child::text() = 'geoscientificInformation'">
              <xsl:text>Geoscientific Information</xsl:text>
            </xsl:when>
            <xsl:when test="gmd:MD_TopicCategoryCode/child::text() = 'health'">
              <xsl:text>Health</xsl:text>
            </xsl:when>
            <xsl:when test="gmd:MD_TopicCategoryCode/child::text() = 'imageryBaseMapsEarthCover'">
              <xsl:text>Imagery/Base Maps/Earth Cover</xsl:text>
            </xsl:when>
            <xsl:when test="gmd:MD_TopicCategoryCode/child::text() = 'intelligenceMilitary'">
              <xsl:text>Intelligence/Military</xsl:text>
            </xsl:when>
            <xsl:when test="gmd:MD_TopicCategoryCode/child::text() = 'inlandWaters'">
              <xsl:text>Inland Waters</xsl:text>
            </xsl:when>
            <xsl:when test="gmd:MD_TopicCategoryCode/child::text() = 'location'">
              <xsl:text>Location</xsl:text>
            </xsl:when>
            <xsl:when test="gmd:MD_TopicCategoryCode/child::text() = 'oceans'">
              <xsl:text>Oceans</xsl:text>
            </xsl:when>
            <xsl:when test="gmd:MD_TopicCategoryCode/child::text() = 'planningCadastre'">
              <xsl:text>Planning Cadastre</xsl:text>
            </xsl:when>
            <xsl:when test="gmd:MD_TopicCategoryCode/child::text() = 'society'">
              <xsl:text>Society</xsl:text>
            </xsl:when>
            <xsl:when test="gmd:MD_TopicCategoryCode/child::text() = 'structure'">
              <xsl:text>Structure</xsl:text>
            </xsl:when>
            <xsl:when test="gmd:MD_TopicCategoryCode/child::text() = 'transportation'">
              <xsl:text>Transportation</xsl:text>
            </xsl:when>
            <xsl:when test="gmd:MD_TopicCategoryCode/child::text() = 'utilitiesCommunication'">
              <xsl:text>Utilities/Communications</xsl:text>
            </xsl:when>
          </xsl:choose>
        </ISO_Topic_Category>
      </xsl:for-each>
      <xsl:if test="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:status/gmd:MD_ProgressCode">
        <Data_Set_Progress>
          <xsl:choose>
            <xsl:when test="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:status/gmd:MD_ProgressCode/@codeListValue = 'completed'">
              <xsl:text>Complete</xsl:text>
            </xsl:when>
            <xsl:when test="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:status/gmd:MD_ProgressCode/@codeListValue = 'historicalArchive'">
              <xsl:text>Complete</xsl:text>
            </xsl:when>
            <xsl:when test="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:status/gmd:MD_ProgressCode/@codeListValue = 'obsolete'">
              <xsl:text>Complete</xsl:text>
            </xsl:when>
            <xsl:when test="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:status/gmd:MD_ProgressCode/@codeListValue = 'onGoing'">
              <xsl:text>In Work</xsl:text>
            </xsl:when>
            <xsl:when test="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:status/gmd:MD_ProgressCode/@codeListValue = 'planned'">
              <xsl:text>Planned</xsl:text>
            </xsl:when>
            <xsl:when test="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:status/gmd:MD_ProgressCode/@codeListValue = 'required'">
              <xsl:text>In Work</xsl:text>
            </xsl:when>
            <xsl:when test="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:status/gmd:MD_ProgressCode/@codeListValue = 'underDevelopment'">
              <xsl:text>In Work</xsl:text>
            </xsl:when>
          </xsl:choose>
        </Data_Set_Progress>
      </xsl:if>
      <Spatial_Coverage>
        <xsl:if test="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:extent/gmd:EX_Extent/gmd:geographicElement/gmd:EX_GeographicBoundingBox/gmd:southBoundLatitude/gco:Decimal">
          <Southernmost_Latitude>
            <xsl:copy-of select="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:extent/gmd:EX_Extent/gmd:geographicElement/gmd:EX_GeographicBoundingBox/gmd:southBoundLatitude/gco:Decimal/child::text()"/>
          </Southernmost_Latitude>
        </xsl:if>
        <xsl:if test="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:extent/gmd:EX_Extent/gmd:geographicElement/gmd:EX_GeographicBoundingBox/gmd:northBoundLatitude/gco:Decimal">
          <Northernmost_Latitude>
            <xsl:copy-of select="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:extent/gmd:EX_Extent/gmd:geographicElement/gmd:EX_GeographicBoundingBox/gmd:northBoundLatitude/gco:Decimal/child::text()"/>
          </Northernmost_Latitude>
        </xsl:if>
        <xsl:if test="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:extent/gmd:EX_Extent/gmd:geographicElement/gmd:EX_GeographicBoundingBox/gmd:westBoundLongitude/gco:Decimal">
          <Westernmost_Longitude>
            <xsl:copy-of select="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:extent/gmd:EX_Extent/gmd:geographicElement/gmd:EX_GeographicBoundingBox/gmd:westBoundLongitude/gco:Decimal/child::text()"/>
          </Westernmost_Longitude>
        </xsl:if>
        <xsl:if test="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:extent/gmd:EX_Extent/gmd:geographicElement/gmd:EX_GeographicBoundingBox/gmd:eastBoundLongitude/gco:Decimal">
          <Easternmost_Longitude>
            <xsl:copy-of select="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:extent/gmd:EX_Extent/gmd:geographicElement/gmd:EX_GeographicBoundingBox/gmd:eastBoundLongitude/gco:Decimal/child::text()"/>
          </Easternmost_Longitude>
        </xsl:if>
      </Spatial_Coverage>
      <Data_Center>
        <Data_Center_Name>
          <Short_Name><xsl:copy-of select="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:pointOfContact/gmd:CI_ResponsibleParty/gmd:organisationName/gco:CharacterString/child::text()"/></Short_Name>
        </Data_Center_Name>
        <xsl:if test="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:pointOfContact/gmd:CI_ResponsibleParty/gmd:contactInfo/gmd:CI_Contact/gmd:onlineResource/gmd:CI_OnlineResource/gmd:linkage/gmd:URL">
          <Data_Center_URL>
            <xsl:copy-of select="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:pointOfContact/gmd:CI_ResponsibleParty/gmd:contactInfo/gmd:CI_Contact/gmd:onlineResource/gmd:CI_OnlineResource/gmd:linkage/gmd:URL/child::text()"/>
          </Data_Center_URL>
        </xsl:if>
        <Personnel>
          <xsl:for-each select="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:pointOfContact/gmd:CI_ResponsibleParty/gmd:role">
            <Role>
              <xsl:choose>
                <xsl:when test="gmd:CI_RoleCode/@CodeListValue = 'principalInvestigator'">
                  <xsl:text>Investigator</xsl:text>
                </xsl:when>
                <xsl:when test="gmd:CI_RoleCode/@CodeListValue = 'author'">
                  <xsl:text>DIF Author</xsl:text>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:text>Technical Contact</xsl:text>
                </xsl:otherwise>
              </xsl:choose>
            </Role>
          </xsl:for-each>
          <xsl:if test="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:pointOfContact/gmd:CI_ResponsibleParty/gmd:individualName">
            <xsl:variable name="name-parts">
              <xsl:copy-of select="str:split(/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:pointOfContact/gmd:CI_ResponsibleParty/gmd:individualName/gco:CharacterString/child::text())"/>
            </xsl:variable>
            <xsl:variable name="number-name-parts">
              <xsl:value-of select="count(com:node-set($name-parts)/token)"/>
            </xsl:variable>
            <xsl:choose>
              <xsl:when test="$number-name-parts=1">
                <Last_Name>
                  <xsl:value-of select="com:node-set($name-parts)/token[1]"/>
                </Last_Name>
              </xsl:when>
              <xsl:when test="$number-name-parts=2">
                <First_Name>
                  <xsl:value-of select="com:node-set($name-parts)/token[1]"/>
                </First_Name>
                <Last_Name>
                  <xsl:value-of select="com:node-set($name-parts)/token[2]"/>
                </Last_Name>
              </xsl:when>
              <xsl:otherwise>
                <First_Name>
                  <xsl:value-of select="com:node-set($name-parts)/token[1]"/>
                </First_Name>
                <Middle_Name>
                  <xsl:value-of select="com:node-set($name-parts)/token[2]"/>
                </Middle_Name>
                <Last_Name>
                  <xsl:value-of select="com:node-set($name-parts)/token[position()=last()]"/>
                </Last_Name>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:if>
          <Contact_Address>
            <xsl:if test="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:pointOfContact/gmd:CI_ResponsibleParty/gmd:contactInfo/gmd:CI_Contact/gmd:address/gmd:CI_Address/gmd:deliveryPoint/gco:CharacterString">
              <Address>
                <xsl:copy-of select="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:pointOfContact/gmd:CI_ResponsibleParty/gmd:contactInfo/gmd:CI_Contact/gmd:address/gmd:CI_Address/gmd:deliveryPoint/gco:CharacterString/child::text()"/>
              </Address>
            </xsl:if>
            <xsl:if test="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:pointOfContact/gmd:CI_ResponsibleParty/gmd:contactInfo/gmd:CI_Contact/gmd:address/gmd:CI_Address/gmd:city/gco:CharacterString">
              <City>
                <xsl:copy-of select="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:pointOfContact/gmd:CI_ResponsibleParty/gmd:contactInfo/gmd:CI_Contact/gmd:address/gmd:CI_Address/gmd:city/gco:CharacterString/child::text()"/>
              </City>
            </xsl:if>
            <xsl:if test="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:pointOfContact/gmd:CI_ResponsibleParty/gmd:contactInfo/gmd:CI_Contact/gmd:address/gmd:CI_Address/gmd:administrativeArea/gco:CharacterString">
              <Province_or_State>
                <xsl:copy-of select="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:pointOfContact/gmd:CI_ResponsibleParty/gmd:contactInfo/gmd:CI_Contact/gmd:address/gmd:CI_Address/gmd:administrativeArea/gco:CharacterString/child::text()"/>
              </Province_or_State>
            </xsl:if>
            <xsl:if test="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:pointOfContact/gmd:CI_ResponsibleParty/gmd:contactInfo/gmd:CI_Contact/gmd:address/gmd:CI_Address/gmd:postalCode/gco:CharacterString">
              <Postal_Code>
                <xsl:copy-of select="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:pointOfContact/gmd:CI_ResponsibleParty/gmd:contactInfo/gmd:CI_Contact/gmd:address/gmd:CI_Address/gmd:postalCode/gco:CharacterString/child::text()"/>
              </Postal_Code>
            </xsl:if>
            <xsl:if test="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:pointOfContact/gmd:CI_ResponsibleParty/gmd:contactInfo/gmd:CI_Contact/gmd:address/gmd:CI_Address/gmd:country/gco:CharacterString">
              <Country>
                <xsl:copy-of select="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:pointOfContact/gmd:CI_ResponsibleParty/gmd:contactInfo/gmd:CI_Contact/gmd:address/gmd:CI_Address/gmd:country/gco:CharacterString/child::text()"/>
              </Country>
            </xsl:if>
          </Contact_Address>
        </Personnel>
      </Data_Center>
      <Summary>
        <xsl:copy-of select="/gmd:MD_Metadata/gmd:identificationInfo/gmd:MD_DataIdentification/gmd:abstract/gco:CharacterString/child::text()"/>
      </Summary>
      <Metadata_Name>CEOS IDN DIF</Metadata_Name>
      <Metadata_Version>9.7</Metadata_Version>
    </DIF>
  </xsl:template>
</xsl:stylesheet>
