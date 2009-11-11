<?xml version="1.0" encoding="ISO-8859-1"?>

<!--
    Document   : dataset.xsl
    Author     : heikok
    Description: representation of dataset.xmd in browsers
-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:d="http://www.met.no/schema/metamod/dataset"  version="1.0">
    <xsl:output method="html"/>

    <xsl:template match="/">
        <html>
            <head>
                <title><xsl:value-of select="/d:dataset/d:info/@name"/></title>
            </head>
            <body>
                <h1>Content of <xsl:value-of select="/d:dataset/d:info/@name"/></h1>
                <xsl:apply-templates select="/d:dataset/d:info" />
                <xsl:apply-templates select="/d:dataset/d:quadtree_nodes" />
            </body>
        </html>
    </xsl:template>

    <xsl:template match="d:info">
        <div title="Status">
        <table border="1">
            <tr><th>Name</th><th>Status</th><th>Creation-Date</th><th>Datestamp</th><th>Owner-Tag</th><th>Metadata-Format</th></tr>
            <tr><td><xsl:value-of select="@name"/></td><td><xsl:value-of select="@status"/></td><td><xsl:value-of select="@creationDate"/></td><td><xsl:value-of select="@datestamp"/></td><td><xsl:value-of select="@ownertag"/></td><td><xsl:value-of select="@metadataFormat"/></td></tr>
        </table>
        </div>
    </xsl:template>
    <xsl:template match="d:quadtree_nodes">
        <div name="quadtree">
        <b>Quadtree-nodes available:</b>
        <quote><xsl:value-of select="."/></quote>
        </div>
    </xsl:template>
</xsl:stylesheet>
