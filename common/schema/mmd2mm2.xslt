<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="xml" indent="yes"/>

  <xsl:template match="/">
<MM2 xmlns="http://www.met.no/schema/metamod/MM2"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://www.met.no/schema/metamod/MM2
  https://wiki.met.no/_media/metamod/mm2.xsd">
  <metadata name="variable">sea_ice_area_fraction</metadata>
  <metadata name="area">Northern Hemisphere</metadata>
  <metadata name="contact">heygster@uni-bremen.de</metadata>
  <metadata name="PI_name">Georg Heygster</metadata>
  <metadata name="product_version">1.0</metadata>
  <metadata name="keywords">Sea Ice</metadata>
  <metadata name="keywords">Arctic Ocean</metadata>
  <metadata name="references">Spreen, Kaleschke, Heygster, 2008 (doi:10.1029/2005JC003384)</metadata>
  <metadata name="datacollection_period_from">2010-05-01</metadata>
  <metadata name="activity_type">Space borne instrument</metadata>
  <metadata name="project_name">DAMOCLES</metadata>
  <metadata name="Conventions">CF-1.0</metadata>
  <metadata name="Platform_name">Aqua (NASA)</metadata>
  <metadata name="history">2010-05-31 creation</metadata>
  <metadata name="distribution_statement">Free</metadata>
  <metadata name="quality_index">1</metadata>
  <metadata name="software_version">ASI algorithm V.5</metadata>
  <metadata name="datacollection_period_to">2010-05-31</metadata>
  <metadata name="title">Sea ice concentration derived from AMSR-E</metadata>
  <metadata name="abstract">
    Sea ice concentration calculated with the ARTIST Sea Ice (ASI) algorithm (see
    www.iup.uni-bremen.de/seaice/amsr/) using AMSR-E (Advanced Microwave Scanning
    Radiometer) data. AMSR-E is a multichannel, dual polarisation (H and V)
    radiometer on NASA's satellite Aqua. Ice concentration is the fraction of a
    satellite footprint covered by sea ice, given in 0% (no ice) to 100% (totally
    ice-covered). About 14 daily satellite passes; in the Arctic, each point is
    covered at least twice daily. All satellite passes of one day are interpolated
    and averaged onto a 6.25 km grid, using the "nearneighbor" routine of the
    Generic Mapping Tools (GMT). The grid is the so-called NSIDC (National Snow and
    Ice Data Center) grid (nsidc.org/data/polar_stereo/ps_grids.html). It is a
    rectangular area from a polar stereographic projection with standard latitude
    70°N, and the meridian of 45°W pointing downwards. The x and y coordinates of
    the NSIDC grid correspond to the dimensions and variables "Xc" and "Yc" in this
    NetCDF file. The variable "seaice" thus depends on (Xc,Yc). In order to
    translate these coordinates into latitude and longitude, two additional
    variables, "latitude(Xc,Yc)" and "longitude(Xc,Yc)" are contained in the file.
    Note that although the corners of the area covered by the grid are as far south
    as 30.98°N (at 168.35°E), the southernmost parallel that is entirely inside the
    area of the grid is 56.35°N, in other words, any point north of 56.35°N is
    inside the area.
 </metadata>
  <metadata name="bounding_box">179.953491210938,31.0110759735107,-180,89.9592056274414</metadata>
  <metadata name="institution">University of Bremen</metadata>
  <metadata name="product_name">asi-n6250-2008*-v5 </metadata>
  <metadata name="dataref">http://thredds.met.no/thredds/catalog.html/data/IXI/iceconc/</metadata>
</MM2>

  </xsl:template>

</xsl:stylesheet>