<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
                xmlns:mm="http://www.met.no/schema/metamod/MM2"
                xmlns:gcmd="http://vocab.ndg.nerc.ac.uk/list/P041/current"
                xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                xmlns:skos="http://www.w3.org/2004/02/skos/core#"
                xmlns:dc="http://purl.org/dc/elements/1.1/"
                xmlns:nc="http://vocab.ndg.nerc.ac.uk/list/P071/current"
                xmlns:nco="http://vocab.ndg.nerc.ac.uk/list/P072/current"
                xmlns:jif="http://www.met.no/schema/metamod/jif"
                xmlns:topic="http://www.met.no/schema/metamod/mm2dif"
                xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                xmlns="http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/"
                xsi:schemaLocation="http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/ http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/dif_v9.8.2.xsd"
                exclude-result-prefixes="mm gcmd nc nco rdf skos dc xsi">

  <xsl:param name="DS_name"/>
  <xsl:param name="DS_creationdate"/>
  <xsl:param name="DS_datestamp"/>

  <xsl:output encoding="UTF-8" indent="yes"/>
  <xsl:variable name="lc" select="'abcdefghijklmnopqrstuvwxyz'"/>
  <xsl:variable name="uc" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ'"/>
 
  <xsl:key name="mm2" match="/*/mm:metadata" use="@name"/>

  <xsl:template match="/">
    <DIF>

      <Entry_ID><xsl:value-of select="$DS_name"/></Entry_ID>
      <Entry_Title jif:default="Not Available"><xsl:value-of select="key('mm2', 'title')"/></Entry_Title>

      <Data_Set_Citation>
        <Dataset_Creator jif:default="Not Available"><xsl:value-of select="key('mm2', 'PI_name')"/></Dataset_Creator>
        <Dataset_Title jif:default="Not Available"><xsl:value-of select="key('mm2', 'title')"/></Dataset_Title>
        <Dataset_Release_Date>Not Available</Dataset_Release_Date>
        <Dataset_Release_Place>Not Available</Dataset_Release_Place>
        <Dataset_Publisher><xsl:value-of select="key('mm2', 'institution')"/></Dataset_Publisher>
        <Version>Not Available</Version>
      </Data_Set_Citation>

      <xsl:apply-templates select="key('mm2', 'gtsFileIdentifier')"/>
      <xsl:apply-templates select="key('mm2', 'gtsInstancePattern')"/>
      <xsl:call-template name="personell">
        <xsl:with-param name="role" select="'Technical Contact'"/>
      </xsl:call-template>
      
      <xsl:comment>start of variables</xsl:comment>
      <xsl:apply-templates select="key('mm2', 'variable')"/>
      <xsl:comment>end of variables</xsl:comment>

      <xsl:variable name="topiccategory" select="key('mm2', 'topiccategory')"/>
      <ISO_Topic_Category><xsl:value-of select="document('')/*/topic:category[@name = $topiccategory]"/></ISO_Topic_Category>

      <xsl:apply-templates select="key('mm2', 'keywords')"/>

      <Temporal_Coverage>
        <Start_Date><xsl:value-of select="key('mm2', 'datacollection_period_from')"/></Start_Date>
        <Stop_Date><xsl:value-of select="key('mm2', 'datacollection_period_to')"/></Stop_Date>
      </Temporal_Coverage>

      <Data_Set_Progress>In Work</Data_Set_Progress>
      <xsl:apply-templates select="key('mm2', 'bounding_box')"/>
      <xsl:apply-templates select="key('mm2', 'area')"/>

      <!-- Project -->
      <xsl:variable name="project" select="key('mm2', 'project_name')"/>
      <xsl:variable name="projs" select="document('')/*/topic:project[@shortname != 'IPY']/topic:project[@name = $project]"/>

      <xsl:choose>

        <xsl:when test="$projs">
          <xsl:for-each select="$projs">
            <Project>
              <Short_Name><xsl:value-of select="../@shortname"/></Short_Name>
              <Long_Name><xsl:value-of select="../@longname"/></Long_Name>
            </Project>
          </xsl:for-each>
        </xsl:when>

        <xsl:otherwise>
          <Project>
            <Short_Name jif:default="Not Available"><xsl:value-of select="$project"/></Short_Name>
            <Long_Name jif:default="Not Available"><xsl:value-of select="$project"/></Long_Name>
          </Project>
        </xsl:otherwise>

      </xsl:choose>

      <!-- also add IPY if required -->
      <xsl:for-each select="document('')/*/topic:project[@shortname = 'IPY']/topic:project[@name = $project]">
        <Project>
          <Short_Name><xsl:value-of select="../@shortname"/></Short_Name>
          <Long_Name><xsl:value-of select="../@longname"/></Long_Name>
        </Project>
      </xsl:for-each>

      <Access_Constraints jif:default="Not Available"><xsl:value-of select="key('mm2', 'distribution_statement')"/></Access_Constraints>
      <Use_Constraints>Not Available</Use_Constraints>
      <Data_Set_Language>Not Available</Data_Set_Language>

      <Data_Center>
        <Data_Center_Name>
          <Short_Name>NO/MET</Short_Name>
          <Long_Name>Norwegian Meteorological Institute, Norway</Long_Name>
        </Data_Center_Name>
        <Data_Center_URL>http://met.no/</Data_Center_URL>
        <xsl:call-template name="personell">
          <xsl:with-param name="role" select="'Data Center Contact'"/>
        </xsl:call-template>
       </Data_Center>

      <Reference><xsl:value-of select="key('mm2', 'references')"/></Reference>
      <Summary><Abstract jif:default="Not Available"><xsl:value-of select="key('mm2', 'abstract')"/></Abstract></Summary>
      <Related_URL>
        <URL_Content_Type>
          <Type>VIEW RELATED INFORMATION</Type>
        </URL_Content_Type>
        <URL><xsl:value-of select="key('mm2', 'dataref')"/></URL>
      </Related_URL>
      <xsl:apply-templates select="key('mm2', 'gtsFileIdentifier')"/>
      <xsl:apply-templates select="key('mm2', 'gtsInstancePattern')"/>

      <IDN_Node>
        <Short_Name>ARCTIC/NO</Short_Name>
      </IDN_Node>
      <IDN_Node>
        <Short_Name>ARCTIC</Short_Name>
      </IDN_Node>
      <IDN_Node>
        <Short_Name>IPY</Short_Name>
      </IDN_Node>
      <IDN_Node>
        <Short_Name>DOKIPY</Short_Name>
      </IDN_Node>

      <Metadata_Name>CEOS IDN DIF</Metadata_Name>
      <Metadata_Version>9.7</Metadata_Version>
      <!-- dif does not handle second resolution -->
      <DIF_Creation_Date><xsl:value-of select="substring($DS_creationdate,1,10)"/></DIF_Creation_Date>
      <Last_DIF_Revision_Date><xsl:value-of select="substring($DS_datestamp,1,10)"/></Last_DIF_Revision_Date>
      <Private>False</Private>
    </DIF>
  </xsl:template>

  <!-- gts-linkage -->
  <xsl:template match="*[@name='gtsInstancePattern']">
      <Related_URL>
        <URL_Content_Type>
          <Type>GTSInstancePattern</Type>
        </URL_Content_Type>
        <URL><xsl:value-of select="current()"/></URL>
        <Description>Instance pattern connecting to Global Telecommunication System (GTS)</Description>
      </Related_URL>
  </xsl:template>

  <xsl:template match="*[@name='gtsFileIdentifier']">
      <Related_URL>
        <URL_Content_Type>
          <Type>GTSFileIdentifier</Type>
        </URL_Content_Type>
        <URL><xsl:value-of select="current()"/></URL>
        <Description>File-Identifier connecting to Global Telecommunication System (GTS)</Description>
      </Related_URL>
  </xsl:template>

  <!-- variables -->
  <xsl:template match="*[@name='variable']">
    <xsl:variable name="value">  <!-- strip away HIDDEN suffix -->
      <xsl:choose>
        <xsl:when test="contains(., 'HIDDEN')">
          <xsl:value-of select="substring-before(., ' &gt; HIDDEN')"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="."/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="keywords" select="document('gcmd/keywords.xml')/*/gcmd:variable"/>
    <xsl:choose>
      <xsl:when test="contains(., ' &gt; ')"> <!-- lookup GCMD variable -->
        <xsl:call-template name="Parameters">
          <xsl:with-param name="topicvar" select="$keywords[@label = $value]"/>
          <xsl:with-param name="origin" select="$value"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise> <!-- CF standard name (may be obsoleted) -->
        <xsl:variable name="standard_name" select="$keywords[nc:standard_name|nco:obsolete_standard_name = $value]"/>
        <xsl:if test="count($standard_name)"> <!-- ignore MM2 variables not listed in keywords.xml -->
          <xsl:call-template name="Parameters">
            <xsl:with-param name="topicvar" select="$standard_name"/>
            <xsl:with-param name="origin" select="$value"/>
          </xsl:call-template>
        </xsl:if>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="Parameters">
    <xsl:param name="topicvar"/>
    <xsl:param name="origin"/>
    <Parameters>
      <Category         jif:default="EARTH SCIENCE"><xsl:value-of select="$topicvar/gcmd:category"/></Category>
      <Topic            jif:default="Not Available"><xsl:value-of select="$topicvar/gcmd:topic"/></Topic>
      <Term             jif:default="Not Available"><xsl:value-of select="$topicvar/gcmd:term"/></Term>
      <Variable_Level_1 jif:default="Not Available"><xsl:value-of select="$topicvar/gcmd:VL1"/></Variable_Level_1>
      <Detailed_Variable><xsl:value-of select="$origin"/></Detailed_Variable>
    </Parameters>
  </xsl:template>

  <!-- areas -->
  <xsl:template match="*[@name='area']">

    <xsl:variable name="topicarea" select="document('')/*/topic:area[@name = current()]"/>

    <Location>
      <Location_Category><xsl:value-of select="$topicarea/@category"/></Location_Category>
      <Location_Type><xsl:value-of select="$topicarea/@type"/></Location_Type>
      <xsl:if test="$topicarea/@subregion1">
        <Location_Subregion1><xsl:value-of select="$topicarea/@subregion1"/></Location_Subregion1>
      </xsl:if>
      <Detailed_Location><xsl:value-of select="."/></Detailed_Location>
    </Location>

    <xsl:if test="$topicarea/@type = 'NORTHERN HEMISPHERE' or $topicarea/@type = 'ARCTIC OCEAN'">
      <Location>
         <Location_Category>GEOGRAPHIC REGION</Location_Category>
         <Location_Type>POLAR</Location_Type>
       </Location>
       <Location>
         <Location_Category>GEOGRAPHIC REGION</Location_Category>
         <Location_Type>ARCTIC</Location_Type>
       </Location>
    </xsl:if>

  </xsl:template>

  <!-- keywords -->
  <xsl:template match="*[@name='keywords']">
    <xsl:call-template name="split">
      <xsl:with-param name="str" select="."/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="split">
    <xsl:param name="str"/>
    <!--recursively splits string into Keyword elements-->
    <xsl:choose>
      <xsl:when test="contains($str, ' ')">
        <Keyword><xsl:value-of select="substring-before($str, ' ')"/></Keyword>
        <xsl:call-template name="split">
          <xsl:with-param name="str" select="substring-after($str, ' ')"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <Keyword><xsl:value-of select="$str"/></Keyword>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- bounding_box -->
  <xsl:template match="*[@name='bounding_box']">
    <Spatial_Coverage>
      <!-- order must be SNWE -->
      <xsl:variable name="SNWE" select="."/>
      <Southernmost_Latitude><xsl:value-of select="substring-before($SNWE, ',')"/></Southernmost_Latitude>
      <xsl:variable name="NWE" select="substring-after($SNWE, ',')"/>
      <Northernmost_Latitude><xsl:value-of select="substring-before($NWE, ',')"/></Northernmost_Latitude>
      <xsl:variable name="WE" select="substring-after($NWE, ',')"/>
      <Westernmost_Longitude><xsl:value-of select="substring-before($WE, ',')"/></Westernmost_Longitude>
      <xsl:variable name="E" select="substring-after($WE, ',')"/>
      <Easternmost_Longitude><xsl:value-of select="$E"/></Easternmost_Longitude>
    </Spatial_Coverage>
  </xsl:template>
  
  <xsl:template name="personell">
    <xsl:param name="role"/>
    <Personnel>
      <Role><xsl:value-of select="$role"/></Role>
      <First_Name>Egil</First_Name>
      <Last_Name>Støren</Last_Name>
      <Email>Not Available</Email>
      <Phone>+4722963000</Phone>
      <Contact_Address>
        <Address>Norwegian Meteorological Institute
P.O. Box 43
Blindern</Address>
        <City>Oslo</City>
        <Postal_Code>N-0313</Postal_Code>
        <Country>Norway</Country>
      </Contact_Address>
    </Personnel>
  </xsl:template>

  <!-- end of transformation, rest is lookup tables -->

  <topic:category name="farming">Farming</topic:category>
  <topic:category name="biodata">Biota</topic:category>
  <topic:category name="biota">Biota</topic:category>
  <topic:category name="boundaries">Boundaries</topic:category>
  <topic:category name="climatologyMeteorologyAtmosphere">Climatology/Meteorology/Atmosphere</topic:category>
  <topic:category name="economy">Economy</topic:category>
  <topic:category name="elevation">Elevation</topic:category>
  <topic:category name="environment">Environment</topic:category>
  <topic:category name="geoscientificinformation">Geoscientific Information</topic:category>
  <topic:category name="health">Health</topic:category>
  <topic:category name="imageryBaseMapsEarthCover">Imagery/Base Maps/Earth Cover</topic:category>
  <topic:category name="intelligenceMilitary">Intelligence/Military</topic:category>
  <topic:category name="inlandWaters">Inland Waters</topic:category>
  <topic:category name="location">Location</topic:category>
  <topic:category name="oceans">Oceans</topic:category>
  <topic:category name="planningCadastre">Planning Cadastre</topic:category>
  <topic:category name="society">Society</topic:category>
  <topic:category name="structure">Structure</topic:category>
  <topic:category name="transportation">Transportation</topic:category>
  <topic:category name="utilitiesCommunications">Utilities/Communications</topic:category>

  <topic:area name="Northern Hemisphere"  category="GEOGRAPHIC REGION" type="NORTHERN HEMISPHERE"/>
  <topic:area name="Southern Hemipshere"  category="GEOGRAPHIC REGION" type="SOUTHERN HEMIPSHERE"/>
  <topic:area name="Arctic Ocean"         category="OCEAN" type="ARCTIC OCEAN"/>
  <topic:area name="Greenland Sea"        category="OCEAN" type="ARCTIC OCEAN"/>
  <topic:area name="Fram Strait"          category="OCEAN" type="ARCTIC OCEAN"/>
  <topic:area name="Central Arctic"       category="OCEAN" type="ARCTIC OCEAN"/>
  <topic:area name="Denmark Strait"       category="OCEAN" type="ARCTIC OCEAN"/>
  <topic:area name="Laptev Sea"           category="OCEAN" type="ARCTIC OCEAN"/>
  <topic:area name="Kara Sea"             category="OCEAN" type="ARCTIC OCEAN"/>
  <topic:area name="Beufort Sea"          category="OCEAN" type="ARCTIC OCEAN"/>
  <topic:area name="Chukchi Sea"          category="OCEAN" type="ARCTIC OCEAN"/>
  <topic:area name="East Siberian Sea"    category="OCEAN" type="ARCTIC OCEAN"/>
  <topic:area name="White Sea"            category="OCEAN" type="ARCTIC OCEAN"/>
  <topic:area name="Denmark Strait Sea"   category="OCEAN" type="ARCTIC OCEAN"/>
  <topic:area name="Barents Sea"          category="OCEAN" type="ARCTIC OCEAN" subregion1="BARENTS SEA"/>
  <topic:area name="Norwegian Sea"        category="OCEAN" type="ATLANTIC OCEAN" subregion1="NORTH ATLANTIC OCEAN"/>
  <topic:area name="Nordic Seas"          category="OCEAN" type="ATLANTIC OCEAN" subregion1="NORTH ATLANTIC OCEAN"/>
  <topic:area name="North Atlantic Ocean" category="OCEAN" type="ATLANTIC OCEAN" subregion1="NORTH ATLANTIC OCEAN"/>
  <topic:area name="Iceland Sea"          category="OCEAN" type="ATLANTIC OCEAN" subregion1="NORTH ATLANTIC OCEAN"/>

  <topic:project shortname="DAMOCLES" longname="Developing Arctic Modelling &amp; Observing Capabilities for Long-term Env. Studies">
    <topic:project name="Damocles,TotalPoleAirship"/>
    <topic:project name="Damocles, AREX 2007"/>
    <topic:project name="DAMOCLES IP"/>
    <topic:project name="DAMOCLES"/> <!-- this is needed to insert longname -->
    <topic:project name="IPY/Damocles/iAOOS"/>
    <topic:project name="Hamburg Arctic Ocean Buoy Drift Experiment DAMOCLES 2008-2009"/>
    <topic:project name="Hamburg Arctic Ocean Buoy Drift Experiment DAMOCLES 2007-2008"/>
    <topic:project name="IPY/iAOOS/Damocles"/>
  </topic:project>

  <topic:project shortname="IPY" longname="INTERNATIONAL POLAR YEAR">
    <topic:project name="AOE-2001"/>
    <topic:project name="Arctic Summer Cloud Ocean Study"/>
    <topic:project name="Arctic Summer Cloud Ocean Study (ASCOS)"/>
    <topic:project name="Arctic Summer Cloud-Ocean Study (ASCOS)"/>
    <topic:project name="Arctic Summer Cloud Ocean Study (ASCOS) 2008"/>
    <topic:project name="AREX 2008"/>
    <topic:project name="ARIST"/>
    <topic:project name="ASCOS"/>
    <topic:project name="AtmoTroll"/>
    <topic:project name="Beaufort Gyre Observing System (BGOS)"/>
    <topic:project name="DAMOCLES"/>
    <topic:project name="Damocles, AREX 2007"/>
    <topic:project name="DAMOCLES IP"/>
    <topic:project name="Damocles,TotalPoleAirship"/>
    <topic:project name="ECMWF"/>
    <topic:project name="EUMETSAT OSI SAF"/>
    <topic:project name="Hamburg Arctic Ocean Buoy Drift Experiment DAMOCLES 2007-2008"/>
    <topic:project name="Hamburg Arctic Ocean Buoy Drift Experiment DAMOCLES 2008-2009"/>
    <topic:project name="HIRLAM"/>
    <topic:project name="IAOOS"/>
    <topic:project name="iAOOS-Norway"/>
    <topic:project name="iAOOS-Norway/IPY-THORPEX"/>
    <topic:project name="IPY/Damocles/iAOOS"/>
    <topic:project name="IPY/iAOOS/Damocles"/>
    <topic:project name="IPY Operational Data Coordination"/>
    <topic:project name="IPY-THORPEX"/>
    <topic:project name="ISSS08"/>
    <topic:project name="ISSS-08"/>
    <topic:project name="LOMROG"/>
    <topic:project name="LOMROG 2007"/>
    <topic:project name="Nansen and Amundsen Basins Observational System (NABOS)"/>
    <topic:project name="North Pole Environmental Observatory (NPEO)"/>
    <topic:project name="POLARCAT"/>
    <topic:project name="POLEWARD"/>
    <topic:project name="REFLEX-2"/>
    <topic:project name="SUMO on Spitsbergen 2008"/>
    <topic:project name="SUMO on Spitsbergen 2009"/>
    <topic:project name="WARPS"/>
  </topic:project>

</xsl:stylesheet>
