<?xml version="1.0" encoding="ISO-8859-1"?>

<!--
    Document   : dif2dataset.xsl
    Created on : November 12, 2008, 1:26 PM
    Author     : heikok
    Description:
        Purpose of transformation follows.
-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
xmlns:dif="http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/"
version="1.0">
    <xsl:output method="xml" encoding="UTF-8" indent="yes"/>

    <xsl:template match="/">
    	<xsl:processing-instruction name="xml-stylesheet">href="dataset.xsl" type="text/xsl"</xsl:processing-instruction>
        <xsl:apply-templates select="dif:DIF"/>
    </xsl:template>
<!-- TODO: DS_datestamp in database is XXX in info? -->
    <xsl:template match="dif:DIF">
        <xsl:element name="MM2" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="schemaLocation" namespace="http://www.w3.org/2001/XMLSchema-instance">http://www.met.no/schema/metamod/MM2 https://wiki.met.no/_media/metamod/mm2.xsd</xsl:attribute>
            <xsl:apply-templates select="*" />
        </xsl:element>    
    </xsl:template>
    
    
    <xsl:template match="*">
        <!-- Handling items not specified otherwise, just use full xpath (without /dif:Dif) as beginning -->
        <xsl:choose>
            <xsl:when test="count( child::* )"><!-- go down path --><xsl:apply-templates select="*" /></xsl:when>
            <xsl:otherwise>
                <xsl:comment>Unknown Element <xsl:value-of select="name()"/></xsl:comment>
                <!-- create full path-name upwards -->
                <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
                    <xsl:attribute name="name"><xsl:apply-templates select=".." mode="buildRecursivePath" />dif:<xsl:value-of select="name()"/></xsl:attribute>
                    <xsl:value-of select="." />
                </xsl:element>
            </xsl:otherwise>
        </xsl:choose>        
    </xsl:template>
    
    <xsl:template match="*" mode="buildRecursivePath">
        <xsl:if test="local-name() != 'DIF'"><xsl:apply-templates select=".." mode="buildRecursivePath" />dif:<xsl:value-of select="name()"/>/</xsl:if>
    </xsl:template>

    <xsl:template match="dif:Entry_ID"><!-- Ignore --></xsl:template>

    <xsl:template match="dif:Entry_Title">
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">title</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>


    <xsl:template match="dif:Data_Set_Citation/dif:Dataset_Creator">
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">PI_name</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>


    <xsl:template match="dif:Data_Set_Citation/dif:Dataset_Title">
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">title</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>


    <xsl:template match="dif:Data_Set_Citation/dif:Dataset_Publisher">
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">institution</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>


    <xsl:template match="dif:Data_Set_Citation/dif:Online_Resource">
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">dataref</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>

    <xsl:template match="dif:Parameters">
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">variable</xsl:attribute>
            <xsl:value-of select="dif:Category" /> &gt; <xsl:value-of select="dif:Topic" /> &gt; <xsl:value-of select="dif:Term" /><xsl:if test="dif:Variable_Level_1"> &gt;  <xsl:value-of select="dif:Variable_Level_1" /></xsl:if>
        </xsl:element>        
    </xsl:template>

    <xsl:template match="dif:Parameters/dif:Category">
        <!-- ignore, used by Parameters -->
    </xsl:template>


    <xsl:template match="dif:Parameters/dif:Topic">
        <!-- ignore, used by Parameters -->
    </xsl:template>


    <xsl:template match="dif:Parameters/dif:Term">
        <!-- ignore, used by Parameters -->
    </xsl:template>


    <xsl:template match="dif:Parameters/dif:Variable_Level_1">
        <!-- ignore, used by Parameters -->
    </xsl:template>


    <xsl:template match="dif:Parameters/dif:Detailed_Variable">
        <!-- Currently unsupported item in Metamod -->
        <xsl:comment>Unsupported element <xsl:value-of select="local-name()"/> in Metamod</xsl:comment>
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">dif:Parameters/dif:Detailed_Variable</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>


    <xsl:template match="dif:ISO_Topic_Category">
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">topiccategory</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>


    <xsl:template match="dif:Keyword">
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">keywords</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>


    <xsl:template match="dif:Temporal_Coverage/dif:Start_Date">
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">datacollection_period_from</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>


    <xsl:template match="dif:Temporal_Coverage/dif:Stop_Date">
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">datacollection_period_to</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>


    <xsl:template match="dif:Spatial_Coverage/dif:Southernmost_Latitude">
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">southernmost_latitude</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>


    <xsl:template match="dif:Spatial_Coverage/dif:Northernmost_Latitude">
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">northernmost_latitude</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>


    <xsl:template match="dif:Spatial_Coverage/dif:Westernmost_Longitude">
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">westernmost_longitude</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>


    <xsl:template match="dif:Spatial_Coverage/dif:Easternmost_Longitude">
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">easternmost_longitude</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>


    <xsl:template match="dif:Location">
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">area</xsl:attribute>
            <xsl:value-of select="dif:Location_Category"/><xsl:if test="dif:Location_Type"> &gt; <xsl:value-of select="dif:Location_Type" /></xsl:if><xsl:if test="dif:Location_Subregion1"> &gt; <xsl:value-of select="dif:Location_Subregion1" /></xsl:if><xsl:if test="dif:Location_Subregion2"> &gt; <xsl:value-of select="dif:Location_Subregion2" /></xsl:if><xsl:if test="dif:Location_Subregion3"> &gt; <xsl:value-of select="dif:Location_Subregion3" /></xsl:if><xsl:if test="dif:Variable_Level_1"> &gt; <xsl:value-of select="dif:Variable_Level_1" /></xsl:if><xsl:if test="dif:Detailed_Location"> &gt; <xsl:value-of select="Detailed_Location" /></xsl:if>
        </xsl:element>
    </xsl:template>

    <xsl:template match="dif:Location/dif:Location_Category">
        <!-- ignore, used by Location -->
    </xsl:template>


    <xsl:template match="dif:Location/dif:Location_Type">
        <!-- ignore, used by Location -->
    </xsl:template>


    <xsl:template match="dif:Location/dif:Location_Subregion2">
        <!-- ignore, used by Location -->
    </xsl:template>


    <xsl:template match="dif:Location/dif:Location_Subregion3">
        <!-- ignore, used by Location -->
    </xsl:template>


    <xsl:template match="dif:Location/dif:Detailed_Location">
        <!-- ignore, used by Location -->
    </xsl:template>


    <xsl:template match="dif:Data_Resolution/dif:Latitude_Resolution">
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">latitude_resolution 1</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>


    <xsl:template match="dif:Data_Resolution/dif:Longitude_Resolution">
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">longitude_resolution 1</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>


    <xsl:template match="dif:Project/dif:Short_Name">
        <!-- Currently unsupported item in Metamod -->
        <xsl:comment>Unsupported element <xsl:value-of select="local-name()"/> in Metamod</xsl:comment>
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">dif:Project/dif:Short_Name</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>


    <xsl:template match="dif:Access_Constraints">
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">distribution_statement</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>


    <xsl:template match="dif:Originating_Center">
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">institution</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>


    <xsl:template match="dif:Data_Center/dif:Data_Center_Name/dif:Short_Name">
        <!-- Currently unsupported item in Metamod -->
        <xsl:comment>Unsupported element <xsl:value-of select="local-name()"/> in Metamod</xsl:comment>
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">dif:Data_Center/dif:Data_Center_Name/dif:Short_Name</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>


    <xsl:template match="dif:Data_Center/dif:Data_Center_Name/dif:Long_Name">
        <!-- Currently unsupported item in Metamod -->
        <xsl:comment>Unsupported element <xsl:value-of select="local-name()"/> in Metamod</xsl:comment>
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">dif:Data_Center/dif:Data_Center_Name/dif:Long_Name</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>


    <xsl:template match="dif:Data_Center/dif:Data_Center_URL">
        <!-- Currently unsupported item in Metamod -->
        <xsl:comment>Unsupported element <xsl:value-of select="local-name()"/> in Metamod</xsl:comment>
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">dif:Data_Center/dif:Data_Center_URL</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>


    <xsl:template match="dif:Data_Center/dif:Personnel/dif:Role">
        <!-- Currently unsupported item in Metamod -->
        <xsl:comment>Unsupported element <xsl:value-of select="local-name()"/> in Metamod</xsl:comment>
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">dif:Data_Center/dif:Personnel/dif:Role</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>


    <xsl:template match="dif:Data_Center/dif:Personnel/dif:First_Name">
        <!-- Currently unsupported item in Metamod -->
        <xsl:comment>Unsupported element <xsl:value-of select="local-name()"/> in Metamod</xsl:comment>
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">dif:Data_Center/dif:Personnel/dif:First_Name</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>


    <xsl:template match="dif:Data_Center/dif:Personnel/dif:Last_Name">
        <!-- Currently unsupported item in Metamod -->
        <xsl:comment>Unsupported element <xsl:value-of select="local-name()"/> in Metamod</xsl:comment>
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">dif:Data_Center/dif:Personnel/dif:Last_Name</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>


    <xsl:template match="dif:Data_Center/dif:Personnel/dif:Phone">
        <!-- Currently unsupported item in Metamod -->
        <xsl:comment>Unsupported element <xsl:value-of select="local-name()"/> in Metamod</xsl:comment>
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">dif:Data_Center/dif:Personnel/dif:Phone</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>


    <xsl:template match="dif:Data_Center/dif:Personnel/dif:Contact_Address/dif:Address">
        <!-- Currently unsupported item in Metamod -->
        <xsl:comment>Unsupported element <xsl:value-of select="local-name()"/> in Metamod</xsl:comment>
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">dif:Data_Center/dif:Personnel/dif:Contact_Address/dif:Address</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>


    <xsl:template match="dif:Data_Center/dif:Personnel/dif:Contact_Address/dif:City">
        <!-- Currently unsupported item in Metamod -->
        <xsl:comment>Unsupported element <xsl:value-of select="local-name()"/> in Metamod</xsl:comment>
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">dif:Data_Center/dif:Personnel/dif:Contact_Address/dif:City</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>


    <xsl:template match="dif:Data_Center/dif:Personnel/dif:Contact_Address/dif:Postal_Code">
        <!-- Currently unsupported item in Metamod -->
        <xsl:comment>Unsupported element <xsl:value-of select="local-name()"/> in Metamod</xsl:comment>
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">dif:Data_Center/dif:Personnel/dif:Contact_Address/dif:Postal_Code</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>


    <xsl:template match="dif:Data_Center/dif:Personnel/dif:Contact_Address/dif:Country">
        <!-- Currently unsupported item in Metamod -->
        <xsl:comment>Unsupported element <xsl:value-of select="local-name()"/> in Metamod</xsl:comment>
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">dif:Data_Center/dif:Personnel/dif:Contact_Address/dif:Country</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>


    <xsl:template match="dif:Reference">
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">references</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>


    <xsl:template match="dif:Summary">
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">abstract</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>


    <xsl:template match="dif:Metadata_Name">
        <!-- Currently unsupported item in Metamod -->
        <xsl:comment>Unsupported element <xsl:value-of select="local-name()"/> in Metamod</xsl:comment>
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">dif:Metadata_Name</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>


    <xsl:template match="dif:Metadata_Version">
        <!-- Currently unsupported item in Metamod -->
        <xsl:comment>Unsupported element <xsl:value-of select="local-name()"/> in Metamod</xsl:comment>
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">dif:Metadata_Version</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>


    <xsl:template match="dif:Last_DIF_Revision_Date">
        <!-- Currently unsupported item in Metamod -->
        <xsl:comment>Unsupported element <xsl:value-of select="local-name()"/> in Metamod</xsl:comment>
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">dif:Last_DIF_Revision_Date</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>


    <xsl:template match="dif:Private">
        <!-- Currently unsupported item in Metamod -->
        <xsl:comment>Unsupported element <xsl:value-of select="local-name()"/> in Metamod</xsl:comment>
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">dif:Private</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>




</xsl:stylesheet>
