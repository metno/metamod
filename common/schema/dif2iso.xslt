<?xml version="1.0" encoding="UTF-8"?>

<xsl:stylesheet version="1.0"
                xmlns:dif="http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:gco="http://www.isotc211.org/2005/gco"
                xmlns:gmd="http://www.isotc211.org/2005/gmd">

  <xsl:output method="xml" indent="yes"/>
  <xsl:param name="REPOSITORY_IDENTIFIER"/>

  <xsl:variable name="uc" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ'"/>
  <xsl:variable name="lc" select="'abcdefghijklmnopqrstuvwxyz'"/>

  <xsl:template match="dif:DIF">
    <gmd:MD_Metadata xsi:schemaLocation="http://www.isotc211.org/2005/gmd http://www.isotc211.org/2005/gmd/gmd.xsd"
                     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                     xmlns:gmd="http://www.isotc211.org/2005/gmd">

      <!-- fileIdentifier ? -->
      <gmd:fileIdentifier>
        <gco:CharacterString>
          <xsl:if test="$REPOSITORY_IDENTIFIER">urn:<xsl:value-of select="$REPOSITORY_IDENTIFIER"/>:</xsl:if><xsl:copy-of select="dif:Entry_ID/child::node()"/>
        </gco:CharacterString>
      </gmd:fileIdentifier>

      <!-- language ? -->
      <gmd:language>
        <gco:CharacterString>en</gco:CharacterString>
      </gmd:language>

      <!-- contact 1 -->
      <gmd:contact>
        <gmd:CI_ResponsibleParty>
          <gmd:individualName>
            <gco:CharacterString>
              <!-- dif:First_Name ? -->
              <xsl:if test="/dif:DIF/dif:Personnel/dif:First_Name">
                <xsl:copy-of select="/dif:DIF/dif:Personnel/dif:First_Name/child::text()"/>
                <xsl:text> </xsl:text>
              </xsl:if>
              <!-- dif:Middle_Name ? -->
              <xsl:if test="/dif:DIF/dif:Personnel/dif:Middle_Name">
                <xsl:copy-of select="/dif:DIF/dif:Personnel/dif:Middle_Name/child::text()"/>
                <xsl:text> </xsl:text>
              </xsl:if>
              <!-- dif:Last_Name 1 -->
              <xsl:copy-of select="/dif:DIF/dif:Personnel/dif:Last_Name/child::text()"/>
            </gco:CharacterString>
          </gmd:individualName>
          <gmd:contactInfo>
            <gmd:CI_Contact>
              <gmd:phone>
                <gmd:CI_Telephone>
                  <!-- dif:Phone * -->
                  <xsl:for-each select="/dif:DIF/dif:Personnel/dif:Phone/child::text()">
                    <gmd:voice>
                      <gco:CharacterString>
                        <xsl:copy-of select="."/>
                      </gco:CharacterString>
                    </gmd:voice>
                  </xsl:for-each>
                  <!-- dif:FAX * -->
                  <xsl:for-each select="/dif:DIF/dif:Personnel/dif:FAX/child::text()">
                    <gmd:facsimile>
                      <gco:CharacterString>
                        <xsl:copy-of select="."/>
                      </gco:CharacterString>
                    </gmd:facsimile>
                  </xsl:for-each>
                </gmd:CI_Telephone>
              </gmd:phone>
              <gmd:address>
                <gmd:CI_Address>
                  <!-- dif:Address * -->
                  <xsl:for-each select="/dif:DIF/dif:Personnel/dif:Contact_Address/dif:Address/child::text()">
                    <gmd:deliveryPoint>
                      <gco:CharacterString>
                        <xsl:copy-of select="."/>
                      </gco:CharacterString>
                    </gmd:deliveryPoint>
                  </xsl:for-each>
                  <!-- dif:City ? -->
                  <xsl:if test="/dif:DIF/dif:Personnel/dif:Contact_Address/dif:City">
                    <gmd:city>
                      <gco:CharacterString>
                        <xsl:copy-of select="/dif:DIF/dif:Personnel/dif:Contact_Address/dif:City/child::text()"/>
                      </gco:CharacterString>
                    </gmd:city>
                  </xsl:if>
                  <!-- dif:Province_or_State ? -->
                  <xsl:if test="/dif:DIF/dif:Personnel/dif:Contact_Address/dif:Province_or_State">
                    <gmd:administrativeArea>
                      <gco:CharacterString>
                        <xsl:copy-of select="/dif:DIF/dif:Personnel/dif:Contact_Address/dif:Province_or_State/child::text()"/>
                      </gco:CharacterString>
                    </gmd:administrativeArea>
                  </xsl:if>
                  <!-- dif:Postal_Code ? -->
                  <xsl:if test="/dif:DIF/dif:Personnel/dif:Contact_Address/dif:Postal_Code">
                    <gmd:postalCode>
                      <gco:CharacterString>
                        <xsl:copy-of select="/dif:DIF/dif:Personnel/dif:Contact_Address/dif:Postal_Code/child::text()"/>
                      </gco:CharacterString>
                    </gmd:postalCode>
                  </xsl:if>
                  <!-- dif:Country ? -->
                  <xsl:if test="/dif:DIF/dif:Personnel/dif:Contact_Address/dif:Country">
                    <gmd:country>
                      <gco:CharacterString>
                        <xsl:copy-of select="/dif:DIF/dif:Personnel/dif:Contact_Address/dif:Country/child::text()"/>
                      </gco:CharacterString>
                    </gmd:country>
                  </xsl:if>
                  <!-- dif:Email * -->
                  <xsl:for-each select="/dif:DIF/dif:Personnel/dif:Email/child::text()">
                    <gmd:electronicMailAddress>
                      <gco:CharacterString>
                        <xsl:copy-of select="."/>
                      </gco:CharacterString>
                    </gmd:electronicMailAddress>
                  </xsl:for-each>
                </gmd:CI_Address>
              </gmd:address>
            </gmd:CI_Contact>
          </gmd:contactInfo>
          <!-- DIF may specify multiple roles, but ISO may specify only one. -->
          <!-- dif:Role + -->
          <gmd:role>
            <gmd:CI_RoleCode codeList="./resources/codeList.xml#CI_RoleCode">
              <xsl:attribute name="codeListValue">
                <xsl:choose>
                  <xsl:when test="translate(/dif:DIF/dif:Personnel/dif:Role/child::text(), $uc, $lc) = 'investigator'">
                    <xsl:text>principalInvestigator</xsl:text>
                  </xsl:when>
                  <xsl:when test="translate(/dif:DIF/dif:Personnel/dif:Role/child::text(), $uc, $lc) = 'technical contact'">
                    <xsl:text>pointOfContact</xsl:text>
                  </xsl:when>
                  <xsl:when test="translate(/dif:DIF/dif:Personnel/dif:Role/child::text(), $uc, $lc) = 'dif author'">
                    <xsl:text>author</xsl:text>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:text>pointOfContact</xsl:text>
                  </xsl:otherwise>
                </xsl:choose>
              </xsl:attribute>
            </gmd:CI_RoleCode>
          </gmd:role>
        </gmd:CI_ResponsibleParty>
      </gmd:contact>

      <!-- dateStamp 1 -->
      <gmd:dateStamp>
        <gco:Date>
          <xsl:copy-of select="dif:DIF_Creation_Date/child::text()"/>
        </gco:Date>
      </gmd:dateStamp>

      <!-- metadataStandardname -->
      <gmd:metadataStandardName>
        <gco:CharacterString xmlns:srv="http://www.isotc211.org/2005/srv">ISO 19115:2003/19139</gco:CharacterString>
      </gmd:metadataStandardName>

      <!-- metadataStandardVersion -->
      <gmd:metadataStandardVersion>
        <gco:CharacterString>1.0</gco:CharacterString>
      </gmd:metadataStandardVersion>

      <xsl:if test="/dif:DIF/dif:Data_Set_Citation/dif:Online_Resource">
        <gmd:dataSetURI>
          <gco:CharacterString>
            <xsl:copy-of select="/dif:DIF/dif:Data_Set_Citation/dif:Online_Resource/child::text()"/>
          </gco:CharacterString>
        </gmd:dataSetURI>
      </xsl:if>

      <!-- identificationInfo 1 -->
      <gmd:identificationInfo>
        <gmd:MD_DataIdentification>
          <gmd:citation>
            <gmd:CI_Citation>
              <gmd:title>
                <gco:CharacterString>
                  <xsl:copy-of select="/dif:DIF/dif:Data_Set_Citation/dif:Dataset_Title/child::text()"/>
                </gco:CharacterString>
              </gmd:title>
              <gmd:date>
                <gmd:CI_Date>
                  <gmd:date>
                    <gco:Date>
                      <xsl:copy-of select="/dif:DIF/dif:DIF_Creation_Date/child::text()"/>
                    </gco:Date>
                  </gmd:date>
                  <gmd:dateType>
                    <gmd:CI_DateTypeCode codeList="http://wis.wmo.int/2006/catalogues/gmxCodelists.xml#CI_DateTypeCode"
                                         codeListValue="creation">
                    </gmd:CI_DateTypeCode>
                  </gmd:dateType>
                </gmd:CI_Date>
              </gmd:date>
              <xsl:if test="/dif:DIF/dif:Related_URL/dif:URL_Content_Type/dif:Type = 'GTSInstancePattern'">
              <gmd:identifier>
                <gmd:RS_Identifier id="InstancePattern">
                  <gmd:code>
                    <gco:CharacterString><xsl:copy-of select="/dif:DIF/dif:Related_URL/dif:URL/child::text()"/></gco:CharacterString>
                  </gmd:code>
                  <gmd:codeSpace>
                    <gco:CharacterString>Instance Pattern of WIS GISC Cache</gco:CharacterString>
                  </gmd:codeSpace>
                </gmd:RS_Identifier>
              </gmd:identifier>
              </xsl:if>
            </gmd:CI_Citation>
          </gmd:citation>
          <gmd:abstract>
            <gco:CharacterString>
              <xsl:copy-of select="/dif:DIF/dif:Summary/child::text()"/>
            </gco:CharacterString>
          </gmd:abstract>

          <xsl:if test="/dif:DIF/dif:Data_Set_Progress">
            <gmd:status>
              <gmd:MD_ProgressCode codeList="./resources/codeList.xml#MD_ProgressCode">
                <xsl:attribute name="codeListValue">
                  <xsl:choose>
                    <xsl:when test="translate(/dif:DIF/dif:Data_Set_Progress/child::text(), $uc, $lc) = 'planned'">
                      <xsl:text>planned</xsl:text>
                    </xsl:when>
                    <xsl:when test="translate(/dif:DIF/dif:Data_Set_Progress/child::text(), $uc, $lc) = 'in work'">
                      <xsl:text>onGoing</xsl:text>
                    </xsl:when>
                    <xsl:when test="translate(/dif:DIF/dif:Data_Set_Progress/child::text(), $uc, $lc) = 'complete'">
                      <xsl:text>completed</xsl:text>
                    </xsl:when>
                  </xsl:choose>
                </xsl:attribute>
              </gmd:MD_ProgressCode>
            </gmd:status>
          </xsl:if>

          <gmd:pointOfContact>
            <gmd:CI_ResponsibleParty>
              <gmd:individualName>
                <gco:CharacterString>
                  <xsl:copy-of select="/dif:DIF/dif:Data_Set_Citation/dif:Dataset_Creator/child::text()"/>
                </gco:CharacterString>
              </gmd:individualName>
              <gmd:role>
                <gmd:CI_RoleCode codeList="./resources/codeList.xml#CI_RoleCode"
                                 codeListValue="principalInvestigator"/>
              </gmd:role>
            </gmd:CI_ResponsibleParty>
          </gmd:pointOfContact>

          <gmd:pointOfContact>
            <gmd:CI_ResponsibleParty>
              <gmd:individualName>
                <gco:CharacterString>
                  <xsl:copy-of select="/dif:DIF/dif:Data_Set_Citation/dif:Dataset_Publisher/child::text()"/>
                </gco:CharacterString>
              </gmd:individualName>
              <gmd:role>
                <gmd:CI_RoleCode codeList="./resources/codeList.xml#CI_RoleCode"
                                 codeListValue="publisher"/>
              </gmd:role>
            </gmd:CI_ResponsibleParty>
          </gmd:pointOfContact>

          <gmd:pointOfContact>
            <gmd:CI_ResponsibleParty>
              <gmd:organisationName>
                <gco:CharacterString>
                  <xsl:copy-of select="/dif:DIF/dif:Data_Center/dif:Data_Center_Name/dif:Long_Name/child::text()"/>
                </gco:CharacterString>
              </gmd:organisationName>
              <gmd:contactInfo>
                <gmd:CI_Contact>
                  <gmd:address>
                    <gmd:CI_Address>
                      <!-- dif:Address * -->
                      <xsl:for-each select="/dif:DIF/dif:Data_Center/dif:Personnel/dif:Contact_Address/dif:Address/child::text()">
                        <gmd:deliveryPoint>
                          <gco:CharacterString>
                            <xsl:copy-of select="/dif:DIF/dif:Data_Center/dif:Personnel/dif:Contact_Address/dif:Address/child::text()"/>
                          </gco:CharacterString>
                        </gmd:deliveryPoint>
                      </xsl:for-each>
                      <!-- dif:City ? -->
                      <xsl:if test="/dif:DIF/dif:Data_Center/dif:Personnel/dif:Contact_Address/dif:City">
                        <gmd:city>
                          <gco:CharacterString>
                            <xsl:copy-of select="/dif:DIF/dif:Data_Center/dif:Personnel/dif:Contact_Address/dif:City/child::text()"/>
                          </gco:CharacterString>
                        </gmd:city>
                      </xsl:if>
                      <!-- dif:Province_or_State ? -->
                      <xsl:if test="/dif:DIF/dif:Data_Center/dif:Personnel/dif:Contact_Address/dif:Province_or_State">
                        <gmd:administrativeArea>
                          <gco:CharacterString>
                            <xsl:copy-of select="/dif:DIF/dif:Data_Center/dif:Personnel/dif:Contact_Address/dif:Province_or_State/child::text()"/>
                          </gco:CharacterString>
                        </gmd:administrativeArea>
                      </xsl:if>
                      <!-- dif:Postal_Code ? -->
                      <xsl:if test="/dif:DIF/dif:Data_Center/dif:Personnel/dif:Contact_Address/dif:Postal_Code">
                        <gmd:postalCode>
                          <gco:CharacterString>
                            <xsl:copy-of select="/dif:DIF/dif:Data_Center/dif:Personnel/dif:Contact_Address/dif:Postal_Code/child::text()"/>
                          </gco:CharacterString>
                        </gmd:postalCode>
                      </xsl:if>
                      <!-- dif:Country ? -->
                      <xsl:if test="/dif:DIF/dif:Data_Center/dif:Personnel/dif:Contact_Address/dif:Country">
                        <gmd:country>
                          <gco:CharacterString>
                            <xsl:copy-of select="/dif:DIF/dif:Data_Center/dif:Personnel/dif:Contact_Address/dif:Country/child::text()"/>
                          </gco:CharacterString>
                        </gmd:country>
                      </xsl:if>
                    </gmd:CI_Address>
                  </gmd:address>
                </gmd:CI_Contact>
              </gmd:contactInfo>
              <gmd:role>
                <gmd:CI_RoleCode codeList="./resources/codeList.xml#CI_RoleCode"
                                 codeListValue="distributor"/>
              </gmd:role>
            </gmd:CI_ResponsibleParty>
          </gmd:pointOfContact>

          <gmd:descriptiveKeywords>
            <gmd:MD_Keywords>
              <xsl:for-each select="/dif:DIF/dif:Parameters">
                <gmd:keyword>
                  <gco:CharacterString>
                    <xsl:copy-of select="./dif:Category/child::text()"/>
                    <xsl:text>|</xsl:text>
                    <xsl:copy-of select="./dif:Topic/child::text()"/>
                    <xsl:text>|</xsl:text>
                    <xsl:copy-of select="./dif:Term/child::text()"/>
                    <xsl:if test="./dif:Variable_Level_1">
                      <xsl:text>|</xsl:text>
                      <xsl:copy-of select="./dif:Variable_Level_1/child::text()"/>
                      <xsl:if test="./dif:Variable_Level_2">
                        <xsl:text>|</xsl:text>
                        <xsl:copy-of select="./dif:Variable_Level_2/child::text()"/>
                        <xsl:if test="./dif:Variable_Level_3">
                          <xsl:text>|</xsl:text>
                          <xsl:copy-of select="./dif:Variable_Level_3/child::text()"/>
                          <xsl:if test="./dif:Detailed_Variable">
                            <xsl:text>|</xsl:text>
                            <xsl:copy-of select="./dif:Detailed_Variable/child::text()"/>
                          </xsl:if>
                        </xsl:if>
                      </xsl:if>
                    </xsl:if>
                  </gco:CharacterString>
                </gmd:keyword>
              </xsl:for-each>
            </gmd:MD_Keywords>
          </gmd:descriptiveKeywords>

          <gmd:resourceConstraints>
            <gmd:MD_LegalConstraints>
              <xsl:if test="/dif:DIF/dif:Access_Constraints">
                <gmd:accessConstraints>
                  <gmd:MD_RestrictionCode
                      codeList="http://wis.wmo.int/2006/catalogues/gmxCodelists.xml#MD_RestrictionCode"
                      codeListValue="restricted">
                    <xsl:copy-of select="/dif:DIF/dif:Access_Constraints/child::text()"/>
                  </gmd:MD_RestrictionCode>
                </gmd:accessConstraints>
              </xsl:if>
              <xsl:if test="/dif:DIF/dif:Use_Constraints">
                <gmd:useConstraints>
                  <gmd:MD_RestrictionCode
                      codeList="http://wis.wmo.int/2006/catalogues/gmxCodelists.xml#MD_RestrictionCode"
                      codeListValue="restricted">
                    <xsl:copy-of select="/dif:DIF/dif:Use_Constraints/child::text()"/>
                  </gmd:MD_RestrictionCode>
                </gmd:useConstraints>
              </xsl:if>
            </gmd:MD_LegalConstraints>
          </gmd:resourceConstraints>
          <gmd:language>
            <gco:CharacterString>en</gco:CharacterString>
          </gmd:language>

          <xsl:for-each select="/dif:DIF/dif:ISO_Topic_Category">
            <gmd:topicCategory>
              <gmd:MD_TopicCategoryCode>
                <xsl:choose>
                  <xsl:when test="translate(./child::text(), $uc, $lc) = 'farming'">
                    <xsl:text>farming</xsl:text>
                  </xsl:when>
                  <xsl:when test="translate(./child::text(), $uc, $lc) = 'biota'">
                    <xsl:text>biota</xsl:text>
                  </xsl:when>
                  <xsl:when test="translate(./child::text(), $uc, $lc) = 'boundaries'">
                    <xsl:text>boundaries</xsl:text>
                  </xsl:when>
                  <xsl:when test="translate(./child::text(), $uc, $lc) = 'climatology/meteorology/atmosphere'">
                    <xsl:text>climatologyMeteorologyAtmosphere</xsl:text>
                  </xsl:when>
                  <xsl:when test="translate(./child::text(), $uc, $lc) = 'economy'">
                    <xsl:text>economy</xsl:text>
                  </xsl:when>
                  <xsl:when test="translate(./child::text(), $uc, $lc) = 'elevation'">
                    <xsl:text>elevation</xsl:text>
                  </xsl:when>
                  <xsl:when test="translate(./child::text(), $uc, $lc) = 'environment'">
                    <xsl:text>environment</xsl:text>
                  </xsl:when>
                  <xsl:when test="translate(./child::text(), $uc, $lc) = 'geoscientific information'">
                    <xsl:text>geoscientificInformation</xsl:text>
                  </xsl:when>
                  <xsl:when test="translate(./child::text(), $uc, $lc) = 'health'">
                    <xsl:text>health</xsl:text>
                  </xsl:when>
                  <xsl:when test="translate(./child::text(), $uc, $lc) = 'imagery/base maps/earth cover'">
                    <xsl:text>imageryBaseMapsEarthCover</xsl:text>
                  </xsl:when>
                  <xsl:when test="translate(./child::text(), $uc, $lc) = 'intelligence/military'">
                    <xsl:text>intelligenceMilitary</xsl:text>
                  </xsl:when>
                  <xsl:when test="translate(./child::text(), $uc, $lc) = 'inland waters'">
                    <xsl:text>inlandWaters</xsl:text>
                  </xsl:when>
                  <xsl:when test="translate(./child::text(), $uc, $lc) = 'location'">
                    <xsl:text>location</xsl:text>
                  </xsl:when>
                  <xsl:when test="translate(./child::text(), $uc, $lc) = 'oceans'">
                    <xsl:text>oceans</xsl:text>
                  </xsl:when>
                  <xsl:when test="translate(./child::text(), $uc, $lc) = 'planning cadastre'">
                    <xsl:text>planningCadastre</xsl:text>
                  </xsl:when>
                  <xsl:when test="translate(./child::text(), $uc, $lc) = 'society'">
                    <xsl:text>society</xsl:text>
                  </xsl:when>
                  <xsl:when test="translate(./child::text(), $uc, $lc) = 'structure'">
                    <xsl:text>structure</xsl:text>
                  </xsl:when>
                  <xsl:when test="translate(./child::text(), $uc, $lc) = 'transportation'">
                    <xsl:text>transportation</xsl:text>
                  </xsl:when>
                  <xsl:when test="translate(./child::text(), $uc, $lc) = 'utilities/communications'">
                    <xsl:text>utilitiesCommunication</xsl:text>
                  </xsl:when>
                </xsl:choose>
              </gmd:MD_TopicCategoryCode>
            </gmd:topicCategory>
          </xsl:for-each>

          <xsl:for-each select="/dif:DIF/dif:Spatial_Coverage">
            <gmd:extent>
              <gmd:EX_Extent>
                <gmd:geographicElement>
                  <gmd:EX_GeographicBoundingBox>
                    <gmd:westBoundLongitude>
                      <gco:Decimal>
                        <xsl:copy-of select="./dif:Westernmost_Longitude/child::text()"/>
                      </gco:Decimal>
                    </gmd:westBoundLongitude>
                    <gmd:eastBoundLongitude>
                      <gco:Decimal>
                        <xsl:copy-of select="./dif:Easternmost_Longitude/child::text()"/>
                      </gco:Decimal>
                    </gmd:eastBoundLongitude>
                    <gmd:southBoundLatitude>
                      <gco:Decimal>
                        <xsl:copy-of select="./dif:Southernmost_Latitude/child::text()"/>
                      </gco:Decimal>
                    </gmd:southBoundLatitude>
                    <gmd:northBoundLatitude>
                      <gco:Decimal>
                        <xsl:copy-of select="./dif:Northernmost_Latitude/child::text()"/>
                      </gco:Decimal>
                    </gmd:northBoundLatitude>
                  </gmd:EX_GeographicBoundingBox>
                </gmd:geographicElement>
              </gmd:EX_Extent>
            </gmd:extent>
          </xsl:for-each>
        </gmd:MD_DataIdentification>
      </gmd:identificationInfo>
      <xsl:if test="/dif:DIF/dif:Data_Set_Citation/dif:Online_Resource">
        <gmd:distributionInfo>
          <gmd:MD_Distribution>
            <gmd:transferOptions>
              <gmd:MD_DigitalTransferOptions>
                <gmd:onLine>
                  <gmd:CI_OnlineResource>
                    <gmd:linkage>
                      <gmd:URL>
                        <xsl:copy-of select="/dif:DIF/dif:Data_Set_Citation/dif:Online_Resource/child::text()"/>
                      </gmd:URL>
                    </gmd:linkage>
                  </gmd:CI_OnlineResource>
                </gmd:onLine>
              </gmd:MD_DigitalTransferOptions>
            </gmd:transferOptions>
          </gmd:MD_Distribution>
        </gmd:distributionInfo>
      </xsl:if>
    </gmd:MD_Metadata>
  </xsl:template>
</xsl:stylesheet>
