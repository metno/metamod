<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	version="1.0" xmlns:mm="http://www.met.no/schema/metamod/MM2"
	xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.openarchives.org/OAI/2.0/oai_dc/"
	xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/" xmlns:dc="http://purl.org/dc/elements/1.1/"
	xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/oai_dc/ http://www.openarchives.org/OAI/2.0/oai_dc.xsd"
	exclude-result-prefixes="mm xsi">

	<xsl:output encoding="UTF-8" indent="yes" />
    <xsl:key name="mm2" match="/*/mm:metadata" use="@name"/>
	<xsl:template match="/">
		<oai_dc:dc xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/oai_dc/ http://www.openarchives.org/OAI/2.0/oai_dc.xsd">

            <xsl:for-each select="/*/mm:metadata[@name = 'dataref']">
                <dc:identifier><xsl:value-of select="."/></dc:identifier>
            </xsl:for-each>

            <xsl:for-each select="/*/mm:metadata[@name = 'title']">
                <dc:title><xsl:value-of select="."/></dc:title>
            </xsl:for-each>

            <xsl:for-each select="/*/mm:metadata[@name = 'abstract']">
                <dc:description><xsl:value-of select="."/></dc:description>
            </xsl:for-each>

            <xsl:for-each select="/*/mm:metadata[@name = 'institution']">
                <dc:creator><xsl:value-of select="."/></dc:creator>
            </xsl:for-each>

            <dc:coverage>
                <xsl:value-of select="key('mm2', 'datacollection_period_from')"/> to <xsl:value-of select="key('mm2', 'datacollection_period_to')"/>
            </dc:coverage>

            <xsl:for-each select="/*/mm:metadata[@name = 'distribution_statement']">
                <dc:rights><xsl:value-of select="."/></dc:rights>
            </xsl:for-each>

            <xsl:for-each select="/*/mm:metadata[@name = 'area']">
                <dc:coverage><xsl:value-of select="."/></dc:coverage>
            </xsl:for-each>

            <xsl:for-each select="/*/mm:metadata[@name = 'topic']">
                <dc:subject><xsl:value-of select="."/></dc:subject>
            </xsl:for-each>

            <xsl:for-each select="/*/mm:metadata[@name = 'keyword']">
                <dc:subject><xsl:value-of select="."/></dc:subject>
            </xsl:for-each>

            <xsl:for-each select="/*/mm:metadata[@name = 'variable']">
                <dc:subject><xsl:value-of select="."/></dc:subject>
            </xsl:for-each>

            <xsl:for-each select="/*/mm:metadata[@name = 'topiccategory']">
                <dc:subject><xsl:value-of select="."/></dc:subject>
            </xsl:for-each>

		</oai_dc:dc>
	</xsl:template>
</xsl:stylesheet>