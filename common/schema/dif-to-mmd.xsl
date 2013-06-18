<?xml version="1.0" encoding="ISO-8859-1"?>

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
        xmlns:dif="http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/"
        xmlns:mm3="http://www.met.no/schema/mm3"
        version="1.0">
  <xsl:output method="xml" encoding="UTF-8" indent="yes"/>

  <xsl:template match="/dif:DIF">
    <xsl:element name="mm3:MM3">
      <xsl:apply-templates select="dif:Entry_Title" />
      <xsl:apply-templates select="dif:Parameters" />
      <xsl:apply-templates select="dif:Keyword" />
      <xsl:apply-templates select="dif:Temporal_Coverage/dif:Start_Date" />
      <xsl:apply-templates select="dif:Temporal_Coverage/dif:Stop_Date" />
      <!-- ... -->
    </xsl:element>
  </xsl:template>


  <xsl:template match="dif:Entry_ID">
  </xsl:template>


  <xsl:template match="dif:Entry_Title">
    <xsl:element name="mm3:title">
      <xsl:attribute name="xml:lang">en_GB</xsl:attribute>
      <xsl:value-of select="." />
    </xsl:element>
  </xsl:template>


  <xsl:template match="dif:Data_Set_Citation">
  </xsl:template>


  <xsl:template match="dif:Parameters">
    <xsl:element name="mm3:keyword">
      <xsl:attribute name="vocabulary">GCMD</xsl:attribute>
      <xsl:value-of select="dif:Topic"/> &gt; <xsl:value-of select="dif:Term" /><xsl:if test="dif:Variable_Level_1/*"> &gt; <xsl:value-of select="dif:Variable_Level_1" /></xsl:if><xsl:if test="dif:Variable_Level_2/*"> &gt; <xsl:value-of select="dif:Variable_Level_2" /></xsl:if><xsl:if test="dif:Variable_Level_3/*"> &gt; <xsl:value-of select="dif:Variable_Level_3" /></xsl:if>
    </xsl:element>
  </xsl:template>


  <xsl:template match="dif:ISO_Topic_Category">
  </xsl:template>


  <xsl:template match="dif:Keyword">
    <xsl:element name="mm3:keyword">
      <xsl:value-of select="." />
    </xsl:element>
  </xsl:template>


  <xsl:template match="dif:Temporal_Coverage/dif:Start_Date">
    <xsl:element name="mm3:datacollection_period_from">
      <xsl:value-of select="." />
    </xsl:element>
  </xsl:template>


  <xsl:template match="dif:Temporal_Coverage/dif:Stop_Date">
    <xsl:element name="mm3:datacollection_period_to">
      <xsl:value-of select="." />
    </xsl:element>
  </xsl:template>


	<xsl:template match="dif:Spatial_Coverage">
		<xsl:element name="mm3:bounding_box">
      <xsl:value-of select="dif:Easternmost_Longitude" />,<xsl:value-of select="dif:Southernmost_Latitude" />,<xsl:value-of select="dif:Westernmost_Longitude" />,<xsl:value-of select="dif:Northernmost_Latitude" />
    </xsl:element>
	</xsl:template>


  <xsl:template match="dif:Location">
  </xsl:template>

  <xsl:template match="dif:Data_Resolution/dif:Latitude_Resolution">
  </xsl:template>


  <xsl:template match="dif:Data_Resolution/dif:Longitude_Resolution">
  </xsl:template>


	<xsl:template match="dif:Project/dif:Short_Name">
	</xsl:template>

	<xsl:template match="dif:Project/dif:Long_Name">
	</xsl:template>


  <xsl:template match="dif:Access_Constraints">
  </xsl:template>


  <xsl:template match="dif:Originating_Center">
  </xsl:template>


  <xsl:template match="dif:Data_Center">
  </xsl:template>


  <xsl:template match="dif:Reference">
  </xsl:template>


  <xsl:template match="dif:Summary">
  </xsl:template>


  <xsl:template match="dif:Metadata_Name">
  </xsl:template>


  <xsl:template match="dif:Metadata_Version">
  </xsl:template>


  <xsl:template match="dif:Last_DIF_Revision_Date">
  </xsl:template>


  <xsl:template match="dif:Private">
  </xsl:template>

</xsl:stylesheet>
