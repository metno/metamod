<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:dap="http://xml.opendap.org/ns/DAP2"
>

  <xsl:output method="html"/>

  <xsl:param name="n"/>
  <xsl:param name="s"/>
  <xsl:param name="e"/>
  <xsl:param name="w"/>

  <xsl:template match="/*">

    <xsl:apply-templates select="dap:Attribute[@ name='NC_GLOBAL']"/>

    <h2>Variables</h2>
    <table class="dapform">
      <tr>
        <th>Download</th>
        <th>Name</th>
        <th>Description</th>
        <th>Standard name</th>
        <th>Long name</th>
        <th>Units</th>
      </tr>
      <xsl:apply-templates select="dap:Array[not( dap:Attribute[@name='axis'] )]"/>
      <xsl:apply-templates select="dap:Grid"/>
    </table>

    <h2>Dimensions</h2>
    <table class="dapform">
      <tr>
        <th>Name</th>
        <th>Description</th>
        <th>Standard name</th>
        <th>Long name</th>
        <th>Units</th>
      </tr>
      <xsl:apply-templates select="dap:Array[dap:Attribute[@name='axis']]"/>
    </table>

  </xsl:template>


  <xsl:template match="dap:Attribute[@type='Container']">

    <h1><xsl:value-of select="dap:Attribute[@name='title']"/></h1>
    <p><xsl:value-of select="dap:Attribute[@name='abstract']"/></p>

    <h2>Selection</h2>
    <table class="dapform">
      <tr>
        <td class="label">Select region:</td>
        <td class="fields">
          <xsl:choose>
            <xsl:when test="$n">
              N: <input name="north" value="{$n}"/><br/>
              W: <input name="west"  value="{$w}"/>
              E: <input name="east"  value="{$e}"/><br/>
              S: <input name="south" value="{$s}"/>
            </xsl:when>
            <xsl:otherwise> <!--fallback to latlon which only works for WGS84-->
              N: <input name="north" value="{dap:Attribute[@name='northernmost_latitude']/dap:value}"/><br/>
              W: <input name="west"  value="{dap:Attribute[@name='westernmost_longitude']/dap:value}"/>
              E: <input name="east"  value="{dap:Attribute[@name='easternmost_longitude']/dap:value}"/><br/>
              S: <input name="south" value="{dap:Attribute[@name='southernmost_latitude']/dap:value}"/>
            </xsl:otherwise>
          </xsl:choose>
        </td>
      </tr>
      <tr>
        <td class="label">Select time range:</td>
        <td class="fields">
          <input name="start_date" id="start_date" value="{dap:Attribute[@name='start_date']/dap:value}"/> to
          <input name="stop_date"  id="stop_date"  value="{dap:Attribute[@name='stop_date']/dap:value}"/>
        </td>
      </tr>
    </table>

  </xsl:template>



  <xsl:template match="dap:Array|dap:Grid">

      <tr>
        <xsl:if test="not(dap:Attribute[@name='axis'])">
          <td class="fields"><input type="checkbox" name="variable" value="{@name}"/></td>
        </xsl:if>
        <td class="label"><xsl:value-of select="@name"/></td>
        <td><xsl:value-of select="dap:Attribute[@name='description']"/>&#160;</td>
        <td><xsl:value-of select="dap:Attribute[@name='standard_name']"/>&#160;</td>
        <td><xsl:value-of select="dap:Attribute[@name='long_name']"/>&#160;</td>
        <td><xsl:value-of select="dap:Attribute[@name='units']"/>&#160;</td>
      </tr>

  </xsl:template>

</xsl:stylesheet>
