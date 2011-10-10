<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
                xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                xmlns:skos="http://www.w3.org/2004/02/skos/core#"
                xmlns:dc="http://purl.org/dc/elements/1.1/"
                xmlns:gcmd="http://vocab.ndg.nerc.ac.uk/list/P041/current"
                xmlns:nc="http://vocab.ndg.nerc.ac.uk/list/P071/current"
                xmlns:nco="http://vocab.ndg.nerc.ac.uk/list/P072/current"
                xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">

    <xsl:output indent="yes" />
    <xsl:variable name="nc" select="document('P071_cf.xml')"/>
    <xsl:variable name="nc2" select="document('P072_cf.xml')"/>
    <xsl:variable name="lc" select="'abcdefghijklmnopqrstuvwxyz'"/>
    <xsl:variable name="uc" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ'"/>

    <!--<xsl:key name="nc_conc" match="skos:Concept" use="@rdf:about"/>--> <!-- doesn't work... -->

    <xsl:template match="/">
        <gcmd:variables>
            <!--<xsl:apply-templates match="document('P071_cf.xml')/*/skos:Concept"/>-->
            <xsl:apply-templates match="/*/skos:Concept"/>
        </gcmd:variables>
    </xsl:template>

    <xsl:template match="/*/skos:Concept">
        <xsl:variable name="label" select="substring-after(skos:prefLabel, 'EARTH SCIENCE &gt; ')"/>
        <gcmd:variable>
            <xsl:attribute name="label">
                <xsl:value-of select="$label"/>
            </xsl:attribute>

            <xsl:variable name="body"    select="translate(skos:prefLabel, $lc, $uc)"/>
            <gcmd:category><xsl:value-of select="substring-before($body, ' &gt; ')"/></gcmd:category>
            <xsl:variable name="tail"    select="substring-after ($body, ' &gt; ')"/>
            <gcmd:topic><xsl:value-of    select="substring-before($tail, ' &gt; ')"/></gcmd:topic>
            <xsl:variable name="tailer"  select="substring-after ($tail, ' &gt; ')"/>
            <xsl:choose>
                <xsl:when test="contains($tailer, ' &gt; ')">
                    <gcmd:term><xsl:value-of     select="substring-before($tailer, ' &gt; ')"/></gcmd:term>
                    <xsl:variable name="tailest" select="substring-after ($tailer, ' &gt; ')"/>
                    <gcmd:VL1><xsl:value-of      select="$tailest"/></gcmd:VL1>
                </xsl:when>
                <xsl:otherwise>
                    <gcmd:term><xsl:value-of     select="$tailer"/></gcmd:term>
                </xsl:otherwise>
            </xsl:choose>

            <xsl:for-each select="skos:narrowMatch | skos:exactMatch | skos:broadMatch">
                <xsl:variable name="ncuri" select="@rdf:resource"/>
                <xsl:choose>
                    <xsl:when test="starts-with($ncuri, 'http://vocab.ndg.nerc.ac.uk/term/P071/')">
                        <xsl:element name="nc:standard_name" namespace="http://vocab.ndg.nerc.ac.uk/list/P071/current">
                            <!--<xsl:value-of select="key('nc_conc', $ncuri)/skos:prefLabel"/>-->
                            <xsl:value-of select="$nc/*/skos:Concept[@rdf:about = $ncuri]/skos:prefLabel"/>
                        </xsl:element>
                    </xsl:when>
                    <xsl:when test="starts-with($ncuri, 'http://vocab.ndg.nerc.ac.uk/term/P072/')">
                        <xsl:element name="nco:obsolete_standard_name" namespace="http://vocab.ndg.nerc.ac.uk/list/P072/current">
                            <xsl:value-of select="$nc2/*/skos:Concept[@rdf:about = $ncuri]/skos:prefLabel"/>
                        </xsl:element>
                    </xsl:when>
                </xsl:choose>
            </xsl:for-each>

            <xsl:for-each select="document('')/*/gcmd:variable[@label = $label]">
                <xsl:comment>custom mapping</xsl:comment>
                <nc:standard_name><xsl:value-of select="nc:standard_name"/></nc:standard_name>
            </xsl:for-each>

        </gcmd:variable>
    </xsl:template>


    <gcmd:variable label="Atmosphere &gt; Atmospheric Water Vapor &gt; Water Vapor">
        <nc:standard_name>atmosphere_water_content</nc:standard_name>
    </gcmd:variable>
    <gcmd:variable label="Atmosphere &gt; Atmospheric Water Vapor &gt; Humidity">
        <nc:standard_name>tendency_of_atmosphere_water_vapor_content_due_to_advection</nc:standard_name>
    </gcmd:variable>
    <gcmd:variable label="Cryosphere &gt; Sea Ice &gt; Ice Edges">
        <nc:standard_name>ice_edge</nc:standard_name>
    </gcmd:variable>
    <gcmd:variable label="Oceans &gt; Sea Ice &gt; Ice Edges">
        <nc:standard_name>ice_edge</nc:standard_name>
    </gcmd:variable>
    <gcmd:variable label="Cryosphere &gt; Sea Ice &gt; Sea Ice Concentration">
        <nc:standard_name>ice_concentration</nc:standard_name>
    </gcmd:variable>
    <gcmd:variable label="Oceans &gt; Sea Ice &gt; Sea Ice Concentration">
        <nc:standard_name>ice_concentration</nc:standard_name>
    </gcmd:variable>
    <gcmd:variable label="Cryosphere &gt; Sea Ice &gt; Ice Types">
        <nc:standard_name>ice_type</nc:standard_name>
    </gcmd:variable>
    <gcmd:variable label="Oceans &gt; Sea Ice &gt; Ice Types">
        <nc:standard_name>ice_type</nc:standard_name>
    </gcmd:variable>


</xsl:stylesheet>
