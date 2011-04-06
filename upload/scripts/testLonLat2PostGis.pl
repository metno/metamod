#! /usr/bin/perl
use strict;
use warnings;
use XML::LibXML;
use DBI;
use Geo::Proj4;
use File::Find;

my $xmlDir = '/disk1/damocles/testXML/';

# get longitude/latitude from file
my $parser = new XML::LibXML;


# connect to testgis database
my $dbh = DBI->connect("dbi:Pg:dbname=testgis;host=localhost;port=15432", "", "", {'AutoCommit' => 0, 'RaiseError' => 1});
my $geomInsert = $dbh->prepare("INSERT INTO dataset_location (ds_name, the_geom_ps) VALUES (?,ST_TRANSFORM(ST_GeomFromText(?,4035), 93413))");


my $time0 = time;

find(\&wanted, $xmlDir);

$dbh->commit;
print STDERR "insert polygon/points in ", (time - $time0), "s\n";

sub wanted {
    if (/.xmlbb$/ && -f $_) {
        print STDERR "$File::Find::name\n";
        geomToDb($File::Find::name);
    }
}

sub geomToDb {
    my ($file) = @_; 
    my @points;
    
    my $xml = $parser->parse_file($file);

    my $dataset = $xml->find('/datasetRegion/@dataset')->item(0)->value;
    foreach my $node ($xml->findnodes('/datasetRegion/lonLatPoint')) {
        push @points, $node->textContent;
    }
    my @polygons;
    foreach my $node ($xml->findnodes('/datasetRegion/lonLatPolygon')) {
        push @polygons, $node->textContent;
    }
    # add boundingbox if no other data 
    if (@polygons == 0 and @points == 0) {
        my %bb;
        foreach my $node ($xml->findnodes('/datasetRegion/boundingBox')) {
            map {$bb{$_->name} = $_->value} $node->attributes;
        }
        if (exists $bb{west} and exists $bb{south} and exists $bb{north} and exists $bb{east}) {
            foreach my $var (keys %bb) {
                $bb{$var} = sprintf "%.3f", $bb{$var}; # math representation
            }
            my $polygon = "$bb{west} $bb{south},$bb{west} $bb{north},$bb{east} $bb{north},$bb{east} $bb{south},$bb{west} $bb{south}";
            push @polygons, $polygon;
        }
    }

    # upload data, convert data from lon/lat in WGS84 (4035) to polar-stereographic, WGS84, lat0 = 70 (93413)
    foreach my $poly (@polygons) {
        my $invalid = 0;
        map {if ($_ and ($_ > 180 or $_ < -180)) {$invalid++}} split /[,\s+]/, $poly;
        if ($invalid == 0) { 
            $geomInsert->execute($dataset, 'POLYGON(('.$poly.'))');
        } else {
            print STDERR "invalid polygon: $poly\n";
        }
    }
    foreach my $pointSet (@points) {
        my @points;
        foreach my $p (split ',', $pointSet) {
            my ($lon, $lat) = split ' ', $p;
            if ($lon <= 180 and $lon >= -180 and $lat <= 90 and $lat >= -90) {
                push @points, sprintf ("(%.3f %.3f)", $lon, $lat);
            }
        }
        if (@points) {
            my $multipoint = 'MULTIPOINT('. join(',',@points) .')';
            $geomInsert->execute($dataset, $multipoint);
        }
    }
}


__END__
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