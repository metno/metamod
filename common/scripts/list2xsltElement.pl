#! /usr/bin/perl -w
# small helper-script to convert a list as used in oaidp-config.php
# to xslt-elements
#
# the results need to be manuall post processed
# the list needs to be added/exchanged manually
use strict;
use warnings;

# prefix to be used for all xpath elements
my $xpathPrefix = 'dif';
# syntax: 'metadata-name' 'original xpath (space as /)' 'default value'
#    metadata-name: start with !: ignore - database-field
#                   end with number: special handling for each metadata required
#    original xpath: start with *: group - just of interest when converting from metadata to xpath
#    default value: just of interest when converting from metadata to xpath
my @list = (
         '!DS_name 1', 'Entry_ID', '',
         'title', 'Entry_Title', '',
         'PI_name', 'Data_Set_Citation Dataset_Creator', '',
         'title', 'Data_Set_Citation Dataset_Title', '',
         'institution', 'Data_Set_Citation Dataset_Publisher', '',
         'dataref', 'Data_Set_Citation Online_Resource', '',
         'variable', '*Parameters Category', 'EARTH SCIENCE',
         'variable 1', 'Parameters Topic', '',
         'variable 2', 'Parameters Term', '',
         'variable 3', 'Parameters Variable_Level_1', '',
         'variable', 'Parameters Detailed_Variable', '',
         'topiccategory', 'ISO_Topic_Category', '',
         'keywords', 'Keyword', '',
         'datacollection_period 1', 'Temporal_Coverage Start_Date', '',
         'datacollection_period 2', 'Temporal_Coverage Stop_Date', '',
         'southernmost_latitude', 'Spatial_Coverage Southernmost_Latitude', '',
         'northernmost_latitude', 'Spatial_Coverage Northernmost_Latitude', '',
         'westernmost_longitude', 'Spatial_Coverage Westernmost_Longitude', '',
         'easternmost_longitude', 'Spatial_Coverage Easternmost_Longitude', '',
         'area 1', '*Location Location_Category', '',
         'area 2', 'Location Location_Type', '',
         'area 3', 'Location Location_Subregion1', '',
         'area 4', 'Location Detailed_Location', '',
         'latitude_resolution 1', 'Data_Resolution Latitude_Resolution', '',
         'longitude_resolution 1', 'Data_Resolution Longitude_Resolution', '',
         '!DS_ownertag 1', 'Project Short_Name', '',
         'distribution_statement', 'Access_Constraints', '',
         'institution', 'Originating_Center', '',
         '', 'Data_Center Data_Center_Name Short_Name', 'met.no',
         '', 'Data_Center Data_Center_Name Long_Name', 'Norwegian Meteorological Institute',
         '', 'Data_Center Data_Center_URL', 'http://met.no/',
         '', 'Data_Center Personnel Role', 'DATA CENTER CONTACT',
         '', 'Data_Center Personnel First_Name', 'Egil',
         '', 'Data_Center Personnel Last_Name', 'Støren',
         '', 'Data_Center Personnel Phone', '+4722963000',
         '', 'Data_Center Personnel Contact_Address Address', "Norwegian Meteorological Institute\nP.O. Box 43\nBlindern",
         '', 'Data_Center Personnel Contact_Address City', 'Oslo',
         '', 'Data_Center Personnel Contact_Address Postal_Code', 'N-0313',
         '', 'Data_Center Personnel Contact_Address Country', 'Norway',
         'references', 'Reference', '',
         'abstract', 'Summary', '',
         '', 'Metadata_Name', 'CEOS IDN DIF',
         '', 'Metadata_Version', '9.7',
         '!DS_datestamp', 'Last_DIF_Revision_Date', '',
         '', 'Private', 'False',
);

if (@list % 3 != 0) {
    die "each list-row needs to consist of 3 entries";
}

my $element = <<EOF;
    <xsl:template match="XPATH">COMMENT
        <xsl:element name="metadata" xmlns="http://www.met.no/schema/metamod/MM2">
            <xsl:attribute name="name">METADATA</xsl:attribute>
            <xsl:value-of select="." />
        </xsl:element>
    </xsl:template>
EOF

my $unknownComment =
'        <!-- Currently unsupported item in Metamod -->
        <xsl:comment>Unsupported element <xsl:value-of select="local-name()"/> in Metamod</xsl:comment>';

for (my $i = 0; $i < @list; $i++) {
    my $metadata = $list[$i];
    my $xpath = $list[++$i];
    my $default_value = $list[++$i]; # ignored
    $metadata =~ s/^!.*//; # database element
    next unless $xpath;
    $xpath =~ s/^\*//; # remove grouping
    $xpath = join '/', (map {"$xpathPrefix:$_"} split (' ', $xpath)); # space to /, add prefix
    my $el = $element;
    $el =~ s/XPATH/$xpath/g;
    if ($metadata) {
        $el =~ s/METADATA/$metadata/g;
        $el =~ s/COMMENT//g;
    } else {
        $el =~ s/METADATA/$xpath/g;
        $el =~ s/COMMENT/\n$unknownComment/g;
    }
    print "$el\n\n";
}
