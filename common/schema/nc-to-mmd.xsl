<?xml version="1.0" encoding="UTF-8"?>

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:nc="http://www.unidata.ucar.edu/namespaces/netcdf/ncml-2.2"
                xmlns="http://www.met.no/schema/mm3"
                version="1.0">

  <xsl:output method="xml" indent="yes"/>

  <xsl:template match="/nc:netcdf">
    <xsl:element name="MM3">
      <xsl:apply-templates select="nc:attribute[@name='title']"/>
      <xsl:apply-templates select="nc:attribute[@name='abstract']"/>
      <!-- ... -->
    </xsl:element>
  </xsl:template>

  <xsl:template match="nc:attribute">
    <xsl:element name="{@name}">
      <xsl:attribute name="xml:lang">en_GB</xsl:attribute>
      <xsl:value-of select="@value" />
    </xsl:element>
  </xsl:template>

</xsl:stylesheet>
