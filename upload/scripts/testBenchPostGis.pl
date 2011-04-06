# /usr/bin/perl
use strict;
use warnings;
use DBI;

my $dbh = DBI->connect("dbi:Pg:dbname=testgis;host=localhost;port=15432", "", "", {'AutoCommit' => 0, 'RaiseError' => 1});
my $geomDWitinSth = $dbh->prepare("SELECT DISTINCT(ds_name) FROM dataset_location ".
                                  " WHERE ST_DWITHIN(ST_TRANSFORM(ST_GeomFromText(?,4035), 93413), the_geom_ps,0)");
my $geomIntersectsSth = $dbh->prepare("SELECT DISTINCT(ds_name) FROM dataset_location ".
                                  " WHERE ST_INTERSECTS(ST_TRANSFORM(ST_GeomFromText(?,4035), 93413), the_geom_ps)");

my %bb0 = (south => 80,
           north => 90,
           east  => 15,
           west  => -4);

my $bb0Poly = makePoly(%bb0);
print STDERR "$bb0Poly\n";

$geomIntersectsSth->execute($bb0Poly);
my $rows = $geomIntersectsSth->fetchall_arrayref;
print STDERR "found ".scalar @$rows." matching datasets with intersects\n";
$geomDWitinSth->execute($bb0Poly);
$rows = $geomDWitinSth->fetchall_arrayref;
print STDERR "found ".scalar @$rows." matching datasets with dwithin\n";

my $count = 5;
my $time0 = time;
foreach $_ (1..$count) {
    $geomIntersectsSth->execute($bb0Poly);   
}
print STDERR "intersect in ".((time-$time0)/$count)."s\n";
$time0 = time;
foreach $_ (1..$count) {
    $geomDWitinSth->execute($bb0Poly);   
}
print STDERR "dwithin in ".((time-$time0)/$count)."s\n";
$dbh->rollback;

sub makePoly {
    my %bb = @_;
    my $polygon = "$bb{west} $bb{south},$bb{west} $bb{north},$bb{east} $bb{north},$bb{east} $bb{south},$bb{west} $bb{south}";
    $polygon = "POLYGON((".$polygon."))";
    return $polygon;
}                              