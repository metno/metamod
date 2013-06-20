<?xml version="1.0" encoding="UTF-8"?>

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:mm2="http://www.met.no/schema/metamod/MM2"
    xmlns="http://www.met.no/schema/mmd"
    xmlns:mapping="http://www.met.no/schema/metamod/mm2mm3"
    xmlns:xmd="http://www.met.no/schema/metamod/dataset" version="1.0">

    <xsl:param name="xmd" />

    <xsl:output method="xml" indent="yes" />

    <xsl:template match="/mm2:MM2">
        <xsl:element name="mmd">
            <xsl:apply-templates select="*[@name='title']" />
            <xsl:apply-templates select="*[@name='abstract']" />
            <!--<xsl:apply-templates select="document($xmd)/xmd:dataset/xmd:info" />-->
            <xsl:apply-templates select="*[@name='dataref']" />
            <xsl:apply-templates select="*[@name='bounding_box']" />
            <xsl:apply-templates select="*[@name='topiccategory']" />

            <!-- assume only single contact -->
            <xsl:element name="personnel">
                <xsl:element name="role">Investigator</xsl:element>
                <xsl:element name="name">
                    <xsl:value-of select="mm2:metadata[@name='PI_name']" />
                </xsl:element>
                <xsl:element name="email">
                    <xsl:value-of select="mm2:metadata[@name='contact']" />
                </xsl:element>
                <xsl:element name="phone" />
                <xsl:element name="fax" />
                <xsl:element name="organisation">
                    <xsl:value-of select="mm2:metadata[@name='institution']" />
                </xsl:element>
            </xsl:element>

            <xsl:apply-templates select="*[@name='distribution_statement']" />

            <xsl:element name="temporal_extent">
                <xsl:element name="start_date">
                    <xsl:value-of select="substring(mm2:metadata[@name='datacollection_period_from'],1,10)" />
                </xsl:element>
                <xsl:element name="end_date">
                    <xsl:value-of select="substring(mm2:metadata[@name='datacollection_period_to'],1,10)" />
                </xsl:element>
            </xsl:element>

            <xsl:apply-templates select="*[@name='project_name']" />
            <xsl:apply-templates select="*[@name='Platform_name']" />

            <xsl:element name="keywords">
                <xsl:attribute name="vocabulary">none</xsl:attribute>

                <xsl:for-each select="mm2:metadata[@name='keywords']">
                    <xsl:element name="keyword">
                        <xsl:attribute name="vocabulary">none</xsl:attribute>
                        <xsl:value-of select="." />
                    </xsl:element>
                </xsl:for-each>
            </xsl:element>

            <xsl:element name="keywords">
                <xsl:attribute name="vocabulary">gcmd</xsl:attribute>

                <xsl:for-each
                    select="mm2:metadata[@name='variable' and contains(., '&gt;')]">
                    <xsl:variable name="value">  <!-- strip away HIDDEN suffix -->
                        <xsl:choose>
                            <xsl:when test="contains(., 'HIDDEN')">
                                <xsl:value-of select="substring-before(., ' &gt; HIDDEN')" />
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:value-of select="." />
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:variable>
                    <xsl:element name="keyword">
                        <xsl:value-of select="$value" />
                    </xsl:element>
                </xsl:for-each>
            </xsl:element>

            <xsl:element name="keywords">
                <xsl:attribute name="vocabulary">cf</xsl:attribute>
                <xsl:for-each
                    select="mm2:metadata[@name='variable' and not(contains(., '&gt;'))]">
                    <xsl:element name="keyword">
                        <xsl:value-of select="." />
                    </xsl:element>
                </xsl:for-each>
            </xsl:element>


<!--            <xsl:element name="system_metadata">
                <xsl:attribute name="for">metamod</xsl:attribute>
                <xsl:copy-of select="document($xmd)/*" />
            </xsl:element>-->


        </xsl:element>
    </xsl:template>


    <xsl:template match="xmd:dataset/xmd:info">
        <xsl:element name="last_metadata_update">
            <xsl:value-of select="@datestamp" />
        </xsl:element>
    </xsl:template>

    <xsl:template match="*[@name='distribution_statement']">
        <xsl:element name="access_constraint">
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>

    <xsl:template match="*[@name='topiccategory']">
        <xsl:element name="iso_topic_category">
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>

    <xsl:template match="*[@name='title']">
        <xsl:element name="title">
            <xsl:attribute name="xml:lang">en</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>

    <xsl:template match="*[@name='abstract']">
        <xsl:element name="abstract">
            <xsl:attribute name="xml:lang">en</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>


    <xsl:template match="*[@name='project_name']">
        <xsl:element name="project">
            <xsl:element name="short_name" />
            <xsl:element name="long_name">
                <xsl:value-of select="." />
            </xsl:element>
        </xsl:element>
    </xsl:template>

    <xsl:template match="*[@name='Platform_name']">
        <xsl:element name="platform">
            <xsl:element name="short_name" />
            <xsl:element name="long_name">
                <xsl:value-of select="." />
            </xsl:element>
        </xsl:element>
    </xsl:template>

    <xsl:template match="*[@name='dataref']">
        <xsl:element name="data_access">
            <xsl:element name="type">undefined</xsl:element>
            <xsl:element name="name" />
            <xsl:element name="resource">
                <xsl:value-of select="." />
            </xsl:element>
            <xsl:element name="description" />

        </xsl:element>
    </xsl:template>

    <xsl:template match="*[@name='bounding_box']">

        <!-- input format is ESWN, output format is SNWE -->
        <xsl:variable name="ESWN" select="." />
        <xsl:variable name="SWN" select="substring-after($ESWN, ',')" />
        <xsl:variable name="WN" select="substring-after($SWN, ',')" />
        <xsl:variable name="N" select="substring-after($WN, ',')" />

        <xsl:element name="geographic_extent">
            <xsl:element name="rectangle">
                <xsl:element name="north">
                    <xsl:value-of select="$N" />
                </xsl:element>
                <xsl:element name="south">
                    <xsl:value-of select="substring-before($SWN, ',')" />
                </xsl:element>
                <xsl:element name="west">
                    <xsl:value-of select="substring-before($WN, ',')" />
                </xsl:element>
                <xsl:element name="east">
                    <xsl:value-of select="substring-before($ESWN, ',')" />
                </xsl:element>
            </xsl:element>
        </xsl:element>
    </xsl:template>

</xsl:stylesheet>
