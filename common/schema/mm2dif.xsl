<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
                xmlns:mm="http://www.met.no/schema/metamod/MM2"
                xmlns:topic="mailto:geira@met.no?Subject=WTF"
                xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">

  <xsl:param name="DS_name"/>
  <xsl:param name="DS_creationdate"/>
  <xsl:param name="DS_datestamp"/>

  <xsl:output encoding="UTF-8" indent="yes"/>

  <xsl:key name="mm2" match="/*/mm:metadata" use="@name"/>

  <xsl:template match="/">
    <xsl:call-template name="dif"/>
  </xsl:template>

  <xsl:template name="dif" xmlns="http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/">
    <DIF xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/ http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/dif_v9.7.1.xsd">

      <Entry_ID><xsl:value-of select="$DS_name"/></Entry_ID>
      <Entry_Title topic:default="Not Available"><xsl:value-of select="key('mm2', 'title')"/></Entry_Title>

      <Data_Set_Citation>
        <Dataset_Creator topic:default="Not Available"><xsl:value-of select="key('mm2', 'PI_name')"/></Dataset_Creator>
        <Dataset_Title topic:default="Not Available"><xsl:value-of select="key('mm2', 'title')"/></Dataset_Title>
        <Dataset_Release_Date>Not Available</Dataset_Release_Date>
        <Dataset_Release_Place>Not Available</Dataset_Release_Place>
        <Dataset_Publisher><xsl:value-of select="key('mm2', 'institution')"/></Dataset_Publisher>
        <Version>Not Available</Version>
      </Data_Set_Citation>

      <xsl:apply-templates select="key('mm2', 'gtsFileIdentifier')"/>
      <xsl:apply-templates select="key('mm2', 'gtsInstancePattern')"/>
      <xsl:call-template name="personell"/>
      <xsl:apply-templates select="key('mm2', 'variable')"/>

      <xsl:variable name="topiccategory" select="key('mm2', 'topiccategory')"/>
      <ISO_Topic_Category><xsl:value-of select="document('')/*/topic:category[@name = $topiccategory]"/></ISO_Topic_Category>

      <xsl:apply-templates select="key('mm2', 'keywords')"/>

      <Temporal_Coverage>
        <Start_Date><xsl:value-of select="key('mm2', 'datacollection_period_from')"/></Start_Date>
        <Stop_Date><xsl:value-of select="key('mm2', 'datacollection_period_to')"/></Stop_Date>
      </Temporal_Coverage>

      <xsl:apply-templates select="key('mm2', 'bounding_box')"/>
      <Data_Set_Progress>In Work</Data_Set_Progress>
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
            <Short_Name topic:default="Not Available"><xsl:value-of select="$project"/></Short_Name>
            <Long_Name topic:default="Not Available"><xsl:value-of select="$project"/></Long_Name>
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

      <Access_Constraints topic:default="Not Available"><xsl:value-of select="key('mm2', 'distribution_statement')"/></Access_Constraints>
      <Use_Constraints>Not Available</Use_Constraints>
      <Data_Set_Language>Not Available</Data_Set_Language>

      <Data_Center>
         <Data_Center_Name>
           <Short_Name>NO/MET</Short_Name>
           <Long_Name>Norwegian Meteorological Institute, Norway</Long_Name>
         </Data_Center_Name>
         <Data_Center_URL>http://met.no/</Data_Center_URL>
         <xsl:call-template name="personell"/>
       </Data_Center>

      <Reference><xsl:value-of select="key('mm2', 'references')"/></Reference>
      <Summary><Abstract><xsl:value-of select="key('mm2', 'abstract')"/></Abstract></Summary>
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
  <xsl:template match="*[@name='gtsInstancePattern']" xmlns="http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/">
      <Related_URL>
        <URL_Content_Type>
          <Type>GTSInstancePattern</Type>
        </URL_Content_Type>
        <URL><xsl:value-of select="current()"/></URL>
        <Description>Instance pattern connecting to Global Telecommunication System (GTS)</Description>
      </Related_URL>
  </xsl:template>
  <xsl:template match="*[@name='gtsFileIdentifier']" xmlns="http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/">
      <Related_URL>
        <URL_Content_Type>
          <Type>GTSFileIdentifier</Type>
        </URL_Content_Type>
        <URL><xsl:value-of select="current()"/></URL>
        <Description>File-Identifier connecting to Global Telecommunication System (GTS)</Description>
      </Related_URL>
  </xsl:template>

  <!-- variables -->
  <xsl:template match="*[@name='variable']" xmlns="http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/">
    <Parameters>
      <Category>EARTH SCIENCE</Category>
      <xsl:variable name="topicvar" select="document('')/*/topic:var[@name = current()]"/>
      <Topic topic:default="Not Available"><xsl:value-of select="$topicvar/topic:param[1]/@topic"/></Topic>
      <Term topic:default="Not Available"><xsl:value-of select="$topicvar/topic:param[1]/@term"/></Term>
      <Variable_Level_1><xsl:value-of select="$topicvar/topic:param[1]/@VL1"/></Variable_Level_1>
      <Detailed_Variable><xsl:value-of select="."/></Detailed_Variable>
    </Parameters>
  </xsl:template>

  <!-- areas -->
  <xsl:template match="*[@name='area']" xmlns="http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/">

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
  <xsl:template match="*[@name='keywords']" xmlns="http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/">
    <xsl:call-template name="split">
      <xsl:with-param name="str" select="."/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="split" xmlns="http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/">
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
  <xsl:template match="*[@name='bounding_box']" xmlns="http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/">
    <Spatial_Coverage> <!-- order must be SNWE -->
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
  
  <xsl:template name="personell" xmlns="http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/">
    <Personnel>
      <Role>Technical Contact</Role>
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

  <!-- translation from CF to GCMD terms -->
  <topic:var name="aerosol_angstrom_exponent">
    <topic:param topic="Atmosphere" term="Aerosols" VL1="Aerosol Particle Properties"/>
  </topic:var>
  <topic:var name="air_potential_temperature">
    <topic:param topic="Atmosphere" term="Atmospheric Temperature" VL1="Potential Temperature"/>
  </topic:var>
  <topic:var name="air_pressure">
    <topic:param topic="Atmosphere" term="Atmospheric Pressure" VL1="Atmospheric Pressure Measurements"/>
  </topic:var>
  <topic:var name="air_pressure_anomaly">
    <topic:param topic="Atmosphere" term="Atmospheric Pressure" VL1="Pressure Anomalies"/>
  </topic:var>
  <topic:var name="air_pressure_at_cloud_base">
    <topic:param topic="Atmosphere" term="Atmospheric Pressure" VL1="Atmospheric Pressure Measurements"/>
  </topic:var>
  <topic:var name="air_pressure_at_cloud_top">
    <topic:param topic="Atmosphere" term="Atmospheric Pressure" VL1="Atmospheric Pressure Measurements"/>
  </topic:var>
  <topic:var name="air_pressure_at_convective_cloud_base">
    <topic:param topic="Atmosphere" term="Atmospheric Pressure" VL1="Atmospheric Pressure Measurements"/>
  </topic:var>
  <topic:var name="air_pressure_at_convective_cloud_top">
    <topic:param topic="Atmosphere" term="Atmospheric Pressure" VL1="Atmospheric Pressure Measurements"/>
  </topic:var>
  <topic:var name="air_pressure_at_freezing_level">
    <topic:param topic="Atmosphere" term="Atmospheric Pressure" VL1="Atmospheric Pressure Measurements"/>
  </topic:var>
  <topic:var name="air_pressure_at_sea_level">
    <topic:param topic="Atmosphere" term="Atmospheric Pressure" VL1="Sea Level Pressure"/>
  </topic:var>
  <topic:var name="air_temperature">
    <topic:param topic="Atmosphere" term="Atmospheric Temperature" VL1="Air Temperature"/>
  </topic:var>
  <topic:var name="air_temperature_anomaly">
    <topic:param topic="Atmosphere" term="Atmospheric Temperature" VL1="Temperature Anomalies"/>
  </topic:var>
  <topic:var name="air_temperature_at_cloud_top">
    <topic:param topic="Atmosphere" term="Atmospheric Temperature" VL1="Air Temperature"/>
  </topic:var>
  <topic:var name="air_temperature_lapse_rate">
    <topic:param topic="Atmosphere" term="Atmospheric Temperature" VL1="Temperature Tendency"/>
  </topic:var>
  <topic:var name="air_temperature_threshold">
    <topic:param topic="Atmosphere" term="Atmospheric Temperature" VL1="Air Temperature"/>
  </topic:var>
  <topic:var name="atmosphere_absolute_vorticity">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Vorticity"/>
    <topic:param topic="Oceans" term="Ocean Winds" VL1="Vorticity"/>
  </topic:var>
  <topic:var name="atmosphere_boundary_layer_thickness">
    <topic:param topic="Atmosphere" term="Altitude" VL1="Planetary Boundary Layer Height"/>
    <topic:param topic="Atmosphere" term="Atmospheric Pressure" VL1="Planetary Boundary Layer Height"/>
  </topic:var>
  <topic:var name="atmosphere_cloud_condensed_water_content">
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Liquid Water/Ice"/>
  </topic:var>
  <topic:var name="atmosphere_cloud_ice_content">
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Liquid Water/Ice"/>
  </topic:var>
  <topic:var name="atmosphere_cloud_liquid_water_content">
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Liquid Water/Ice"/>
  </topic:var>
  <topic:var name="atmosphere_content_of_sulfate_aerosol">
    <topic:param topic="Atmosphere" term="Aerosols" VL1="Sulfate Particles"/>
    <topic:param topic="Atmosphere" term="Atmospheric Chemistry/Sulfur Compounds" VL1="Atmospheric Chemistry/Sulfur Compounds"/>
  </topic:var>
  <topic:var name="atmosphere_convective_mass_flux">
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Mass Flux"/>
  </topic:var>
  <topic:var name="atmosphere_eastward_stress_due_to_gravity_wave_drag">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Stress"/>
    <topic:param topic="Oceans" term="Ocean Winds" VL1="Wind Stress"/>
  </topic:var>
  <topic:var name="atmosphere_heat_diffusivity">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Atmospheric Heating"/>
  </topic:var>
  <topic:var name="atmosphere_horizontal_streamfunction">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Streamfunctions"/>
  </topic:var>
  <topic:var name="atmosphere_net_rate_of_absorption_of_longwave_energy">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Absorption"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="atmosphere_net_rate_of_absorption_of_shortwave_energy">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Absorption"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
  </topic:var>
  <topic:var name="atmosphere_northward_stress_due_to_gravity_wave_drag">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Stress"/>
    <topic:param topic="Oceans" term="Ocean Winds" VL1="Wind Stress"/>
  </topic:var>
  <topic:var name="atmosphere_optical_thickness_due_to_aerosol">
    <topic:param topic="Atmosphere" term="Aerosols" VL1="Aerosol Optical Depth/Thickness"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Optical Depth/Thickness"/>
  </topic:var>
  <topic:var name="atmosphere_relative_vorticity">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Vorticity"/>
    <topic:param topic="Oceans" term="Ocean Winds" VL1="Vorticity"/>
  </topic:var>
  <topic:var name="atmosphere_so4_content">
    <topic:param topic="Atmosphere" term="Atmospheric Chemistry/Sulfur Compounds" VL1="Atmospheric Chemistry/Sulfur Compounds"/>
  </topic:var>
  <topic:var name="atmosphere_sulfate_content">
    <topic:param topic="Atmosphere" term="Atmospheric Chemistry/Sulfur Compounds" VL1="Atmospheric Chemistry/Sulfur Compounds"/>
  </topic:var>
  <topic:var name="atmosphere_water_content">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Water Vapor"/>
  </topic:var>
  <topic:var name="atmosphere_water_vapor_content">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Water Vapor"/>
  </topic:var>
  <topic:var name="baroclinic_eastward_sea_water_velocity">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Ocean Currents"/>
  </topic:var>
  <topic:var name="baroclinic_northward_sea_water_velocity">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Ocean Currents"/>
  </topic:var>
  <topic:var name="barotropic_eastward_sea_water_velocity">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Ocean Currents"/>
  </topic:var>
  <topic:var name="barotropic_northward_sea_water_velocity">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Ocean Currents"/>
  </topic:var>
  <topic:var name="baseflow_amount">
    <topic:param topic="Hydrosphere" term="Surface Water" VL1="Runoff"/>
  </topic:var>
  <topic:var name="bedrock_altitude">
    <topic:param topic="Land Surface" term="Topography" VL1="Terrain Elevation"/>
  </topic:var>
  <topic:var name="bedrock_altitude_change_due_to_isostatic_adjustment">
    <topic:param topic="Land Surface" term="Topography" VL1="Terrain Elevation"/>
  </topic:var>
  <topic:var name="bioluminescent_photon_rate_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Bioluminescence"/>
    <topic:param topic="Biosphere" term="Ecological Dynamics" VL1="Bioluminescence"/>
  </topic:var>
  <topic:var name="biomass_burning_carbon_flux">
    <topic:param topic="Human Dimensions" term="Environmental Impacts" VL1="Biomass Burning"/>
  </topic:var>
  <topic:var name="canopy_and_surface_water_amount">
    <topic:param topic="Biosphere" term="Vegetation" VL1="Canopy Characteristics"/>
  </topic:var>
  <topic:var name="canopy_height">
    <topic:param topic="Biosphere" term="Vegetation" VL1="Canopy Characteristics"/>
  </topic:var>
  <topic:var name="canopy_water_amount">
    <topic:param topic="Biosphere" term="Vegetation" VL1="Canopy Characteristics"/>
  </topic:var>
  <topic:var name="change_over_time_in_atmospheric_water_content_due_to_advection">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Water Vapor"/>
  </topic:var>
  <topic:var name="change_over_time_in_surface_snow_amount">
    <topic:param topic="Hydrosphere" term="Snow/Ice" VL1="Snow Cover"/>
    <topic:param topic="Cryosphere" term="Snow/Ice" VL1="Snow Cover"/>
  </topic:var>
  <topic:var name="chlorophyll_concentration_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Chemistry" VL1="Pigments"/>
    <topic:param topic="Oceans" term="Ocean Chemistry" VL1="Chlorophyll"/>
    <topic:param topic="Hydrosphere" term="Water Quality/Water Chemistry" VL1="Chlorophyll"/>
    <topic:param topic="Biosphere" term="Microbiota" VL1="Pigments"/>
    <topic:param topic="Biosphere" term="Microbiota" VL1="Chlorophyll"/>
  </topic:var>
  <topic:var name="cloud_area_fraction">
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Amount/Frequency"/>
  </topic:var>
  <topic:var name="cloud_area_fraction_in_atmosphere_layer">
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Amount/Frequency"/>
  </topic:var>
  <topic:var name="cloud_base_altitude">
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Base"/>
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Base Pressure"/>
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Ceiling"/>
  </topic:var>
  <topic:var name="cloud_condensed_water_content_of_atmosphere_layer">
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Liquid Water/Ice"/>
  </topic:var>
  <topic:var name="cloud_ice_content_of_atmosphere_layer">
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Liquid Water/Ice"/>
  </topic:var>
  <topic:var name="cloud_liquid_water_content_of_atmosphere_layer">
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Liquid Water/Ice"/>
  </topic:var>
  <topic:var name="cloud_top_altitude">
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Top Pressure"/>
  </topic:var>
  <topic:var name="concentration_of_chlorophyll_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Chemistry" VL1="Pigments"/>
    <topic:param topic="Oceans" term="Ocean Chemistry" VL1="Chlorophyll"/>
    <topic:param topic="Hydrosphere" term="Water Quality/Water Chemistry" VL1="Chlorophyll"/>
    <topic:param topic="Biosphere" term="Microbiota" VL1="Pigments"/>
    <topic:param topic="Biosphere" term="Microbiota" VL1="Chlorophyll"/>
  </topic:var>
  <topic:var name="concentration_of_suspended_matter_in_sea_water">
    <topic:param topic="Oceans" term="Marine Sediments" VL1="Suspended Solids"/>
    <topic:param topic="Oceans" term="Ocean Chemistry" VL1="Suspended Solids"/>
    <topic:param topic="Hydrosphere" term="Water Quality/Water Chemistry" VL1="Suspended Solids"/>
  </topic:var>
  <topic:var name="convective_cloud_area_fraction">
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Amount/Frequency"/>
  </topic:var>
  <topic:var name="convective_cloud_area_fraction_in_atmosphere_layer">
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Amount/Frequency"/>
  </topic:var>
  <topic:var name="convective_cloud_base_altitude">
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Base"/>
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Base Pressure"/>
  </topic:var>
  <topic:var name="convective_cloud_base_height">
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Base"/>
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Base Pressure"/>
  </topic:var>
  <topic:var name="convective_cloud_top_altitude">
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Top Pressure"/>
  </topic:var>
  <topic:var name="convective_cloud_top_height">
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Top Pressure"/>
  </topic:var>
  <topic:var name="convective_precipitation_amount">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Precipitation Amount"/>
  </topic:var>
  <topic:var name="convective_precipitation_flux">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Precipitation"/>
  </topic:var>
  <topic:var name="convective_rainfall_amount">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Precipitation Amount"/>
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Rain"/>
  </topic:var>
  <topic:var name="convective_rainfall_flux">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Rain"/>
  </topic:var>
  <topic:var name="convective_rainfall_rate">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Rain"/>
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Precipitation Rate"/>
  </topic:var>
  <topic:var name="convective_snowfall_amount">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Precipitation Amount"/>
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Snow"/>
  </topic:var>
  <topic:var name="convective_snowfall_flux">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Snow"/>
  </topic:var>
  <topic:var name="correction_for_model_negative_specific_humidity">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Humidity"/>
  </topic:var>
  <topic:var name="dew_point_depression">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Dew Point Temperature"/>
  </topic:var>
  <topic:var name="dew_point_temperature">
    <topic:param topic="Atmosphere" term="Atmospheric Temperature" VL1="Dew Point Temperature"/>
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Dew Point Temperature"/>
  </topic:var>
  <topic:var name="difference_of_air_pressure_from_model_reference">
    <topic:param topic="Atmosphere" term="Atmospheric Pressure" VL1="Pressure Anomalies"/>
  </topic:var>
  <topic:var name="direction_of_sea_ice_velocity">
    <topic:param topic="Oceans" term="Sea Ice" VL1="Sea Ice Motion"/>
    <topic:param topic="Cryosphere" term="Sea Ice" VL1="Sea Ice Motion"/>
  </topic:var>
  <topic:var name="direction_of_sea_water_velocity">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Ocean Currents"/>
    <topic:param topic="Oceans" term="Tides" VL1="Tidal Currents"/>
  </topic:var>
  <topic:var name="direction_of_swell_wave_velocity">
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Wave Speed/Direction"/>
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Swells"/>
  </topic:var>
  <topic:var name="direction_of_wind_wave_velocity">
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Wave Speed/Direction"/>
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Wind Waves"/>
  </topic:var>
  <topic:var name="divergence_of_sea_ice_velocity">
    <topic:param topic="Oceans" term="Sea Ice" VL1="Sea Ice Motion"/>
    <topic:param topic="Cryosphere" term="Sea Ice" VL1="Sea Ice Motion"/>
  </topic:var>
  <topic:var name="divergence_of_wind">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Convergence/Divergence"/>
  </topic:var>
  <topic:var name="downward_heat_flux_at_ground_level_in_snow">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Heat Flux"/>
  </topic:var>
  <topic:var name="downward_heat_flux_at_ground_level_in_soil">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Heat Flux"/>
  </topic:var>
  <topic:var name="downward_heat_flux_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Heat Flux"/>
  </topic:var>
  <topic:var name="downward_heat_flux_in_sea_ice">
    <topic:param topic="Oceans" term="Sea Ice" VL1="Heat Flux"/>
    <topic:param topic="Cryosphere" term="Sea Ice" VL1="Heat Flux"/>
  </topic:var>
  <topic:var name="downward_sea_ice_basal_salt_flux">
    <topic:param topic="Oceans" term="Salinity/Density" VL1="Salt Transport"/>
  </topic:var>
  <topic:var name="downwelling_longwave_flux_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="downwelling_longwave_radiance_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="downwelling_photon_flux_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Irradiance"/>
  </topic:var>
  <topic:var name="downwelling_photon_radiance_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Radiance"/>
  </topic:var>
  <topic:var name="downwelling_photon_spherical_irradiance_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Irradiance"/>
  </topic:var>
  <topic:var name="downwelling_photosynthetic_photon_flux_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Irradiance"/>
  </topic:var>
  <topic:var name="downwelling_photosynthetic_photon_radiance_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Radiance"/>
  </topic:var>
  <topic:var name="downwelling_photosynthetic_photon_spherical_irradiance_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Irradiance"/>
  </topic:var>
  <topic:var name="downwelling_photosynthetic_radiance_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Radiance"/>
  </topic:var>
  <topic:var name="downwelling_photosynthetic_radiative_flux_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Irradiance"/>
  </topic:var>
  <topic:var name="downwelling_photosynthetic_spherical_irradiance_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Irradiance"/>
  </topic:var>
  <topic:var name="downwelling_radiance_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Radiance"/>
  </topic:var>
  <topic:var name="downwelling_radiative_flux_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Irradiance"/>
  </topic:var>
  <topic:var name="downwelling_shortwave_flux_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Flux"/>
  </topic:var>
  <topic:var name="downwelling_shortwave_radiance_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
  </topic:var>
  <topic:var name="downwelling_spectral_photon_flux_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Irradiance"/>
  </topic:var>
  <topic:var name="downwelling_spectral_photon_radiance_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Radiance"/>
  </topic:var>
  <topic:var name="downwelling_spectral_photon_spherical_irradiance_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Irradiance"/>
  </topic:var>
  <topic:var name="downwelling_spectral_radiance_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Radiance"/>
  </topic:var>
  <topic:var name="downwelling_spectral_radiative_flux_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Flux"/>
  </topic:var>
  <topic:var name="downwelling_spectral_radiative_flux_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Irradiance"/>
  </topic:var>
  <topic:var name="downwelling_spectral_spherical_irradiance_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Irradiance"/>
  </topic:var>
  <topic:var name="downwelling_spherical_irradiance_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Irradiance"/>
  </topic:var>
  <topic:var name="duration_of_sunshine">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Sunshine"/>
  </topic:var>
  <topic:var name="eastward_sea_ice_velocity">
    <topic:param topic="Oceans" term="Sea Ice" VL1="Sea Ice Motion"/>
    <topic:param topic="Cryosphere" term="Sea Ice" VL1="Sea Ice Motion"/>
  </topic:var>
  <topic:var name="eastward_sea_water_velocity">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Ocean Currents"/>
    <topic:param topic="Oceans" term="Tides" VL1="Tidal Currents"/>
  </topic:var>
  <topic:var name="eastward_wind">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Surface Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Profiles"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Boundary Layer Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Upper Level Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Flight Level Winds"/>
    <topic:param topic="Oceans" term="Ocean Winds" VL1="Surface Winds"/>
  </topic:var>
  <topic:var name="eastward_wind_shear">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Shear"/>
    <topic:param topic="Oceans" term="Ocean Winds" VL1="Wind Shear"/>
  </topic:var>
  <topic:var name="equivalent_potential_temperature">
    <topic:param topic="Atmosphere" term="Atmospheric Temperature" VL1="Potential Temperature"/>
  </topic:var>
  <topic:var name="equivalent_pressure_of_atmosphere_ozone_content">
    <topic:param topic="Atmosphere" term="Atmospheric Chemistry/Oxygen Compounds" VL1="Ozone"/>
  </topic:var>
  <topic:var name="equivalent_temperature">
    <topic:param topic="Atmosphere" term="Atmospheric Temperature" VL1="Air Temperature"/>
  </topic:var>
  <topic:var name="equivalent_thickness_at_stp_of_atmosphere_o3_content">
    <topic:param topic="Atmosphere" term="Atmospheric Chemistry/Oxygen Compounds" VL1="Ozone"/>
  </topic:var>
  <topic:var name="equivalent_thickness_at_stp_of_atmosphere_ozone_content">
    <topic:param topic="Atmosphere" term="Atmospheric Chemistry/Oxygen Compounds" VL1="Ozone"/>
  </topic:var>
  <topic:var name="ertel_potential_vorticity">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Vorticity"/>
    <topic:param topic="Oceans" term="Ocean Winds" VL1="Vorticity"/>
  </topic:var>
  <topic:var name="fractional_saturation_of_oxygen_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Chemistry" VL1="Oxygen"/>
    <topic:param topic="Hydrosphere" term="Water Quality/Water Chemistry" VL1="Oxygen"/>
  </topic:var>
  <topic:var name="freezing_level_altitude">
    <topic:param topic="Atmosphere" term="Atmospheric Phenomena" VL1="Freeze"/>
  </topic:var>
  <topic:var name="frozen_water_content_of_soil_layer">
    <topic:param topic="Land Surface" term="Soils" VL1="Soil Moisture/Water Content"/>
  </topic:var>
  <topic:var name="geopotential_height">
    <topic:param topic="Atmosphere" term="Altitude" VL1="Geopotential Height"/>
  </topic:var>
  <topic:var name="geopotential_height_anomaly">
    <topic:param topic="Atmosphere" term="Altitude" VL1="Geopotential Height"/>
  </topic:var>
  <topic:var name="geostrophic_eastward_wind">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Surface Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Profiles"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Boundary Layer Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Upper Level Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Flight Level Winds"/>
    <topic:param topic="Oceans" term="Ocean Winds" VL1="Surface Winds"/>
  </topic:var>
  <topic:var name="geostrophic_northward_wind">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Surface Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Profiles"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Boundary Layer Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Upper Level Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Flight Level Winds"/>
    <topic:param topic="Oceans" term="Ocean Winds" VL1="Surface Winds"/>
  </topic:var>
  <topic:var name="global_average_sea_level_change">
    <topic:param topic="Oceans" term="Coastal Processes" VL1="Sea Level Rise"/>
    <topic:param topic="Paleoclimate" term="Paleoclimate Reconstructions" VL1="Sea Level Reconstruction"/>
  </topic:var>
  <topic:var name="global_average_thermosteric_sea_level_change">
    <topic:param topic="Oceans" term="Coastal Processes" VL1="Sea Level Rise"/>
    <topic:param topic="Paleoclimate" term="Paleoclimate Reconstructions" VL1="Sea Level Reconstruction"/>
  </topic:var>
  <topic:var name="grid_eastward_wind">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Surface Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Profiles"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Boundary Layer Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Upper Level Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Flight Level Winds"/>
    <topic:param topic="Oceans" term="Ocean Winds" VL1="Surface Winds"/>
  </topic:var>
  <topic:var name="grid_northward_wind">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Surface Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Profiles"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Boundary Layer Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Upper Level Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Flight Level Winds"/>
    <topic:param topic="Oceans" term="Ocean Winds" VL1="Surface Winds"/>
  </topic:var>
  <topic:var name="gross_primary_productivity_of_carbon">
    <topic:param topic="Biosphere" term="Ecological Dynamics" VL1="Primary Production"/>
  </topic:var>
  <topic:var name="heat_flux_correction">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Heat Flux"/>
  </topic:var>
  <topic:var name="height_at_cloud_top">
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Ceiling"/>
  </topic:var>
  <topic:var name="humidity_mixing_ratio">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Humidity"/>
  </topic:var>
  <topic:var name="ice_concentration">
    <topic:param topic="Cryosphere" term="Sea Ice" VL1="Sea Ice Concentration"/>
    <topic:param topic="Oceans" term="Sea Ice" VL1="Sea Ice Concentration"/>
  </topic:var>
  <topic:var name="ice_edge">
    <topic:param topic="Cryosphere" term="Sea Ice" VL1="Ice Edges"/>
    <topic:param topic="Oceans" term="Sea Ice" VL1="Ice Edges"/>
  </topic:var>
  <topic:var name="ice_type">
    <topic:param topic="Cryosphere" term="Sea Ice" VL1="Ice Types"/>
    <topic:param topic="Oceans" term="Sea Ice" VL1="Ice Types"/>
  </topic:var>
  <topic:var name="integral_of_air_temperature_deficit_wrt_time">
    <topic:param topic="Atmosphere" term="Atmospheric Temperature" VL1="Air Temperature"/>
  </topic:var>
  <topic:var name="integral_of_air_temperature_excess_wrt_time">
    <topic:param topic="Atmosphere" term="Atmospheric Temperature" VL1="Air Temperature"/>
  </topic:var>
  <topic:var name="integral_of_sea_water_temperature_wrt_depth_in_ocean_layer">
    <topic:param topic="Oceans" term="Ocean Temperature" VL1="Water Temperature"/>
  </topic:var>
  <topic:var name="isccp_cloud_area_fraction">
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Amount/Frequency"/>
  </topic:var>
  <topic:var name="isotropic_longwave_radiance_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="isotropic_shortwave_radiance_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
  </topic:var>
  <topic:var name="lagrangian_tendency_of_air_pressure">
    <topic:param topic="Atmosphere" term="Atmospheric Pressure" VL1="Pressure Tendency"/>
  </topic:var>
  <topic:var name="lagrangian_tendency_of_atmosphere_sigma_coordinate">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Vertical Wind Motion"/>
  </topic:var>
  <topic:var name="land_cover">
    <topic:param topic="Land Surface" term="Land Use/Land Cover" VL1="Land Cover"/>
  </topic:var>
  <topic:var name="land_ice_area_fraction">
    <topic:param topic="Hydrosphere" term="Snow/Ice" VL1="Ice Extent"/>
    <topic:param topic="Cryosphere" term="Snow/Ice" VL1="Ice Extent"/>
  </topic:var>
  <topic:var name="land_ice_basal_melt_rate">
    <topic:param topic="Hydrosphere" term="Snow/Ice" VL1="Ice Growth/Melt"/>
    <topic:param topic="Cryosphere" term="Snow/Ice" VL1="Ice Growth/Melt"/>
  </topic:var>
  <topic:var name="land_ice_basal_x_velocity">
    <topic:param topic="Hydrosphere" term="Glaciers/Ice Sheets" VL1="Glacier Motion/Ice Sheet Motion"/>
    <topic:param topic="Cryosphere" term="Glaciers/Ice Sheets" VL1="Glacier Motion/Ice Sheet Motion"/>
  </topic:var>
  <topic:var name="land_ice_basal_y_velocity">
    <topic:param topic="Hydrosphere" term="Glaciers/Ice Sheets" VL1="Glacier Motion/Ice Sheet Motion"/>
    <topic:param topic="Cryosphere" term="Glaciers/Ice Sheets" VL1="Glacier Motion/Ice Sheet Motion"/>
  </topic:var>
  <topic:var name="land_ice_calving_rate">
    <topic:param topic="Hydrosphere" term="Glaciers/Ice Sheets" VL1="Glaciers"/>
    <topic:param topic="Hydrosphere" term="Glaciers/Ice Sheets" VL1="Ice Sheets"/>
    <topic:param topic="Hydrosphere" term="Glaciers/Ice Sheets" VL1="Icebergs"/>
    <topic:param topic="Cryosphere" term="Sea Ice" VL1="Icebergs"/>
    <topic:param topic="Cryosphere" term="Glaciers/Ice Sheets" VL1="Ice Sheets"/>
    <topic:param topic="Cryosphere" term="Glaciers/Ice Sheets" VL1="Glaciers"/>
    <topic:param topic="Cryosphere" term="Glaciers/Ice Sheets" VL1="Icebergs"/>
  </topic:var>
  <topic:var name="land_ice_lwe_basal_melt_rate">
    <topic:param topic="Hydrosphere" term="Snow/Ice" VL1="Ice Growth/Melt"/>
    <topic:param topic="Cryosphere" term="Snow/Ice" VL1="Ice Growth/Melt"/>
  </topic:var>
  <topic:var name="land_ice_lwe_calving_rate">
    <topic:param topic="Hydrosphere" term="Glaciers/Ice Sheets" VL1="Glaciers"/>
    <topic:param topic="Hydrosphere" term="Glaciers/Ice Sheets" VL1="Ice Sheets"/>
    <topic:param topic="Hydrosphere" term="Glaciers/Ice Sheets" VL1="Icebergs"/>
    <topic:param topic="Cryosphere" term="Sea Ice" VL1="Icebergs"/>
    <topic:param topic="Cryosphere" term="Glaciers/Ice Sheets" VL1="Ice Sheets"/>
    <topic:param topic="Cryosphere" term="Glaciers/Ice Sheets" VL1="Glaciers"/>
    <topic:param topic="Cryosphere" term="Glaciers/Ice Sheets" VL1="Icebergs"/>
  </topic:var>
  <topic:var name="land_ice_lwe_surface_specific_mass_balance">
    <topic:param topic="Hydrosphere" term="Glaciers/Ice Sheets" VL1="Glaciers"/>
    <topic:param topic="Hydrosphere" term="Glaciers/Ice Sheets" VL1="Ice Sheets"/>
    <topic:param topic="Cryosphere" term="Glaciers/Ice Sheets" VL1="Ice Sheets"/>
    <topic:param topic="Cryosphere" term="Glaciers/Ice Sheets" VL1="Glaciers"/>
  </topic:var>
  <topic:var name="land_ice_surface_specific_mass_balance">
    <topic:param topic="Hydrosphere" term="Glaciers/Ice Sheets" VL1="Glaciers"/>
    <topic:param topic="Hydrosphere" term="Glaciers/Ice Sheets" VL1="Ice Sheets"/>
    <topic:param topic="Cryosphere" term="Glaciers/Ice Sheets" VL1="Ice Sheets"/>
    <topic:param topic="Cryosphere" term="Glaciers/Ice Sheets" VL1="Glaciers"/>
  </topic:var>
  <topic:var name="land_ice_temperature">
    <topic:param topic="Cryosphere" term="Snow/Ice" VL1="Snow/Ice Temperature"/>
  </topic:var>
  <topic:var name="land_ice_thickness">
    <topic:param topic="Hydrosphere" term="Snow/Ice" VL1="Ice Depth/Thickness"/>
    <topic:param topic="Cryosphere" term="Snow/Ice" VL1="Ice Depth/Thickness"/>
  </topic:var>
  <topic:var name="land_ice_vertical_mean_x_velocity">
    <topic:param topic="Hydrosphere" term="Glaciers/Ice Sheets" VL1="Glacier Motion/Ice Sheet Motion"/>
    <topic:param topic="Cryosphere" term="Glaciers/Ice Sheets" VL1="Glacier Motion/Ice Sheet Motion"/>
  </topic:var>
  <topic:var name="land_ice_vertical_mean_y_velocity">
    <topic:param topic="Hydrosphere" term="Glaciers/Ice Sheets" VL1="Glacier Motion/Ice Sheet Motion"/>
    <topic:param topic="Cryosphere" term="Glaciers/Ice Sheets" VL1="Glacier Motion/Ice Sheet Motion"/>
  </topic:var>
  <topic:var name="land_ice_x_velocity">
    <topic:param topic="Hydrosphere" term="Glaciers/Ice Sheets" VL1="Glacier Motion/Ice Sheet Motion"/>
    <topic:param topic="Cryosphere" term="Glaciers/Ice Sheets" VL1="Glacier Motion/Ice Sheet Motion"/>
  </topic:var>
  <topic:var name="land_ice_y_velocity">
    <topic:param topic="Hydrosphere" term="Glaciers/Ice Sheets" VL1="Glacier Motion/Ice Sheet Motion"/>
    <topic:param topic="Cryosphere" term="Glaciers/Ice Sheets" VL1="Glacier Motion/Ice Sheet Motion"/>
  </topic:var>
  <topic:var name="large_scale_cloud_area_fraction">
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Amount/Frequency"/>
  </topic:var>
  <topic:var name="large_scale_precipitation_amount">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Precipitation Amount"/>
  </topic:var>
  <topic:var name="large_scale_precipitation_flux">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Precipitation"/>
  </topic:var>
  <topic:var name="large_scale_rainfall_amount">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Precipitation Amount"/>
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Rain"/>
  </topic:var>
  <topic:var name="large_scale_rainfall_flux">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Rain"/>
  </topic:var>
  <topic:var name="large_scale_rainfall_rate">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Rain"/>
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Precipitation Rate"/>
  </topic:var>
  <topic:var name="large_scale_snowfall_amount">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Precipitation Amount"/>
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Snow"/>
  </topic:var>
  <topic:var name="large_scale_snowfall_flux">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Snow"/>
  </topic:var>
  <topic:var name="leaf_area_index">
    <topic:param topic="Biosphere" term="Vegetation" VL1="Vegetation Index"/>
  </topic:var>
  <topic:var name="liquid_water_content_of_snow_layer">
    <topic:param topic="Hydrosphere" term="Snow/Ice" VL1="Snow Water Equivalent"/>
    <topic:param topic="Cryosphere" term="Snow/Ice" VL1="Snow Water Equivalent"/>
  </topic:var>
  <topic:var name="liquid_water_content_of_soil_layer">
    <topic:param topic="Land Surface" term="Soils" VL1="Soil Moisture/Water Content"/>
  </topic:var>
  <topic:var name="litter_carbon_content">
    <topic:param topic="Biosphere" term="Vegetation" VL1="Litter Characteristics"/>
  </topic:var>
  <topic:var name="litter_carbon_flux">
    <topic:param topic="Biosphere" term="Vegetation" VL1="Litter Characteristics"/>
  </topic:var>
  <topic:var name="longwave_radiance">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="lwe_convective_precipitation_rate">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Liquid Water Equivalent"/>
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Precipitation Rate"/>
  </topic:var>
  <topic:var name="lwe_convective_snowfall_rate">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Snow"/>
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Liquid Water Equivalent"/>
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Precipitation Rate"/>
  </topic:var>
  <topic:var name="lwe_large_scale_precipitation_rate">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Liquid Water Equivalent"/>
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Precipitation Rate"/>
  </topic:var>
  <topic:var name="lwe_large_scale_snowfall_rate">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Snow"/>
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Liquid Water Equivalent"/>
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Precipitation Rate"/>
  </topic:var>
  <topic:var name="lwe_precipitation_rate">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Liquid Water Equivalent"/>
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Precipitation Rate"/>
  </topic:var>
  <topic:var name="lwe_snowfall_rate">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Snow"/>
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Liquid Water Equivalent"/>
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Precipitation Rate"/>
  </topic:var>
  <topic:var name="lwe_thickness_of_atmosphere_water_vapor_content">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Humidity"/>
  </topic:var>
  <topic:var name="lwe_thickness_of_canopy_water_amount">
    <topic:param topic="Biosphere" term="Vegetation" VL1="Canopy Characteristics"/>
  </topic:var>
  <topic:var name="lwe_thickness_of_convective_precipitation_amount">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Precipitation Amount"/>
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Liquid Water Equivalent"/>
  </topic:var>
  <topic:var name="lwe_thickness_of_convective_snowfall_amount">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Precipitation Amount"/>
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Snow"/>
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Liquid Water Equivalent"/>
  </topic:var>
  <topic:var name="lwe_thickness_of_frozen_water_content_of_soil_layer">
    <topic:param topic="Land Surface" term="Soils" VL1="Soil Moisture/Water Content"/>
  </topic:var>
  <topic:var name="lwe_thickness_of_large_scale_precipitation_amount">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Precipitation Amount"/>
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Liquid Water Equivalent"/>
  </topic:var>
  <topic:var name="lwe_thickness_of_large_scale_snowfall_amount">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Precipitation Amount"/>
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Snow"/>
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Liquid Water Equivalent"/>
  </topic:var>
  <topic:var name="lwe_thickness_of_moisture_content_of_soil_layer">
    <topic:param topic="Land Surface" term="Soils" VL1="Soil Moisture/Water Content"/>
  </topic:var>
  <topic:var name="lwe_thickness_of_precipitation_amount">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Precipitation Amount"/>
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Liquid Water Equivalent"/>
  </topic:var>
  <topic:var name="lwe_thickness_of_snowfall_amount">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Precipitation Amount"/>
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Snow"/>
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Liquid Water Equivalent"/>
  </topic:var>
  <topic:var name="lwe_thickness_of_soil_moisture_content">
    <topic:param topic="Land Surface" term="Soils" VL1="Soil Moisture/Water Content"/>
  </topic:var>
  <topic:var name="lwe_thickness_of_surface_snow_amount">
    <topic:param topic="Hydrosphere" term="Snow/Ice" VL1="Snow Water Equivalent"/>
    <topic:param topic="Cryosphere" term="Snow/Ice" VL1="Snow Water Equivalent"/>
  </topic:var>
  <topic:var name="lwe_thickness_of_water_evaporation_amount">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Evaporation"/>
    <topic:param topic="Oceans" term="Ocean Heat Budget" VL1="Evaporation"/>
  </topic:var>
  <topic:var name="lwe_water_evaporation_rate">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Evaporation"/>
    <topic:param topic="Oceans" term="Ocean Heat Budget" VL1="Evaporation"/>
  </topic:var>
  <topic:var name="magnitude_of_surface_downward_stress">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Stress"/>
    <topic:param topic="Oceans" term="Ocean Winds" VL1="Wind Stress"/>
  </topic:var>
  <topic:var name="mass_concentration_of_oxygen_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Chemistry" VL1="Oxygen"/>
    <topic:param topic="Hydrosphere" term="Water Quality/Water Chemistry" VL1="Oxygen"/>
  </topic:var>
  <topic:var name="mass_concentration_of_sulfate_aerosol_in_air">
    <topic:param topic="Atmosphere" term="Aerosols" VL1="Sulfate Particles"/>
    <topic:param topic="Atmosphere" term="Atmospheric Chemistry/Sulfur Compounds" VL1="Atmospheric Chemistry/Sulfur Compounds"/>
  </topic:var>
  <topic:var name="mass_fraction_of_cloud_condensed_water_in_air">
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Liquid Water/Ice"/>
  </topic:var>
  <topic:var name="mass_fraction_of_cloud_ice_in_air">
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Liquid Water/Ice"/>
  </topic:var>
  <topic:var name="mass_fraction_of_cloud_liquid_water_in_air">
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Liquid Water/Ice"/>
  </topic:var>
  <topic:var name="mass_fraction_of_convective_cloud_ice_in_air">
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Liquid Water/Ice"/>
  </topic:var>
  <topic:var name="mass_fraction_of_convective_cloud_liquid_water_in_air">
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Liquid Water/Ice"/>
  </topic:var>
  <topic:var name="mass_fraction_of_convective_condensed_water_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Humidity"/>
  </topic:var>
  <topic:var name="mass_fraction_of_dimethyl_sulfide_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Chemistry/Sulfur Compounds" VL1="Dimethyl Sulfide"/>
  </topic:var>
  <topic:var name="mass_fraction_of_frozen_water_in_soil_moisture">
    <topic:param topic="Land Surface" term="Soils" VL1="Soil Moisture/Water Content"/>
  </topic:var>
  <topic:var name="mass_fraction_of_graupel_in_air">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Freezing Rain"/>
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Precipitation Amount"/>
  </topic:var>
  <topic:var name="mass_fraction_of_o3_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Chemistry/Oxygen Compounds" VL1="Ozone"/>
  </topic:var>
  <topic:var name="mass_fraction_of_ozone_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Chemistry/Oxygen Compounds" VL1="Ozone"/>
  </topic:var>
  <topic:var name="mass_fraction_of_precipitation_in_air">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Precipitation Amount"/>
  </topic:var>
  <topic:var name="mass_fraction_of_rain_in_air">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Rain"/>
  </topic:var>
  <topic:var name="mass_fraction_of_snow_in_air">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Snow"/>
  </topic:var>
  <topic:var name="mass_fraction_of_stratiform_cloud_ice_in_air">
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Liquid Water/Ice"/>
  </topic:var>
  <topic:var name="mass_fraction_of_stratiform_cloud_liquid_water_in_air">
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Liquid Water/Ice"/>
  </topic:var>
  <topic:var name="mass_fraction_of_sulfur_dioxide_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Chemistry/Sulfur Compounds" VL1="Sulfur Dioxide"/>
    <topic:param topic="Atmosphere" term="Atmospheric Chemistry/Sulfur Compounds" VL1="Sulfur Oxides"/>
  </topic:var>
  <topic:var name="mass_fraction_of_unfrozen_water_in_soil_moisture">
    <topic:param topic="Land Surface" term="Soils" VL1="Soil Moisture/Water Content"/>
  </topic:var>
  <topic:var name="mass_fraction_of_water_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Humidity"/>
  </topic:var>
  <topic:var name="model_level_number_at_convective_cloud_base">
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Base"/>
  </topic:var>
  <topic:var name="model_level_number_at_convective_cloud_top">
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Ceiling"/>
  </topic:var>
  <topic:var name="model_level_number_at_top_of_atmosphere_boundary_layer">
    <topic:param topic="Atmosphere" term="Atmospheric Pressure" VL1="Planetary Boundary Layer Height"/>
  </topic:var>
  <topic:var name="moisture_content_of_soil_layer">
    <topic:param topic="Land Surface" term="Soils" VL1="Soil Moisture/Water Content"/>
  </topic:var>
  <topic:var name="moisture_content_of_soil_layer_at_field_capacity">
    <topic:param topic="Land Surface" term="Soils" VL1="Soil Moisture/Water Content"/>
  </topic:var>
  <topic:var name="mole_fraction_of_o3_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Chemistry/Oxygen Compounds" VL1="Ozone"/>
  </topic:var>
  <topic:var name="mole_fraction_of_ozone_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Chemistry/Oxygen Compounds" VL1="Ozone"/>
  </topic:var>
  <topic:var name="moles_of_nitrate_and_nitrite_per_unit_mass_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Chemistry" VL1="Nitrate"/>
    <topic:param topic="Oceans" term="Ocean Chemistry" VL1="Nutrients"/>
    <topic:param topic="Hydrosphere" term="Water Quality/Water Chemistry" VL1="Nutrients"/>
  </topic:var>
  <topic:var name="moles_of_nitrate_per_unit_mass_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Chemistry" VL1="Nitrate"/>
  </topic:var>
  <topic:var name="moles_of_nitrite_per_unit_mass_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Chemistry" VL1="Nutrients"/>
    <topic:param topic="Hydrosphere" term="Water Quality/Water Chemistry" VL1="Nutrients"/>
  </topic:var>
  <topic:var name="moles_of_oxygen_per_unit_mass_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Chemistry" VL1="Oxygen"/>
    <topic:param topic="Hydrosphere" term="Water Quality/Water Chemistry" VL1="Oxygen"/>
  </topic:var>
  <topic:var name="moles_of_phosphate_per_unit_mass_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Chemistry" VL1="Phosphate"/>
    <topic:param topic="Oceans" term="Ocean Chemistry" VL1="Nutrients"/>
    <topic:param topic="Hydrosphere" term="Water Quality/Water Chemistry" VL1="Nutrients"/>
  </topic:var>
  <topic:var name="moles_of_silicate_per_unit_mass_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Chemistry" VL1="Silicate"/>
    <topic:param topic="Oceans" term="Ocean Chemistry" VL1="Nutrients"/>
    <topic:param topic="Hydrosphere" term="Water Quality/Water Chemistry" VL1="Nutrients"/>
  </topic:var>
  <topic:var name="net_downward_longwave_flux_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Net Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="net_downward_longwave_flux_in_air_assuming_clear_sky">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Net Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="net_downward_radiative_flux_at_top_of_atmosphere_model">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Flux"/>
  </topic:var>
  <topic:var name="net_downward_shortwave_flux_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Net Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Flux"/>
  </topic:var>
  <topic:var name="net_downward_shortwave_flux_in_air_assuming_clear_sky">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Net Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Flux"/>
  </topic:var>
  <topic:var name="net_primary_productivity_of_carbon">
    <topic:param topic="Biosphere" term="Ecological Dynamics" VL1="Primary Production"/>
  </topic:var>
  <topic:var name="net_rate_of_absorption_of_longwave_energy_in_atmosphere_layer">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Absorption"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="net_rate_of_absorption_of_shortwave_energy_in_atmosphere_layer">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Absorption"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
  </topic:var>
  <topic:var name="net_upward_longwave_flux_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Net Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Outgoing Longwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="net_upward_longwave_flux_in_air_assuming_clear_sky">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Net Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Outgoing Longwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="net_upward_shortwave_flux_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Net Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Flux"/>
  </topic:var>
  <topic:var name="net_upward_shortwave_flux_in_air_assuming_clear_sky">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Net Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Flux"/>
  </topic:var>
  <topic:var name="normalized_difference_vegetation_index">
    <topic:param topic="Biosphere" term="Vegetation" VL1="Vegetation Index"/>
  </topic:var>
  <topic:var name="northward_ocean_freshwater_transport">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Fresh Water Flux"/>
  </topic:var>
  <topic:var name="northward_ocean_freshwater_transport_due_to_bolus_advection">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Fresh Water Flux"/>
  </topic:var>
  <topic:var name="northward_ocean_freshwater_transport_due_to_diffusion">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Fresh Water Flux"/>
  </topic:var>
  <topic:var name="northward_ocean_freshwater_transport_due_to_gyre">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Fresh Water Flux"/>
  </topic:var>
  <topic:var name="northward_ocean_freshwater_transport_due_to_overturning">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Fresh Water Flux"/>
  </topic:var>
  <topic:var name="northward_ocean_heat_transport">
    <topic:param topic="Oceans" term="Ocean Heat Budget" VL1="Heat Flux"/>
  </topic:var>
  <topic:var name="northward_ocean_heat_transport_due_to_bolus_advection">
    <topic:param topic="Oceans" term="Ocean Heat Budget" VL1="Heat Flux"/>
  </topic:var>
  <topic:var name="northward_ocean_heat_transport_due_to_diffusion">
    <topic:param topic="Oceans" term="Ocean Heat Budget" VL1="Heat Flux"/>
  </topic:var>
  <topic:var name="northward_ocean_heat_transport_due_to_gyre">
    <topic:param topic="Oceans" term="Ocean Heat Budget" VL1="Heat Flux"/>
  </topic:var>
  <topic:var name="northward_ocean_heat_transport_due_to_overturning">
    <topic:param topic="Oceans" term="Ocean Heat Budget" VL1="Heat Flux"/>
  </topic:var>
  <topic:var name="northward_ocean_salt_transport">
    <topic:param topic="Oceans" term="Salinity/Density" VL1="Salt Transport"/>
  </topic:var>
  <topic:var name="northward_ocean_salt_transport_due_to_bolus_advection">
    <topic:param topic="Oceans" term="Salinity/Density" VL1="Salt Transport"/>
  </topic:var>
  <topic:var name="northward_ocean_salt_transport_due_to_diffusion">
    <topic:param topic="Oceans" term="Salinity/Density" VL1="Salt Transport"/>
  </topic:var>
  <topic:var name="northward_ocean_salt_transport_due_to_gyre">
    <topic:param topic="Oceans" term="Salinity/Density" VL1="Salt Transport"/>
  </topic:var>
  <topic:var name="northward_ocean_salt_transport_due_to_overturning">
    <topic:param topic="Oceans" term="Salinity/Density" VL1="Salt Transport"/>
  </topic:var>
  <topic:var name="northward_sea_ice_velocity">
    <topic:param topic="Oceans" term="Sea Ice" VL1="Sea Ice Motion"/>
    <topic:param topic="Cryosphere" term="Sea Ice" VL1="Sea Ice Motion"/>
  </topic:var>
  <topic:var name="northward_sea_water_velocity">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Ocean Currents"/>
    <topic:param topic="Oceans" term="Tides" VL1="Tidal Currents"/>
  </topic:var>
  <topic:var name="northward_wind">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Surface Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Profiles"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Boundary Layer Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Upper Level Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Flight Level Winds"/>
    <topic:param topic="Oceans" term="Ocean Winds" VL1="Surface Winds"/>
  </topic:var>
  <topic:var name="northward_wind_shear">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Shear"/>
    <topic:param topic="Oceans" term="Ocean Winds" VL1="Wind Shear"/>
  </topic:var>
  <topic:var name="ocean_barotropic_streamfunction">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Ocean Currents"/>
  </topic:var>
  <topic:var name="ocean_integral_of_sea_water_temperature_wrt_depth">
    <topic:param topic="Oceans" term="Ocean Temperature" VL1="Water Temperature"/>
  </topic:var>
  <topic:var name="ocean_meridional_overturning_streamfunction">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Upwelling/Downwelling"/>
  </topic:var>
  <topic:var name="ocean_mixed_layer_thickness">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Ocean Mixed Layer"/>
    <topic:param topic="Oceans" term="Ocean Temperature" VL1="Ocean Mixed Layer"/>
  </topic:var>
  <topic:var name="ocean_mixed_layer_thickness_defined_by_mixing_scheme">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Ocean Mixed Layer"/>
    <topic:param topic="Oceans" term="Ocean Temperature" VL1="Ocean Mixed Layer"/>
  </topic:var>
  <topic:var name="ocean_mixed_layer_thickness_defined_by_sigma_t">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Ocean Mixed Layer"/>
    <topic:param topic="Oceans" term="Ocean Temperature" VL1="Ocean Mixed Layer"/>
  </topic:var>
  <topic:var name="ocean_mixed_layer_thickness_defined_by_sigma_theta">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Ocean Mixed Layer"/>
    <topic:param topic="Oceans" term="Ocean Temperature" VL1="Ocean Mixed Layer"/>
  </topic:var>
  <topic:var name="ocean_mixed_layer_thickness_defined_by_temperature">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Ocean Mixed Layer"/>
    <topic:param topic="Oceans" term="Ocean Temperature" VL1="Ocean Mixed Layer"/>
  </topic:var>
  <topic:var name="omega">
    <topic:param topic="Atmosphere" term="Atmospheric Pressure" VL1="Pressure Tendency"/>
  </topic:var>
  <topic:var name="omnidirectional_photosynthetic_spherical_irradiance_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Irradiance"/>
  </topic:var>
  <topic:var name="omnidirectional_spectral_spherical_irradiance_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Irradiance"/>
  </topic:var>
  <topic:var name="optical_thickness_of_atmosphere_layer_due_to_aerosol">
    <topic:param topic="Atmosphere" term="Aerosols" VL1="Aerosol Optical Depth/Thickness"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Optical Depth/Thickness"/>
  </topic:var>
  <topic:var name="planetary_albedo">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Albedo"/>
    <topic:param topic="Land Surface" term="Surface Radiative Properties" VL1="Albedo"/>
  </topic:var>
  <topic:var name="plant_respiration_carbon_flux">
    <topic:param topic="Biosphere" term="Ecological Dynamics" VL1="Respiration"/>
  </topic:var>
  <topic:var name="platform_orientation">
    <topic:param topic="Spectral/Engineering" term="Platform Characteristics" VL1="Attitude Characteristics"/>
  </topic:var>
  <topic:var name="platform_pitch_angle">
    <topic:param topic="Spectral/Engineering" term="Platform Characteristics" VL1="Attitude Characteristics"/>
  </topic:var>
  <topic:var name="platform_pitch_rate">
    <topic:param topic="Spectral/Engineering" term="Platform Characteristics" VL1="Attitude Characteristics"/>
  </topic:var>
  <topic:var name="platform_roll_angle">
    <topic:param topic="Spectral/Engineering" term="Platform Characteristics" VL1="Attitude Characteristics"/>
  </topic:var>
  <topic:var name="platform_roll_rate">
    <topic:param topic="Spectral/Engineering" term="Platform Characteristics" VL1="Attitude Characteristics"/>
  </topic:var>
  <topic:var name="platform_speed_wrt_air">
    <topic:param topic="Spectral/Engineering" term="Platform Characteristics" VL1="Airspeed/Ground Speed"/>
  </topic:var>
  <topic:var name="platform_speed_wrt_ground">
    <topic:param topic="Spectral/Engineering" term="Platform Characteristics" VL1="Airspeed/Ground Speed"/>
  </topic:var>
  <topic:var name="platform_yaw_angle">
    <topic:param topic="Spectral/Engineering" term="Platform Characteristics" VL1="Attitude Characteristics"/>
  </topic:var>
  <topic:var name="platform_yaw_rate">
    <topic:param topic="Spectral/Engineering" term="Platform Characteristics" VL1="Attitude Characteristics"/>
  </topic:var>
  <topic:var name="potential_vorticity_of_atmosphere_layer">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Vorticity"/>
    <topic:param topic="Oceans" term="Ocean Winds" VL1="Vorticity"/>
  </topic:var>
  <topic:var name="potential_vorticity_of_ocean_layer">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Vorticity"/>
  </topic:var>
  <topic:var name="precipitation_amount">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Precipitation Amount"/>
  </topic:var>
  <topic:var name="precipitation_flux">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Precipitation"/>
  </topic:var>
  <topic:var name="precipitation_flux_onto_canopy_where_land">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Precipitation Amount"/>
  </topic:var>
  <topic:var name="pseudo_equivalent_potential_temperature">
    <topic:param topic="Atmosphere" term="Atmospheric Temperature" VL1="Air Temperature"/>
    <topic:param topic="Oceans" term="Ocean Temperature" VL1="Water Temperature"/>
  </topic:var>
  <topic:var name="pseudo_equivalent_temperature">
    <topic:param topic="Atmosphere" term="Atmospheric Temperature" VL1="Air Temperature"/>
  </topic:var>
  <topic:var name="radial_velocity_of_scatterers_away_from_instrument">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Ocean Currents"/>
    <topic:param topic="Oceans" term="Tides" VL1="Tidal Currents"/>
  </topic:var>
  <topic:var name="rainfall_amount">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Precipitation Amount"/>
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Rain"/>
  </topic:var>
  <topic:var name="rainfall_flux">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Rain"/>
  </topic:var>
  <topic:var name="rainfall_rate">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Rain"/>
  </topic:var>
  <topic:var name="relative_humidity">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Humidity"/>
  </topic:var>
  <topic:var name="root_depth">
    <topic:param topic="Agriculture" term="Soils" VL1="Soil Rooting Depth"/>
    <topic:param topic="Land Surface" term="Soils" VL1="Soil Rooting Depth"/>
  </topic:var>
  <topic:var name="runoff_amount">
    <topic:param topic="Hydrosphere" term="Surface Water" VL1="Runoff"/>
  </topic:var>
  <topic:var name="runoff_amount_excluding_baseflow">
    <topic:param topic="Hydrosphere" term="Surface Water" VL1="Runoff"/>
  </topic:var>
  <topic:var name="runoff_flux">
    <topic:param topic="Hydrosphere" term="Surface Water" VL1="Runoff"/>
  </topic:var>
  <topic:var name="scattering_angle">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Scattering"/>
  </topic:var>
  <topic:var name="sea_floor_depth">
    <topic:param topic="Oceans" term="Bathymetry/Seafloor Topography" VL1="Water Depth"/>
    <topic:param topic="Hydrosphere" term="Surface Water" VL1="Water Depth"/>
  </topic:var>
  <topic:var name="sea_floor_depth_below_geoid">
    <topic:param topic="Oceans" term="Bathymetry/Seafloor Topography" VL1="Water Depth"/>
    <topic:param topic="Hydrosphere" term="Surface Water" VL1="Water Depth"/>
  </topic:var>
  <topic:var name="sea_floor_depth_below_sea_level">
    <topic:param topic="Oceans" term="Bathymetry/Seafloor Topography" VL1="Water Depth"/>
    <topic:param topic="Hydrosphere" term="Surface Water" VL1="Water Depth"/>
  </topic:var>
  <topic:var name="sea_ice_amount">
    <topic:param topic="Oceans" term="Sea Ice" VL1="Sea Ice Concentration"/>
    <topic:param topic="Cryosphere" term="Sea Ice" VL1="Sea Ice Concentration"/>
  </topic:var>
  <topic:var name="sea_ice_area">
    <topic:param topic="Oceans" term="Sea Ice" VL1="Ice Extent"/>
    <topic:param topic="Cryosphere" term="Sea Ice" VL1="Ice Extent"/>
  </topic:var>
  <topic:var name="sea_ice_area_fraction">
    <topic:param topic="Oceans" term="Sea Ice" VL1="Ice Extent"/>
    <topic:param topic="Cryosphere" term="Sea Ice" VL1="Ice Extent"/>
  </topic:var>
  <topic:var name="sea_ice_draft">
    <topic:param topic="Oceans" term="Sea Ice" VL1="Ice Depth/Thickness"/>
    <topic:param topic="Cryosphere" term="Sea Ice" VL1="Ice Depth/Thickness"/>
  </topic:var>
  <topic:var name="sea_ice_extent">
    <topic:param topic="Oceans" term="Sea Ice" VL1="Ice Extent"/>
    <topic:param topic="Cryosphere" term="Sea Ice" VL1="Ice Extent"/>
  </topic:var>
  <topic:var name="sea_ice_freeboard">
    <topic:param topic="Oceans" term="Sea Ice" VL1="Sea Ice Elevation"/>
    <topic:param topic="Cryosphere" term="Sea Ice" VL1="Sea Ice Elevation"/>
  </topic:var>
  <topic:var name="sea_ice_speed">
    <topic:param topic="Oceans" term="Sea Ice" VL1="Sea Ice Motion"/>
    <topic:param topic="Cryosphere" term="Sea Ice" VL1="Sea Ice Motion"/>
  </topic:var>
  <topic:var name="sea_ice_temperature">
    <topic:param topic="Oceans" term="Sea Ice" VL1="Ice Temperature"/>
    <topic:param topic="Cryosphere" term="Sea Ice" VL1="Ice Temperature"/>
  </topic:var>
  <topic:var name="sea_ice_thickness">
    <topic:param topic="Oceans" term="Sea Ice" VL1="Ice Depth/Thickness"/>
    <topic:param topic="Hydrosphere" term="Snow/Ice" VL1="Ice Depth/Thickness"/>
    <topic:param topic="Cryosphere" term="Sea Ice" VL1="Ice Depth/Thickness"/>
    <topic:param topic="Cryosphere" term="Snow/Ice" VL1="Ice Depth/Thickness"/>
  </topic:var>
  <topic:var name="sea_ice_transport_across_line">
    <topic:param topic="Oceans" term="Sea Ice" VL1="Sea Ice Motion"/>
    <topic:param topic="Cryosphere" term="Sea Ice" VL1="Sea Ice Motion"/>
  </topic:var>
  <topic:var name="sea_ice_x_velocity">
    <topic:param topic="Oceans" term="Sea Ice" VL1="Sea Ice Motion"/>
    <topic:param topic="Cryosphere" term="Sea Ice" VL1="Sea Ice Motion"/>
  </topic:var>
  <topic:var name="sea_ice_y_velocity">
    <topic:param topic="Oceans" term="Sea Ice" VL1="Sea Ice Motion"/>
    <topic:param topic="Cryosphere" term="Sea Ice" VL1="Sea Ice Motion"/>
  </topic:var>
  <topic:var name="sea_surface_elevation">
    <topic:param topic="Oceans" term="Sea Surface Topography" VL1="Sea Surface Height"/>
  </topic:var>
  <topic:var name="sea_surface_elevation_anomaly">
    <topic:param topic="Oceans" term="Coastal Processes" VL1="Sea Surface Height"/>
    <topic:param topic="Oceans" term="Coastal Processes" VL1="Tidal Height"/>
    <topic:param topic="Oceans" term="Sea Surface Topography" VL1="Sea Surface Height"/>
    <topic:param topic="Oceans" term="Tides" VL1="Tidal Height"/>
  </topic:var>
  <topic:var name="sea_surface_height">
    <topic:param topic="Oceans" term="Sea Surface Topography" VL1="Sea Surface Height"/>
  </topic:var>
  <topic:var name="sea_surface_height_above_geoid">
    <topic:param topic="Oceans" term="Sea Surface Topography" VL1="Sea Surface Height"/>
  </topic:var>
  <topic:var name="sea_surface_height_above_reference_ellipsoid">
    <topic:param topic="Oceans" term="Sea Surface Topography" VL1="Sea Surface Height"/>
  </topic:var>
  <topic:var name="sea_surface_height_above_sea_level">
    <topic:param topic="Oceans" term="Sea Surface Topography" VL1="Sea Surface Height"/>
  </topic:var>
  <topic:var name="sea_surface_salinity">
    <topic:param topic="Oceans" term="Salinity/Density" VL1="Salinity"/>
  </topic:var>
  <topic:var name="sea_surface_swell_wave_period">
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Swells"/>
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Wave Period"/>
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Sea State"/>
  </topic:var>
  <topic:var name="sea_surface_swell_wave_significant_height">
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Swells"/>
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Significant Wave Height"/>
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Sea State"/>
  </topic:var>
  <topic:var name="sea_surface_swell_wave_to_direction">
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Wave Speed/Direction"/>
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Swells"/>
  </topic:var>
  <topic:var name="sea_surface_swell_wave_zero_upcrossing_period">
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Swells"/>
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Wave Period"/>
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Sea State"/>
  </topic:var>
  <topic:var name="sea_surface_temperature">
    <topic:param topic="Oceans" term="Ocean Temperature" VL1="Sea Surface Temperature"/>
    <topic:param topic="Oceans" term="Ocean Temperature" VL1="Water Temperature"/>
  </topic:var>
  <topic:var name="sea_surface_wave_directional_variance_spectral_density">
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Wave Speed/Direction"/>
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Wave Spectra"/>
  </topic:var>
  <topic:var name="sea_surface_wave_frequency">
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Sea State"/>
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Wave Frequency"/>
  </topic:var>
  <topic:var name="sea_surface_wave_from_direction">
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Wave Speed/Direction"/>
  </topic:var>
  <topic:var name="sea_surface_wave_significant_height">
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Significant Wave Height"/>
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Sea State"/>
  </topic:var>
  <topic:var name="sea_surface_wave_to_direction">
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Wave Speed/Direction"/>
  </topic:var>
  <topic:var name="sea_surface_wave_variance_spectral_density">
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Wave Spectra"/>
  </topic:var>
  <topic:var name="sea_surface_wave_zero_upcrossing_period">
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Wave Period"/>
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Sea State"/>
  </topic:var>
  <topic:var name="sea_surface_wind_wave_period">
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Wave Period"/>
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Sea State"/>
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Wind Waves"/>
  </topic:var>
  <topic:var name="sea_surface_wind_wave_significant_height">
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Significant Wave Height"/>
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Sea State"/>
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Wind Waves"/>
  </topic:var>
  <topic:var name="sea_surface_wind_wave_to_direction">
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Wave Speed/Direction"/>
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Wind Waves"/>
  </topic:var>
  <topic:var name="sea_surface_wind_wave_zero_upcrossing_period">
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Sea State"/>
  </topic:var>
  <topic:var name="sea_water_density">
    <topic:param topic="Oceans" term="Salinity/Density" VL1="Density"/>
  </topic:var>
  <topic:var name="sea_water_electrical_conductivity">
    <topic:param topic="Oceans" term="Salinity/Density" VL1="Conductivity"/>
    <topic:param topic="Hydrosphere" term="Water Quality/Water Chemistry" VL1="Conductivity"/>
  </topic:var>
  <topic:var name="sea_water_potential_density">
    <topic:param topic="Oceans" term="Salinity/Density" VL1="Potential Density"/>
  </topic:var>
  <topic:var name="sea_water_potential_temperature">
    <topic:param topic="Oceans" term="Ocean Temperature" VL1="Water Temperature"/>
  </topic:var>
  <topic:var name="sea_water_pressure">
    <topic:param topic="Oceans" term="Ocean Pressure" VL1="Water Pressure"/>
    <topic:param topic="Hydrosphere" term="Surface Water" VL1="Water Pressure"/>
  </topic:var>
  <topic:var name="sea_water_salinity">
    <topic:param topic="Oceans" term="Salinity/Density" VL1="Salinity"/>
  </topic:var>
  <topic:var name="sea_water_sigma_t">
    <topic:param topic="Oceans" term="Salinity/Density" VL1="Density"/>
  </topic:var>
  <topic:var name="sea_water_sigma_theta">
    <topic:param topic="Oceans" term="Salinity/Density" VL1="Density"/>
  </topic:var>
  <topic:var name="sea_water_speed">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Ocean Currents"/>
    <topic:param topic="Oceans" term="Tides" VL1="Tidal Currents"/>
  </topic:var>
  <topic:var name="sea_water_temperature">
    <topic:param topic="Oceans" term="Ocean Temperature" VL1="Water Temperature"/>
  </topic:var>
  <topic:var name="sea_water_x_velocity">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Ocean Currents"/>
    <topic:param topic="Oceans" term="Tides" VL1="Tidal Currents"/>
  </topic:var>
  <topic:var name="sea_water_y_velocity">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Ocean Currents"/>
    <topic:param topic="Oceans" term="Tides" VL1="Tidal Currents"/>
  </topic:var>
  <topic:var name="shortwave_radiance">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
  </topic:var>
  <topic:var name="significant_height_of_swell_waves">
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Swells"/>
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Significant Wave Height"/>
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Sea State"/>
  </topic:var>
  <topic:var name="significant_height_of_wind_and_swell_waves">
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Swells"/>
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Significant Wave Height"/>
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Sea State"/>
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Wind Waves"/>
  </topic:var>
  <topic:var name="significant_height_of_wind_waves">
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Significant Wave Height"/>
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Sea State"/>
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Wind Waves"/>
  </topic:var>
  <topic:var name="snow_density">
    <topic:param topic="Hydrosphere" term="Snow/Ice" VL1="Snow Density"/>
    <topic:param topic="Cryosphere" term="Snow/Ice" VL1="Snow Density"/>
  </topic:var>
  <topic:var name="snow_temperature">
    <topic:param topic="Hydrosphere" term="Snow/Ice" VL1="Snow/Ice Temperature"/>
    <topic:param topic="Cryosphere" term="Snow/Ice" VL1="Snow/Ice Temperature"/>
  </topic:var>
  <topic:var name="snow_thermal_energy_content">
    <topic:param topic="Hydrosphere" term="Snow/Ice" VL1="Snow Energy Balance"/>
    <topic:param topic="Cryosphere" term="Snow/Ice" VL1="Snow Energy Balance"/>
  </topic:var>
  <topic:var name="snowfall_amount">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Precipitation Amount"/>
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Snow"/>
  </topic:var>
  <topic:var name="snowfall_flux">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Snow"/>
  </topic:var>
  <topic:var name="soil_albedo">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Albedo"/>
    <topic:param topic="Land Surface" term="Surface Radiative Properties" VL1="Albedo"/>
  </topic:var>
  <topic:var name="soil_carbon_content">
    <topic:param topic="Land Surface" term="Soils" VL1="Carbon"/>
  </topic:var>
  <topic:var name="soil_frozen_water_content">
    <topic:param topic="Land Surface" term="Soils" VL1="Soil Moisture/Water Content"/>
  </topic:var>
  <topic:var name="soil_hydraulic_conductivity_at_saturation">
    <topic:param topic="Land Surface" term="Soils" VL1="Hydraulic Conductivity"/>
  </topic:var>
  <topic:var name="soil_moisture_content">
    <topic:param topic="Land Surface" term="Soils" VL1="Soil Moisture/Water Content"/>
  </topic:var>
  <topic:var name="soil_moisture_content_at_field_capacity">
    <topic:param topic="Land Surface" term="Soils" VL1="Soil Moisture/Water Content"/>
  </topic:var>
  <topic:var name="soil_porosity">
    <topic:param topic="Land Surface" term="Soils" VL1="Soil Porosity"/>
  </topic:var>
  <topic:var name="soil_temperature">
    <topic:param topic="Agriculture" term="Soils" VL1="Soil Temperature"/>
    <topic:param topic="Land Surface" term="Soils" VL1="Soil Temperature"/>
  </topic:var>
  <topic:var name="soil_type">
    <topic:param topic="Land Surface" term="Soils" VL1="Soil Classification"/>
  </topic:var>
  <topic:var name="specific_humidity">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Humidity"/>
  </topic:var>
  <topic:var name="spectral_radiance">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Radiance"/>
  </topic:var>
  <topic:var name="speed_of_sound_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Acoustics" VL1="Acoustic Velocity"/>
  </topic:var>
  <topic:var name="square_of_air_temperature">
    <topic:param topic="Atmosphere" term="Atmospheric Temperature" VL1="Air Temperature"/>
  </topic:var>
  <topic:var name="square_of_eastward_wind">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Surface Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Profiles"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Boundary Layer Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Upper Level Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Flight Level Winds"/>
    <topic:param topic="Oceans" term="Ocean Winds" VL1="Surface Winds"/>
  </topic:var>
  <topic:var name="square_of_geopotential_height">
    <topic:param topic="Atmosphere" term="Altitude" VL1="Geopotential Height"/>
  </topic:var>
  <topic:var name="square_of_lagrangian_tendency_of_air_pressure">
    <topic:param topic="Atmosphere" term="Atmospheric Pressure" VL1="Pressure Tendency"/>
  </topic:var>
  <topic:var name="square_of_northward_wind">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Surface Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Profiles"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Boundary Layer Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Upper Level Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Flight Level Winds"/>
    <topic:param topic="Oceans" term="Ocean Winds" VL1="Surface Winds"/>
  </topic:var>
  <topic:var name="square_of_upward_air_velocity">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Vertical Wind Motion"/>
    <topic:param topic="Oceans" term="Ocean Winds" VL1="Vertical Wind Motion"/>
  </topic:var>
  <topic:var name="stratiform_cloud_area_fraction_in_atmosphere_layer">
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Amount/Frequency"/>
  </topic:var>
  <topic:var name="subsurface_runoff_amount">
    <topic:param topic="Hydrosphere" term="Surface Water" VL1="Runoff"/>
  </topic:var>
  <topic:var name="subsurface_runoff_flux">
    <topic:param topic="Hydrosphere" term="Surface Water" VL1="Runoff"/>
  </topic:var>
  <topic:var name="surface_air_pressure">
    <topic:param topic="Atmosphere" term="Atmospheric Pressure" VL1="Surface Pressure"/>
  </topic:var>
  <topic:var name="surface_albedo">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Albedo"/>
    <topic:param topic="Hydrosphere" term="Snow/Ice" VL1="Albedo"/>
    <topic:param topic="Land Surface" term="Surface Radiative Properties" VL1="Albedo"/>
    <topic:param topic="Cryosphere" term="Snow/Ice" VL1="Albedo"/>
  </topic:var>
  <topic:var name="surface_albedo_assuming_deep_snow">
    <topic:param topic="Hydrosphere" term="Snow/Ice" VL1="Albedo"/>
    <topic:param topic="Cryosphere" term="Snow/Ice" VL1="Albedo"/>
  </topic:var>
  <topic:var name="surface_albedo_assuming_no_snow">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Albedo"/>
    <topic:param topic="Land Surface" term="Surface Radiative Properties" VL1="Albedo"/>
  </topic:var>
  <topic:var name="surface_altitude">
    <topic:param topic="Atmosphere" term="Atmospheric Pressure" VL1="Planetary Boundary Layer Height"/>
  </topic:var>
  <topic:var name="surface_carbon_dioxide_mole_flux">
    <topic:param topic="Atmosphere" term="Atmospheric Chemistry/Carbon and Hydrocarbon Compounds" VL1="Carbon Dioxide"/>
    <topic:param topic="Oceans" term="Ocean Chemistry" VL1="Carbon Dioxide"/>
    <topic:param topic="Hydrosphere" term="Water Quality/Water Chemistry" VL1="Carbon Dioxide"/>
  </topic:var>
  <topic:var name="surface_carbon_dioxide_partial_pressure_difference_between_air_and_sea_water">
    <topic:param topic="Atmosphere" term="Atmospheric Chemistry/Carbon and Hydrocarbon Compounds" VL1="Carbon Dioxide"/>
    <topic:param topic="Oceans" term="Ocean Chemistry" VL1="Carbon Dioxide"/>
    <topic:param topic="Hydrosphere" term="Water Quality/Water Chemistry" VL1="Carbon Dioxide"/>
  </topic:var>
  <topic:var name="surface_diffuse_downwelling_photosynthetic_radiative_flux_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Flux"/>
    <topic:param topic="Biosphere" term="Vegetation" VL1="Photosynthetically Active Radiation"/>
  </topic:var>
  <topic:var name="surface_downward_eastward_stress">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Stress"/>
    <topic:param topic="Oceans" term="Ocean Winds" VL1="Wind Stress"/>
  </topic:var>
  <topic:var name="surface_downward_heat_flux_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Heat Flux"/>
  </topic:var>
  <topic:var name="surface_downward_heat_flux_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Heat Budget" VL1="Heat Flux"/>
  </topic:var>
  <topic:var name="surface_downward_latent_heat_flux">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Heat Flux"/>
  </topic:var>
  <topic:var name="surface_downward_northward_stress">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Stress"/>
    <topic:param topic="Oceans" term="Ocean Winds" VL1="Wind Stress"/>
  </topic:var>
  <topic:var name="surface_downward_sensible_heat_flux">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Heat Flux"/>
  </topic:var>
  <topic:var name="surface_downward_x_stress">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Stress"/>
    <topic:param topic="Oceans" term="Ocean Winds" VL1="Wind Stress"/>
  </topic:var>
  <topic:var name="surface_downward_y_stress">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Stress"/>
    <topic:param topic="Oceans" term="Ocean Winds" VL1="Wind Stress"/>
  </topic:var>
  <topic:var name="surface_downwelling_longwave_flux">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="surface_downwelling_longwave_flux_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="surface_downwelling_longwave_flux_in_air_assuming_clear_sky">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="surface_downwelling_photon_flux_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Irradiance"/>
  </topic:var>
  <topic:var name="surface_downwelling_photon_radiance_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Radiance"/>
  </topic:var>
  <topic:var name="surface_downwelling_photon_spherical_irradiance_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Irradiance"/>
  </topic:var>
  <topic:var name="surface_downwelling_photosynthetic_photon_flux_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Flux"/>
    <topic:param topic="Biosphere" term="Vegetation" VL1="Photosynthetically Active Radiation"/>
  </topic:var>
  <topic:var name="surface_downwelling_photosynthetic_photon_flux_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Irradiance"/>
  </topic:var>
  <topic:var name="surface_downwelling_photosynthetic_photon_radiance_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Radiance"/>
  </topic:var>
  <topic:var name="surface_downwelling_photosynthetic_photon_spherical_irradiance_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Irradiance"/>
  </topic:var>
  <topic:var name="surface_downwelling_photosynthetic_radiance_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Radiance"/>
  </topic:var>
  <topic:var name="surface_downwelling_photosynthetic_radiative_flux_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Flux"/>
    <topic:param topic="Biosphere" term="Vegetation" VL1="Photosynthetically Active Radiation"/>
  </topic:var>
  <topic:var name="surface_downwelling_photosynthetic_radiative_flux_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Irradiance"/>
  </topic:var>
  <topic:var name="surface_downwelling_photosynthetic_spherical_irradiance_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Irradiance"/>
  </topic:var>
  <topic:var name="surface_downwelling_radiance_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Radiance"/>
  </topic:var>
  <topic:var name="surface_downwelling_radiative_flux_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Irradiance"/>
  </topic:var>
  <topic:var name="surface_downwelling_shortwave_flux">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Flux"/>
  </topic:var>
  <topic:var name="surface_downwelling_shortwave_flux_assuming_clear_sky">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Flux"/>
  </topic:var>
  <topic:var name="surface_downwelling_shortwave_flux_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Flux"/>
  </topic:var>
  <topic:var name="surface_downwelling_shortwave_flux_in_air_assuming_clear_sky">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Flux"/>
  </topic:var>
  <topic:var name="surface_downwelling_spectral_photon_flux_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Irradiance"/>
  </topic:var>
  <topic:var name="surface_downwelling_spectral_photon_radiance_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Radiance"/>
  </topic:var>
  <topic:var name="surface_downwelling_spectral_photon_spherical_irradiance_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Irradiance"/>
  </topic:var>
  <topic:var name="surface_downwelling_spectral_radiance_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Radiance"/>
  </topic:var>
  <topic:var name="surface_downwelling_spectral_radiative_flux_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="surface_downwelling_spectral_radiative_flux_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Irradiance"/>
  </topic:var>
  <topic:var name="surface_downwelling_spectral_spherical_irradiance_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Irradiance"/>
  </topic:var>
  <topic:var name="surface_downwelling_spherical_irradiance_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Irradiance"/>
  </topic:var>
  <topic:var name="surface_eastward_geostrophic_sea_water_velocity">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Ocean Currents"/>
  </topic:var>
  <topic:var name="surface_eastward_geostrophic_sea_water_velocity_assuming_sea_level_for_geoid">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Ocean Currents"/>
  </topic:var>
  <topic:var name="surface_eastward_sea_water_velocity">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Ocean Currents"/>
    <topic:param topic="Oceans" term="Tides" VL1="Tidal Currents"/>
  </topic:var>
  <topic:var name="surface_geopotential">
    <topic:param topic="Atmosphere" term="Altitude" VL1="Geopotential Height"/>
  </topic:var>
  <topic:var name="surface_net_downward_longwave_flux">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Net Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="surface_net_downward_longwave_flux_assuming_clear_sky">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Net Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="surface_net_downward_radiative_flux_where_land">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Net Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="surface_net_downward_shortwave_flux">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Net Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Flux"/>
  </topic:var>
  <topic:var name="surface_net_downward_shortwave_flux_assuming_clear_sky">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Net Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Flux"/>
  </topic:var>
  <topic:var name="surface_net_upward_longwave_flux">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Net Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Outgoing Longwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="surface_net_upward_radiative_flux">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="surface_net_upward_shortwave_flux">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Net Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Flux"/>
  </topic:var>
  <topic:var name="surface_northward_geostrophic_sea_water_velocity">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Ocean Currents"/>
  </topic:var>
  <topic:var name="surface_northward_geostrophic_sea_water_velocity_assuming_sea_level_for_geoid">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Ocean Currents"/>
  </topic:var>
  <topic:var name="surface_northward_sea_water_velocity">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Ocean Currents"/>
    <topic:param topic="Oceans" term="Tides" VL1="Tidal Currents"/>
  </topic:var>
  <topic:var name="surface_partial_pressure_of_carbon_dioxide_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Chemistry/Carbon and Hydrocarbon Compounds" VL1="Carbon Dioxide"/>
  </topic:var>
  <topic:var name="surface_partial_pressure_of_carbon_dioxide_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Chemistry" VL1="Carbon Dioxide"/>
    <topic:param topic="Hydrosphere" term="Water Quality/Water Chemistry" VL1="Carbon Dioxide"/>
  </topic:var>
  <topic:var name="surface_roughness_length">
    <topic:param topic="Land Surface" term="Topography" VL1="Surface Roughness"/>
  </topic:var>
  <topic:var name="surface_roughness_length_for_heat_in_air">
    <topic:param topic="Land Surface" term="Topography" VL1="Surface Roughness"/>
  </topic:var>
  <topic:var name="surface_roughness_length_for_momentum_in_air">
    <topic:param topic="Land Surface" term="Topography" VL1="Surface Roughness"/>
  </topic:var>
  <topic:var name="surface_runoff_amount">
    <topic:param topic="Hydrosphere" term="Surface Water" VL1="Runoff"/>
  </topic:var>
  <topic:var name="surface_runoff_flux">
    <topic:param topic="Hydrosphere" term="Surface Water" VL1="Runoff"/>
  </topic:var>
  <topic:var name="surface_snow_melt_amount">
    <topic:param topic="Hydrosphere" term="Snow/Ice" VL1="Snow Melt"/>
    <topic:param topic="Cryosphere" term="Sea Ice" VL1="Snow Melt"/>
  </topic:var>
  <topic:var name="surface_snow_melt_and_sublimation_heat_flux">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Sublimation"/>
    <topic:param topic="Hydrosphere" term="Snow/Ice" VL1="Snow Melt"/>
    <topic:param topic="Cryosphere" term="Sea Ice" VL1="Snow Melt"/>
  </topic:var>
  <topic:var name="surface_snow_melt_flux">
    <topic:param topic="Hydrosphere" term="Snow/Ice" VL1="Snow Melt"/>
    <topic:param topic="Cryosphere" term="Sea Ice" VL1="Snow Melt"/>
  </topic:var>
  <topic:var name="surface_snow_melt_heat_flux">
    <topic:param topic="Cryosphere" term="Sea Ice" VL1="Snow Melt"/>
  </topic:var>
  <topic:var name="surface_snow_sublimation_amount">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Sublimation"/>
  </topic:var>
  <topic:var name="surface_snow_sublimation_heat_flux">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Sublimation"/>
  </topic:var>
  <topic:var name="surface_snow_thickness">
    <topic:param topic="Hydrosphere" term="Snow/Ice" VL1="Snow Depth"/>
    <topic:param topic="Cryosphere" term="Snow/Ice" VL1="Snow Depth"/>
  </topic:var>
  <topic:var name="surface_snow_thickness_where_sea_ice">
    <topic:param topic="Oceans" term="Sea Ice" VL1="Snow Depth"/>
    <topic:param topic="Cryosphere" term="Sea Ice" VL1="Snow Depth"/>
  </topic:var>
  <topic:var name="surface_specific_humidity">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Humidity"/>
  </topic:var>
  <topic:var name="surface_temperature">
    <topic:param topic="Atmosphere" term="Atmospheric Temperature" VL1="Surface Air Temperature"/>
  </topic:var>
  <topic:var name="surface_temperature_anomaly">
    <topic:param topic="Atmosphere" term="Atmospheric Temperature" VL1="Temperature Anomalies"/>
  </topic:var>
  <topic:var name="surface_temperature_where_land">
    <topic:param topic="Atmosphere" term="Atmospheric Temperature" VL1="Surface Air Temperature"/>
  </topic:var>
  <topic:var name="surface_temperature_where_open_sea">
    <topic:param topic="Atmosphere" term="Atmospheric Temperature" VL1="Surface Air Temperature"/>
  </topic:var>
  <topic:var name="surface_temperature_where_snow">
    <topic:param topic="Atmosphere" term="Atmospheric Temperature" VL1="Surface Air Temperature"/>
  </topic:var>
  <topic:var name="surface_upward_heat_flux_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Heat Flux"/>
  </topic:var>
  <topic:var name="surface_upward_latent_heat_flux">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Heat Flux"/>
  </topic:var>
  <topic:var name="surface_upward_sensible_heat_flux">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Heat Flux"/>
  </topic:var>
  <topic:var name="surface_upward_sensible_heat_flux_where_sea">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Heat Flux"/>
  </topic:var>
  <topic:var name="surface_upwelling_longwave_flux">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Outgoing Longwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="surface_upwelling_longwave_flux_assuming_clear_sky">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Outgoing Longwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="surface_upwelling_longwave_flux_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Outgoing Longwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="surface_upwelling_longwave_flux_in_air_assuming_clear_sky">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Outgoing Longwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="surface_upwelling_photosynthetic_photon_flux_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Flux"/>
    <topic:param topic="Biosphere" term="Vegetation" VL1="Photosynthetically Active Radiation"/>
  </topic:var>
  <topic:var name="surface_upwelling_radiance_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Atmospheric Emitted Radiation"/>
  </topic:var>
  <topic:var name="surface_upwelling_radiance_in_air_emerging_from_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Water-leaving Radiance"/>
  </topic:var>
  <topic:var name="surface_upwelling_radiance_in_air_reflected_by_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Reflectance"/>
  </topic:var>
  <topic:var name="surface_upwelling_radiance_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Radiance"/>
  </topic:var>
  <topic:var name="surface_upwelling_shortwave_flux">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Flux"/>
  </topic:var>
  <topic:var name="surface_upwelling_shortwave_flux_assuming_clear_sky">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Flux"/>
  </topic:var>
  <topic:var name="surface_upwelling_shortwave_flux_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Flux"/>
  </topic:var>
  <topic:var name="surface_upwelling_shortwave_flux_in_air_assuming_clear_sky">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Flux"/>
  </topic:var>
  <topic:var name="surface_upwelling_spectral_radiance_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Radiance"/>
  </topic:var>
  <topic:var name="surface_upwelling_spectral_radiative_flux_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Flux"/>
  </topic:var>
  <topic:var name="surface_upwelling_spectral_radiative_flux_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Irradiance"/>
  </topic:var>
  <topic:var name="surface_water_amount">
    <topic:param topic="Hydrosphere" term="Surface Water" VL1="Total Surface Water"/>
  </topic:var>
  <topic:var name="swell_wave_period">
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Swells"/>
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Wave Period"/>
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Sea State"/>
  </topic:var>
  <topic:var name="tendency_of_air_pressure">
    <topic:param topic="Atmosphere" term="Atmospheric Pressure" VL1="Pressure Tendency"/>
  </topic:var>
  <topic:var name="tendency_of_air_temperature">
    <topic:param topic="Atmosphere" term="Atmospheric Temperature" VL1="Temperature Tendency"/>
  </topic:var>
  <topic:var name="tendency_of_air_temperature_due_to_advection">
    <topic:param topic="Atmosphere" term="Atmospheric Temperature" VL1="Temperature Tendency"/>
  </topic:var>
  <topic:var name="tendency_of_air_temperature_due_to_diabatic_processes">
    <topic:param topic="Atmosphere" term="Atmospheric Temperature" VL1="Temperature Tendency"/>
  </topic:var>
  <topic:var name="tendency_of_air_temperature_due_to_diffusion">
    <topic:param topic="Atmosphere" term="Atmospheric Temperature" VL1="Temperature Tendency"/>
  </topic:var>
  <topic:var name="tendency_of_air_temperature_due_to_dry_convection">
    <topic:param topic="Atmosphere" term="Atmospheric Temperature" VL1="Temperature Tendency"/>
  </topic:var>
  <topic:var name="tendency_of_air_temperature_due_to_large_scale_precipitation">
    <topic:param topic="Atmosphere" term="Atmospheric Temperature" VL1="Temperature Tendency"/>
  </topic:var>
  <topic:var name="tendency_of_air_temperature_due_to_longwave_heating">
    <topic:param topic="Atmosphere" term="Atmospheric Temperature" VL1="Temperature Tendency"/>
  </topic:var>
  <topic:var name="tendency_of_air_temperature_due_to_longwave_heating_assuming_clear_sky">
    <topic:param topic="Atmosphere" term="Atmospheric Temperature" VL1="Temperature Tendency"/>
  </topic:var>
  <topic:var name="tendency_of_air_temperature_due_to_moist_convection">
    <topic:param topic="Atmosphere" term="Atmospheric Temperature" VL1="Temperature Tendency"/>
  </topic:var>
  <topic:var name="tendency_of_air_temperature_due_to_radiative_heating">
    <topic:param topic="Atmosphere" term="Atmospheric Temperature" VL1="Temperature Tendency"/>
  </topic:var>
  <topic:var name="tendency_of_air_temperature_due_to_shortwave_heating">
    <topic:param topic="Atmosphere" term="Atmospheric Temperature" VL1="Temperature Tendency"/>
  </topic:var>
  <topic:var name="tendency_of_air_temperature_due_to_shortwave_heating_assuming_clear_sky">
    <topic:param topic="Atmosphere" term="Atmospheric Temperature" VL1="Temperature Tendency"/>
  </topic:var>
  <topic:var name="tendency_of_air_temperature_due_to_turbulence">
    <topic:param topic="Atmosphere" term="Atmospheric Temperature" VL1="Temperature Tendency"/>
  </topic:var>
  <topic:var name="tendency_of_atmosphere_water_content_due_to_advection">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Humidity"/>
  </topic:var>
  <topic:var name="tendency_of_atmosphere_water_vapor_content">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Humidity"/>
  </topic:var>
  <topic:var name="tendency_of_atmosphere_water_vapor_content_due_to_advection">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Humidity"/>
  </topic:var>
  <topic:var name="tendency_of_atmosphere_water_vapor_content_due_to_convection">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Humidity"/>
  </topic:var>
  <topic:var name="tendency_of_atmosphere_water_vapor_content_due_to_deep_convection">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Humidity"/>
  </topic:var>
  <topic:var name="tendency_of_atmosphere_water_vapor_content_due_to_shallow_convection">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Humidity"/>
  </topic:var>
  <topic:var name="tendency_of_atmosphere_water_vapor_content_due_to_turbulence">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Humidity"/>
  </topic:var>
  <topic:var name="tendency_of_bedrock_altitude">
    <topic:param topic="Land Surface" term="Topography" VL1="Terrain Elevation"/>
  </topic:var>
  <topic:var name="tendency_of_eastward_wind">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Tendency"/>
  </topic:var>
  <topic:var name="tendency_of_eastward_wind_due_to_advection">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Tendency"/>
  </topic:var>
  <topic:var name="tendency_of_eastward_wind_due_to_convection">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Tendency"/>
  </topic:var>
  <topic:var name="tendency_of_eastward_wind_due_to_diffusion">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Tendency"/>
  </topic:var>
  <topic:var name="tendency_of_eastward_wind_due_to_gravity_wave_drag">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Tendency"/>
  </topic:var>
  <topic:var name="tendency_of_land_ice_thickness">
    <topic:param topic="Hydrosphere" term="Snow/Ice" VL1="Ice Depth/Thickness"/>
    <topic:param topic="Hydrosphere" term="Glaciers/Ice Sheets" VL1="Glacier Thickness/Ice Sheet Thickness"/>
    <topic:param topic="Cryosphere" term="Snow/Ice" VL1="Ice Depth/Thickness"/>
    <topic:param topic="Cryosphere" term="Glaciers/Ice Sheets" VL1="Glacier Thickness/Ice Sheet Thickness"/>
  </topic:var>
  <topic:var name="tendency_of_mass_fraction_of_cloud_condensed_water_in_air_due_to_advection">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Humidity"/>
  </topic:var>
  <topic:var name="tendency_of_mass_fraction_of_cloud_ice_in_air_due_to_advection">
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Liquid Water/Ice"/>
  </topic:var>
  <topic:var name="tendency_of_mass_fraction_of_cloud_ice_in_air_due_to_diffusion">
    <topic:param topic="Atmosphere" term="Clouds" VL1="Cloud Liquid Water/Ice"/>
  </topic:var>
  <topic:var name="tendency_of_mass_fraction_of_cloud_liquid_water_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Humidity"/>
  </topic:var>
  <topic:var name="tendency_of_mass_fraction_of_cloud_liquid_water_in_air_due_to_advection">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Humidity"/>
  </topic:var>
  <topic:var name="tendency_of_mass_fraction_of_cloud_liquid_water_in_air_due_to_diffusion">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Humidity"/>
  </topic:var>
  <topic:var name="tendency_of_northward_wind">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Tendency"/>
  </topic:var>
  <topic:var name="tendency_of_northward_wind_due_to_advection">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Tendency"/>
  </topic:var>
  <topic:var name="tendency_of_northward_wind_due_to_convection">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Tendency"/>
  </topic:var>
  <topic:var name="tendency_of_northward_wind_due_to_diffusion">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Tendency"/>
  </topic:var>
  <topic:var name="tendency_of_northward_wind_due_to_gravity_wave_drag">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Tendency"/>
  </topic:var>
  <topic:var name="tendency_of_ocean_barotropic_streamfunction">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Ocean Currents"/>
  </topic:var>
  <topic:var name="tendency_of_sea_ice_thickness_due_to_thermodynamics">
    <topic:param topic="Hydrosphere" term="Snow/Ice" VL1="Ice Growth/Melt"/>
    <topic:param topic="Cryosphere" term="Snow/Ice" VL1="Ice Growth/Melt"/>
  </topic:var>
  <topic:var name="tendency_of_specific_humidity">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Humidity"/>
  </topic:var>
  <topic:var name="tendency_of_specific_humidity_due_to_advection">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Humidity"/>
  </topic:var>
  <topic:var name="tendency_of_specific_humidity_due_to_convection">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Humidity"/>
  </topic:var>
  <topic:var name="tendency_of_specific_humidity_due_to_diffusion">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Humidity"/>
  </topic:var>
  <topic:var name="tendency_of_specific_humidity_due_to_model_physics">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Humidity"/>
  </topic:var>
  <topic:var name="tendency_of_surface_air_pressure">
    <topic:param topic="Atmosphere" term="Atmospheric Pressure" VL1="Pressure Tendency"/>
  </topic:var>
  <topic:var name="tendency_of_surface_snow_amount">
    <topic:param topic="Oceans" term="Sea Ice" VL1="Snow Melt"/>
    <topic:param topic="Cryosphere" term="Sea Ice" VL1="Snow Melt"/>
  </topic:var>
  <topic:var name="tendency_of_upward_air_velocity">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Vertical Wind Motion"/>
    <topic:param topic="Oceans" term="Ocean Winds" VL1="Vertical Wind Motion"/>
  </topic:var>
  <topic:var name="tendency_of_upward_air_velocity_due_to_advection">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Vertical Wind Motion"/>
    <topic:param topic="Oceans" term="Ocean Winds" VL1="Vertical Wind Motion"/>
  </topic:var>
  <topic:var name="tendency_of_water_vapor_content_of_atmosphere_layer">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Humidity"/>
  </topic:var>
  <topic:var name="tendency_of_water_vapor_content_of_atmosphere_layer_due_to_convection">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Humidity"/>
  </topic:var>
  <topic:var name="tendency_of_water_vapor_content_of_atmosphere_layer_due_to_deep_convection">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Humidity"/>
  </topic:var>
  <topic:var name="tendency_of_water_vapor_content_of_atmosphere_layer_due_to_shallow_convection">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Humidity"/>
  </topic:var>
  <topic:var name="tendency_of_water_vapor_content_of_atmosphere_layer_due_to_turbulence">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Humidity"/>
  </topic:var>
  <topic:var name="tendency_of_wind_speed_due_to_convection">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Tendency"/>
  </topic:var>
  <topic:var name="tendency_of_wind_speed_due_to_gravity_wave_drag">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Tendency"/>
  </topic:var>
  <topic:var name="thickness_of_convective_rainfall_amount">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Precipitation Amount"/>
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Rain"/>
  </topic:var>
  <topic:var name="thickness_of_convective_snowfall_amount">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Precipitation Amount"/>
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Snow"/>
  </topic:var>
  <topic:var name="thickness_of_large_scale_rainfall_amount">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Precipitation Amount"/>
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Rain"/>
  </topic:var>
  <topic:var name="thickness_of_large_scale_snowfall_amount">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Precipitation Amount"/>
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Snow"/>
  </topic:var>
  <topic:var name="thickness_of_rainfall_amount">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Precipitation Amount"/>
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Rain"/>
  </topic:var>
  <topic:var name="thickness_of_snowfall_amount">
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Precipitation Amount"/>
    <topic:param topic="Atmosphere" term="Precipitation" VL1="Snow"/>
  </topic:var>
  <topic:var name="thunderstorm_probability">
    <topic:param topic="Atmosphere" term="Atmospheric Phenomena" VL1="Storms"/>
  </topic:var>
  <topic:var name="toa_adjusted_longwave_forcing">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="toa_adjusted_radiative_forcing">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Forcing"/>
  </topic:var>
  <topic:var name="toa_adjusted_shortwave_forcing">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Forcing"/>
  </topic:var>
  <topic:var name="toa_incoming_shortwave_flux">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Incoming Solar Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Flux"/>
  </topic:var>
  <topic:var name="toa_instantaneous_longwave_forcing">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="toa_instantaneous_radiative_forcing">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Forcing"/>
  </topic:var>
  <topic:var name="toa_instantaneous_shortwave_forcing">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Forcing"/>
  </topic:var>
  <topic:var name="toa_net_downward_longwave_flux">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="toa_net_downward_radiative_flux">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Forcing"/>
  </topic:var>
  <topic:var name="toa_net_downward_shortwave_flux">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Flux"/>
  </topic:var>
  <topic:var name="toa_net_downward_shortwave_flux_assuming_clear_sky">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Flux"/>
  </topic:var>
  <topic:var name="toa_net_upward_longwave_flux">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Net Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Outgoing Longwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="toa_net_upward_longwave_flux_assuming_clear_sky">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Net Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Outgoing Longwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="toa_net_upward_shortwave_flux">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Flux"/>
  </topic:var>
  <topic:var name="toa_outgoing_longwave_flux">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Outgoing Longwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="toa_outgoing_longwave_flux_assuming_clear_sky">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Outgoing Longwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="toa_outgoing_shortwave_flux">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Flux"/>
  </topic:var>
  <topic:var name="toa_outgoing_shortwave_flux_assuming_clear_sky">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Flux"/>
  </topic:var>
  <topic:var name="transpiration_amount">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Evapotranspiration"/>
  </topic:var>
  <topic:var name="transpiration_flux">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Evapotranspiration"/>
  </topic:var>
  <topic:var name="tropopause_adjusted_longwave_forcing">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="tropopause_adjusted_radiative_forcing">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Forcing"/>
  </topic:var>
  <topic:var name="tropopause_adjusted_shortwave_forcing">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Forcing"/>
  </topic:var>
  <topic:var name="tropopause_air_pressure">
    <topic:param topic="Atmosphere" term="Atmospheric Pressure" VL1="Planetary Boundary Layer Height"/>
  </topic:var>
  <topic:var name="tropopause_air_temperature">
    <topic:param topic="Atmosphere" term="Atmospheric Temperature" VL1="Air Temperature"/>
  </topic:var>
  <topic:var name="tropopause_altitude">
    <topic:param topic="Atmosphere" term="Altitude" VL1="Tropopause"/>
  </topic:var>
  <topic:var name="tropopause_downwelling_longwave_flux">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="tropopause_instantaneous_longwave_forcing">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="tropopause_instantaneous_radiative_forcing">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Forcing"/>
  </topic:var>
  <topic:var name="tropopause_instantaneous_shortwave_forcing">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Forcing"/>
  </topic:var>
  <topic:var name="tropopause_net_downward_longwave_flux">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Net Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="tropopause_net_downward_shortwave_flux">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Solar Irradiance"/>
  </topic:var>
  <topic:var name="tropopause_upwelling_shortwave_flux">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Flux"/>
  </topic:var>
  <topic:var name="upward_air_velocity">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Vertical Wind Motion"/>
    <topic:param topic="Oceans" term="Ocean Winds" VL1="Vertical Wind Motion"/>
  </topic:var>
  <topic:var name="upward_air_velocity_expressed_as_tendency_of_sigma">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Vertical Wind Motion"/>
    <topic:param topic="Oceans" term="Ocean Winds" VL1="Vertical Wind Motion"/>
  </topic:var>
  <topic:var name="upward_heat_flux_at_ground_level_in_snow">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Heat Flux"/>
  </topic:var>
  <topic:var name="upward_heat_flux_at_ground_level_in_soil">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Heat Flux"/>
  </topic:var>
  <topic:var name="upward_heat_flux_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Heat Flux"/>
  </topic:var>
  <topic:var name="upward_sea_ice_basal_heat_flux">
    <topic:param topic="Oceans" term="Sea Ice" VL1="Heat Flux"/>
    <topic:param topic="Oceans" term="Ocean Heat Budget" VL1="Heat Flux"/>
    <topic:param topic="Cryosphere" term="Sea Ice" VL1="Heat Flux"/>
  </topic:var>
  <topic:var name="upward_sea_water_velocity">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Upwelling/Downwelling"/>
  </topic:var>
  <topic:var name="upwelling_longwave_flux_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Outgoing Longwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="upwelling_longwave_radiance_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Outgoing Longwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Longwave Radiation"/>
  </topic:var>
  <topic:var name="upwelling_shortwave_flux_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Flux"/>
  </topic:var>
  <topic:var name="upwelling_shortwave_radiance_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Shortwave Radiation"/>
  </topic:var>
  <topic:var name="upwelling_spectral_radiative_flux_in_air">
    <topic:param topic="Atmosphere" term="Atmospheric Radiation" VL1="Radiative Flux"/>
  </topic:var>
  <topic:var name="upwelling_spectral_radiative_flux_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Photosynthetically Active Radiation"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Irradiance"/>
  </topic:var>
  <topic:var name="vegetation_area_fraction">
    <topic:param topic="Biosphere" term="Vegetation" VL1="Vegetation Cover"/>
  </topic:var>
  <topic:var name="vegetation_carbon_content">
    <topic:param topic="Biosphere" term="Vegetation" VL1="Carbon"/>
  </topic:var>
  <topic:var name="vertical_air_velocity_expressed_as_tendency_of_pressure">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Vertical Wind Motion"/>
    <topic:param topic="Oceans" term="Ocean Winds" VL1="Vertical Wind Motion"/>
  </topic:var>
  <topic:var name="vertical_air_velocity_expressed_as_tendency_of_sigma">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Vertical Wind Motion"/>
    <topic:param topic="Oceans" term="Ocean Winds" VL1="Vertical Wind Motion"/>
  </topic:var>
  <topic:var name="virtual_temperature">
    <topic:param topic="Atmosphere" term="Atmospheric Temperature" VL1="Virtual Temperature"/>
  </topic:var>
  <topic:var name="visibility_in_air">
    <topic:param topic="Atmosphere" term="Air Quality" VL1="Visibility"/>
  </topic:var>
  <topic:var name="volume_absorption_coefficient_of_radiative_flux_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Absorption"/>
  </topic:var>
  <topic:var name="volume_absorption_coefficient_of_radiative_flux_in_sea_water_due_to_dissolved_organic_matter">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Absorption"/>
  </topic:var>
  <topic:var name="volume_attenuation_coefficient_of_downwelling_radiative_flux_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Absorption"/>
  </topic:var>
  <topic:var name="volume_backwards_scattering_coefficient_of_radiative_flux_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Scattering"/>
  </topic:var>
  <topic:var name="volume_beam_attenuation_coefficient_of_radiative_flux_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Extinction Coefficients"/>
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Attenuation/Transmission"/>
  </topic:var>
  <topic:var name="volume_fraction_of_clay_in_soil">
    <topic:param topic="Land Surface" term="Soils" VL1="Soil Consistence"/>
  </topic:var>
  <topic:var name="volume_fraction_of_frozen_water_in_soil">
    <topic:param topic="Land Surface" term="Soils" VL1="Soil Moisture/Water Content"/>
  </topic:var>
  <topic:var name="volume_fraction_of_sand_in_soil">
    <topic:param topic="Land Surface" term="Soils" VL1="Soil Consistence"/>
  </topic:var>
  <topic:var name="volume_fraction_of_silt_in_soil">
    <topic:param topic="Land Surface" term="Soils" VL1="Soil Consistence"/>
  </topic:var>
  <topic:var name="volume_fraction_of_water_in_soil">
    <topic:param topic="Land Surface" term="Soils" VL1="Soil Moisture/Water Content"/>
  </topic:var>
  <topic:var name="volume_fraction_of_water_in_soil_at_critical_point">
    <topic:param topic="Land Surface" term="Soils" VL1="Soil Moisture/Water Content"/>
  </topic:var>
  <topic:var name="volume_fraction_of_water_in_soil_at_field_capacity">
    <topic:param topic="Land Surface" term="Soils" VL1="Soil Moisture/Water Content"/>
  </topic:var>
  <topic:var name="volume_fraction_of_water_in_soil_at_wilting_point">
    <topic:param topic="Land Surface" term="Soils" VL1="Soil Moisture/Water Content"/>
  </topic:var>
  <topic:var name="volume_mixing_ratio_of_oxygen_at_stp_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Chemistry" VL1="Oxygen"/>
    <topic:param topic="Hydrosphere" term="Water Quality/Water Chemistry" VL1="Oxygen"/>
  </topic:var>
  <topic:var name="volume_scattering_coefficient_of_radiative_flux_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Scattering"/>
  </topic:var>
  <topic:var name="volume_scattering_function_of_radiative_flux_in_sea_water">
    <topic:param topic="Oceans" term="Ocean Optics" VL1="Scattering"/>
  </topic:var>
  <topic:var name="water_content_of_atmosphere_layer">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Humidity"/>
  </topic:var>
  <topic:var name="water_evaporation_amount">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Evaporation"/>
  </topic:var>
  <topic:var name="water_evaporation_amount_from_canopy">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Evaporation"/>
  </topic:var>
  <topic:var name="water_evaporation_amount_from_canopy_where_land">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Evaporation"/>
  </topic:var>
  <topic:var name="water_evaporation_flux">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Evaporation"/>
  </topic:var>
  <topic:var name="water_evaporation_flux_from_canopy">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Evaporation"/>
  </topic:var>
  <topic:var name="water_evaporation_flux_from_canopy_where_land">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Evaporation"/>
  </topic:var>
  <topic:var name="water_evaporation_flux_from_soil">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Evaporation"/>
  </topic:var>
  <topic:var name="water_evaporation_flux_where_sea_ice">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Evaporation"/>
  </topic:var>
  <topic:var name="water_flux_into_ocean">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Fresh Water Flux"/>
  </topic:var>
  <topic:var name="water_flux_into_ocean_from_rivers">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Fresh Water Flux"/>
  </topic:var>
  <topic:var name="water_potential_evaporation_amount">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Evaporation"/>
  </topic:var>
  <topic:var name="water_potential_evaporation_flux">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Evaporation"/>
  </topic:var>
  <topic:var name="water_sublimation_flux">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Sublimation"/>
  </topic:var>
  <topic:var name="water_vapor_content_of_atmosphere_layer">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Humidity"/>
  </topic:var>
  <topic:var name="water_vapor_pressure">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Humidity"/>
  </topic:var>
  <topic:var name="water_vapor_saturation_deficit">
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Humidity"/>
  </topic:var>
  <topic:var name="water_volume_transport_into_ocean_from_rivers">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Fresh Water Flux"/>
  </topic:var>
  <topic:var name="wet_bulb_temperature">
    <topic:param topic="Atmosphere" term="Atmospheric Temperature" VL1="Air Temperature"/>
    <topic:param topic="Atmosphere" term="Atmospheric Water Vapor" VL1="Humidity"/>
  </topic:var>
  <topic:var name="wind_from_direction">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Surface Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Profiles"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Boundary Layer Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Upper Level Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Flight Level Winds"/>
    <topic:param topic="Oceans" term="Ocean Winds" VL1="Surface Winds"/>
  </topic:var>
  <topic:var name="wind_speed">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Surface Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Profiles"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Boundary Layer Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Upper Level Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Flight Level Winds"/>
    <topic:param topic="Oceans" term="Ocean Winds" VL1="Surface Winds"/>
  </topic:var>
  <topic:var name="wind_speed_of_gust">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Surface Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Profiles"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Boundary Layer Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Upper Level Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Flight Level Winds"/>
    <topic:param topic="Oceans" term="Ocean Winds" VL1="Surface Winds"/>
  </topic:var>
  <topic:var name="wind_speed_shear">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Shear"/>
    <topic:param topic="Oceans" term="Ocean Winds" VL1="Wind Shear"/>
  </topic:var>
  <topic:var name="wind_to_direction">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Surface Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Profiles"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Boundary Layer Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Upper Level Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Flight Level Winds"/>
    <topic:param topic="Oceans" term="Ocean Winds" VL1="Surface Winds"/>
  </topic:var>
  <topic:var name="wind_wave_period">
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Wave Period"/>
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Sea State"/>
    <topic:param topic="Oceans" term="Ocean Waves" VL1="Wind Waves"/>
  </topic:var>
  <topic:var name="x_sea_water_velocity">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Ocean Currents"/>
    <topic:param topic="Oceans" term="Tides" VL1="Tidal Currents"/>
  </topic:var>
  <topic:var name="x_wind">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Surface Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Profiles"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Boundary Layer Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Upper Level Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Flight Level Winds"/>
    <topic:param topic="Oceans" term="Ocean Winds" VL1="Surface Winds"/>
  </topic:var>
  <topic:var name="y_sea_water_velocity">
    <topic:param topic="Oceans" term="Ocean Circulation" VL1="Ocean Currents"/>
    <topic:param topic="Oceans" term="Tides" VL1="Tidal Currents"/>
  </topic:var>
  <topic:var name="y_wind">
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Surface Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Wind Profiles"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Boundary Layer Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Upper Level Winds"/>
    <topic:param topic="Atmosphere" term="Atmospheric Winds" VL1="Flight Level Winds"/>
    <topic:param topic="Oceans" term="Ocean Winds" VL1="Surface Winds"/>
  </topic:var>

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
