<?xml version="1.0" encoding="ISO-8859-1"?>

<!--
    Document   : dataset2View.xsl
    Created on : October 22, 2008, 11:41 AM
    Author     : heikok
    Description:
        Purpose of transformation follows.
-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:d="http://www.met.no/schema/metamod/dataset2/"  version="1.0">
    <xsl:output method="html"/>

    <!-- TODO customize transformation rules 
         syntax recommendation http://www.w3.org/TR/xslt 
    -->
    <xsl:template match="/">
        <html>
            <head>
                <title><xsl:value-of select="/d:dataset/d:info/@drpath"/></title>
            </head>
            <body>
                <h1>Content of <xsl:value-of select="/d:dataset/d:info/@drpath"/></h1>
                <xsl:apply-templates select="/d:dataset/d:info" />
                <xsl:apply-templates select="/d:dataset/d:datacollection_period" />
                <xsl:apply-templates select="/d:dataset/d:quadtree_nodes" />
                <div><table>
                <xsl:apply-templates select="/d:dataset/d:metadata">
                    <xsl:sort select="@name"/>
                </xsl:apply-templates>
                </table></div>
            </body>
        </html>
    </xsl:template>

    <xsl:template match="d:info">
        <div title="Status">
        <table>
            <tr><th>Status</th><th>Creation-Date</th><th>Owner-Tag</th><th>DrPath</th></tr>
            <tr><td><xsl:value-of select="@status"/></td><td><xsl:value-of select="@creationDate"/></td><td><xsl:value-of select="@ownertag"/></td><td><xsl:value-of select="@drpath"/></td></tr>
        </table>
        </div>
    </xsl:template>
    <xsl:template match="d:datacollection_period">
        <div name="period">
        <table>
            <tr><th>Period Start</th><td><xsl:value-of select="@from"/></td></tr>
            <tr><th>Period End</th><td><xsl:value-of select="@to"/></td></tr>
        </table>
        </div>
    </xsl:template>    
    <xsl:template match="d:quadtree_nodes">
        <div name="quadtree">
        <b>Quadtree-nodes available</b>
        </div>
    </xsl:template>
    <xsl:template match="d:metadata">
        <tr><th><xsl:value-of select="@name"/></th><td><xsl:value-of select="."/></td></tr>
    </xsl:template>


</xsl:stylesheet>
