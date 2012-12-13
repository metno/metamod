<?xml version="1.0" encoding="UTF-8"?>
<!--
  JIF (because AJAX was taken and PLUMBO is too long)

  XSLT post-processing stylesheet for cleaning up nodes, including but not limited to:
  * inserting default values where nodevalue is blank
  * removing nodes with blank values

  Copyright (C) 2010 met.no geira@met.no

  This file is part of METAMOD

  METAMOD is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  METAMOD is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with METAMOD; if not, write to the Free Software
  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 -->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
                xmlns:jif="http://www.met.no/schema/metamod/jif"
                exclude-result-prefixes="jif">

  <xsl:output encoding="UTF-8" indent="yes"/>
  <xsl:variable name="lc" select="'abcdefghijklmnopqrstuvwxyz'"/>
  <xsl:variable name="uc" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ'"/>

  <!-- ============================== -->
  <!-- = Handler for default values = -->
  <!-- ============================== -->
  <!-- insert attr value if element is empty -->
  <xsl:template match="@jif:default">
    <!--<xsl:message>+ <xsl:value-of select="position()"/>: @<xsl:value-of select="name()"/>="<xsl:value-of select="."/>"</xsl:message>-->
    <xsl:variable name="default" select="."/>
    <!--<xsl:attribute name="garfle"><xsl:value-of select="."/></xsl:attribute>-->
    <xsl:for-each select="..">
      <xsl:if test="not(node()[not(self::comment())])">
        <!--<xsl:message>@@@Default = <xsl:value-of select="$default"/></xsl:message>-->
        <xsl:value-of select="$default"/>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>

  <!-- ============================== -->
  <!-- = Handler for purge function = -->
  <!-- ============================== -->
  <!-- removes element if empty (does not work recursively... yet) -->
  <xsl:template match="*[@jif:purge and not(node()[not(self::comment())])]">
    <!--<xsl:message># <xsl:value-of select="position()"/>: <xsl:value-of select="name()"/>="<xsl:value-of select="text()"/>" {<xsl:value-of select="@jif:purge"/>}</xsl:message>-->
    <xsl:apply-templates select="*"/>
  </xsl:template>

  <!--<xsl:template match="*[@jif:purge]" priority="-1">-->
  <!--  <xsl:message>? <xsl:value-of select="position()"/>: <xsl:value-of select="name()"/>="<xsl:value-of select="text()"/>" {<xsl:value-of select="@jif:purge"/>}</xsl:message>-->
  <!--  <xsl:copy>-->
  <!--    <xsl:apply-templates select="@*[namespace-uri() != 'http://www.met.no/schema/metamod/jif']"/>-->
  <!--    <xsl:apply-templates select="@*[namespace-uri() = 'http://www.met.no/schema/metamod/jif']"/>-->
  <!--    <xsl:apply-templates select="*"/>-->
  <!--  </xsl:copy>-->
  <!--</xsl:template>-->

  <!-- other jif attributes are filtered out -->
  <xsl:template match="@*[namespace-uri() = 'http://www.met.no/schema/metamod/jif']" priority="-9">
    <!--<xsl:message># <xsl:value-of select="position()"/>: @<xsl:value-of select="name()"/>="<xsl:value-of select="normalize-space(.)"/>"</xsl:message>-->
  </xsl:template>

  <!-- ordinary attributes copied here -->
  <xsl:template match="@*[namespace-uri() != 'http://www.met.no/schema/metamod/jif']">
    <!--<xsl:message>~ <xsl:value-of select="position()"/>: @<xsl:value-of select="name()"/>="<xsl:value-of select="."/>"</xsl:message>-->
    <xsl:copy/>
  </xsl:template>

  <!-- all the other nodes are processed here -->
  <xsl:template match="//*" priority="-8">
    <!--<xsl:message>. <xsl:value-of select="position()"/>: <xsl:value-of select="name()"/>="<xsl:value-of select="normalize-space(text())"/>" {<xsl:value-of select="@jif:purge"/>}</xsl:message>-->
    <xsl:copy>
      <!-- must process non-jif attributes before starting to manipulate child nodes -->
      <xsl:apply-templates select="@*[namespace-uri() != 'http://www.met.no/schema/metamod/jif']"/>
      <xsl:apply-templates select="@*[namespace-uri() = 'http://www.met.no/schema/metamod/jif']"/>
      <xsl:apply-templates select="node()"/>
    </xsl:copy>
  </xsl:template>

  <!--  only text nodes? -->
  <xsl:template match="node()" priority="-9">
    <!--<xsl:message>% <xsl:value-of select="position()"/>: "<xsl:value-of select="normalize-space(.)"/>"</xsl:message>-->
    <xsl:copy/>
  </xsl:template>

</xsl:stylesheet>
