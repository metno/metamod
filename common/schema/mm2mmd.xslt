<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="xml" indent="yes"/>

  <xsl:template match="/">

<mmd xmlns="http://www.met.no/schema/mmd" xmlns:gml="http://www.opengis.net/gml">
  <metadata_version>1</metadata_version>
  <dataset_language>en</dataset_language>
  <metadata_identifier />
  <title xml:lang="en">Arctic Ocean Physics Analysis and Foreca</title>
  <abstract xml:lang="en">The operational TOPAZ4 Arctic Ocean system uses the
  HYCOM model and a 100-member EnKF assimilation scheme. It is run daily to
  provide 10 days of forecast (one single member) of the 3D physical ocean,
  including sea ice; data assimilation is performed weekly to provide 7 days of
  analysis (ensemble average).

Operational Ocean General Circulation Models describe routinely the 4D evolution
of the physical ocean and sea ice variables, such as temperature, salinity,
currents, sea level height, sea ice thickness and concentration. The TOPAZ
system has provided analyses and forecasts for the Atlantic and Arctic Basins
since 2003, assimilating available satellite and in situ observations.

The current version of the TOPAZ system - TOPAZ4 - uses the latest version of
the Hybrid Coordinate Ocean Model (HYCOM) developed at University of Miami
(Bleck 2002). HYCOM is coupled to a sea ice model; ice thermodynamics are
described in Drange and Simonsen (1996) and the elastic-viscous-plastic rheology
in Hunke and Dukowicz (1997). The model's native grid covers the Arctic and
North Atlantic Oceans, is obtained by comformal mapping and has fairly
homogeneous horizontal spacing (between 11 and 16 km). 28 hybrid layers are used
in the vertical (z-isopycnal). TOPAZ4 uses the Ensemble Kalman filter (EnKF;
Sakov and Oke 2008) to assimilate remotely sensed sea level anomalies, sea
surface temperature, sea ice concentration, lagrangian sea ice velocities
(winter only), as well as temperature and salinity profiles from Argo floats.
From V2, all assimilation data are acquired from the relevant MyOcean Thematic
Assembly Centres: Sea Level TAC, Sea Surface Temperature TAC, Ocean and Sea Ice
TAC and In Situ TAC. In this connection, the V2 system was reinitialized with
respect to the V1 system. The output consists of daily mean fields interpolated
onto standard grids in NetCDF CF format. Variables include 3D currents (U, V),
temperature and salinity, as well as 2D fields of sea ice parameters, sea
surface height, mixed layer depth and more.

Data assimilation, including the 100-member ensemble production, is performed
weekly on Tuesdays to produce a week-long analysis (ensemble average) and
initialize a 10-day forecast. A new 10-day forecast is produced daily using the
previous day's forecast and the most up-to-date prognostic forcing
fields.</abstract>
  <last_metadata_update />
  <iso_topic_category>farming</iso_topic_category>
  <data_center>
    <data_center_name />
  </data_center>
  <vocabulary id="cf">
    <description>...</description>
    <resource>http://</resource>
  </vocabulary>
  <keywords vocabulary="none" />
  <temporal_extent>
    <start_date>2010-08-25T00:00:00Z</start_date>
    <end_date />
  </temporal_extent>
  <geographic_extent>
    <rectangle>
      <north>90.0</north>
      <south>65.0</south>
      <east>180.</east>
      <west>-180.</west>
    </rectangle>
    <polygon>
      <gml:Polygon id="polygon" srsName="EPSG:4326">
        <gml:exterior>
          <gml:LinearRing />
        </gml:exterior>
      </gml:Polygon>
    </polygon>
  </geographic_extent>
</mmd>

  </xsl:template>

</xsl:stylesheet>