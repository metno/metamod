#! /usr/bin/perl
use strict;
use warnings;
use XML::LibXML;
use DBI;
use Geo::Proj4;

my $file = '/disk1/damocles/testXML/DAMOC/iceconc/iceconc_2009-01.xmlbb';

# get longitude/latitude from file
my $parser = new XML::LibXML;
my $xml = $parser->parse_file($file);
my $dataset = $xml->find('/datasetRegion/@dataset')->item(0)->value;
print STDERR $dataset, "\n";
my $latNode = $xml->findnodes('/datasetRegion/latitudeValues')->item(0);
my @latValues = split ' ', $latNode->textContent;
my $lonNode = $xml->findnodes('/datasetRegion/longitudeValues')->item(0);
my @lonValues = split ' ', $lonNode->textContent;

unless (scalar @latValues == scalar @lonValues) {
    die "problems reading ".(scalar @latValues). " latitude values and ".
        (scalar @lonValues)." longitude values\n";
}

# connect to testgis database
my $dbh = DBI->connect("dbi:Pg:dbname=testgis;host=localhost;port=15432", "", "", {'AutoCommit' => 0, 'RaiseError' => 1});

# upload data, convert data from lon/lat in WGS84 (4035) to polar-stereographic, WGS84, lat0 = 70 (93413)
my $time0 = time;
# postgis transform (2mio points): 881s
#my $insert = $dbh->prepare("INSERT INTO dataset_location (ds_id, point_ps) VALUES (1, ST_TRANSFORM(ST_SetSRID(ST_MAKEPOINT(?,?),4035), 93413))");
# geo::proj4 transform: 515s; 417s without gist index
#my $insert = $dbh->prepare("INSERT INTO dataset_location (ds_id, point_ps) VALUES (1, ST_SetSRID(ST_MAKEPOINT(?,?),93413))");
#$dbh->do("drop index idx_dataset_location_point_ps");

# insert into long/lat columns, make_points later, 300s lon/lat insert, 518s totalt
my $insert = $dbh->prepare("INSERT INTO dataset_location (ds_id, latitude, longitude) VALUES (1, ?, ?)");

my $points = scalar @latValues;
my $gp4 = new Geo::Proj4("+proj=stere +lat_0=70");
while (@latValues) {
    my $lat = shift @latValues;
    my $lon = shift @lonValues;
#    my ($x, $y) = $gp4->forward($lat, $lon);
#    $insert->execute($x, $y);
    $insert->execute($lat, $lon); 
}
#$dbh->do("create index idx_dataset_location_point_ps on dataset_location using gist (point_ps)");

print STDERR "insert $points long/lat points in ", (time - $time0), "s\n";

$dbh->do("UPDATE dataset_location SET point_ps = ST_TRANSFORM(ST_SetSRID(ST_MAKEPOINT(longitude,latitude),4035), 93413)");

print STDERR "update $points points in ", (time - $time0), "s\n";

$dbh->rollback;

# get envelope


# test searching by points/envelope