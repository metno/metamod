<?xml version="1.0" encoding="ISO-8859-1"?>

<!--
    Document   : MM2.xsl
    Author     : heikok
    Description: representation of MM2.xml files in browser
-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:d="http://www.met.no/schema/metamod/MM2"  version="1.0">
    <xsl:output method="html"/>

    <!-- TODO customize transformation rules 
         syntax recommendation http://www.w3.org/TR/xslt 
    -->
    <xsl:template match="/">
        <html>
            <head>
                <title>MM2 dataset contents</title>
            </head>
            <body>
                <h1>Content of MM2 dataset</h1>
                <table>
                <xsl:apply-templates select="/d:MM2/d:metadata">
                    <xsl:sort select="@name"/>
                </xsl:apply-templates>
                </table>
            </body>
        </html>
    </xsl:template>

    <xsl:template match="d:metadata">
        <tr><th><xsl:value-of select="@name"/></th><td><xsl:value-of select="."/></td></tr>
    </xsl:template>
</xsl:stylesheet>
