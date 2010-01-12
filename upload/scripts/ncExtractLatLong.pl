#! /usr/bin/perl -w

=head1 NAME

ncExtractLatLong - extract lat/long information from datasets

=head1 SYNOPSIS

  ncExtractLatLong -x xmlDir [-O opendapdir -D datadir]

=head1 DESCRIPTION

This script will read all xml/xmd-files in a directory
For each dataset beloning to the xml/xmd data, it will read the
latitute/longitude information and put them to a xmlbb file 
(the xmll data should be in a later stage be added to the xmd data
instead of the quadtree_nodes)

=head1 AUTHOR

Heiko Klein, E<lt>H.Klein@met.noE<gt>

=head1 SEE ALSO

=cut

use strict;
use warnings;
use Getopt::Std qw(getopts);
use Pod::Usage qw(pod2usage);
use File::Spec;
use PDL::NetCDF;
use Fcntl qw(:DEFAULT);
use File::Find;
use vars qw(%Args);

# small routine to get lib-directories relative to the installed file
sub getTargetDir {
    my ($finalDir) = @_;
    my ($vol, $dir, $file) = File::Spec->splitpath(__FILE__);
    $dir = $dir ? File::Spec->catdir($dir, "..") : File::Spec->updir();
    $dir = File::Spec->catdir($dir, $finalDir); 
    return File::Spec->catpath($vol, $dir, "");
}
# local libraries
use lib ('../../common/lib', getTargetDir('lib'), getTargetDir('scripts'), '.');
use Metamod::Dataset;
use MetNo::NcFind;

$Args{O} = 'http://damocles.met.no:8080/thredds/';
$Args{D} = '/metno/damocles/data/';
getopts('x:O:D:h', \%Args) or pod2usage(2);
pod2usage(-exitval => 0,
          -verbose => 2) if $Args{h};
pod2usage(-exitval => 2,
          -msg => "Missing xml-inputdir (-x)") unless $Args{x};
$Args{D} .= '/' unless $Args{D} =~ m^/$^;

our @xmdFiles;
find(\&extractXML, $Args{x});
foreach my $basename (@xmdFiles) {
	my $dataset = Metamod::Dataset->newFromFile($basename);
    my $ncFile = extractNcFile($Args{O}, $Args{D}, $basename, $dataset) if $dataset;
    if ($ncFile) {
        print STDERR "working on $ncFile\n";
        my %lonLatInfo = extractLonLat($ncFile);
        my %info = $dataset->getInfo;
        open my $fh, ">$basename.xmlbb"
           or die "Cannot write $basename.xmlbb: $!";
        print $fh '<datasetRegion dataset="'.$info{name}.'">'."\n";
        my $lonLatAdded;
        foreach my $polygon (@{ $lonLatInfo{polygons} }) {
            print $fh '<lonLatPolygon>'."\n";
            print $fh join ',', map {sprintf "%.3f %.3f", @$_} @$polygon;
            print $fh '</lonLatPolygon>'."\n";
        }
        if (@{ $lonLatInfo{points} }) {
            print $fh '<lonLatPoints>'."\n";
            print $fh join ',', map {sprintf "%.3f %.3f", @$_} @{$lonLatInfo{points}};
            print $fh '</lonLatPoints>'."\n";            
        }
        my $bb = $lonLatInfo{boundingBox};
        print $fh '<boundingBox north="'.$bb->{north}.'" south="'.$bb->{south}.'" east="'.$bb->{east}.'" west="'.$bb->{west}.'" />'."\n" if (scalar keys %$bb == 4);
        print $fh '</datasetRegion>'."\n";
        close $fh;
    }
}

# find the xmd files and put them to @xmdFiles
sub extractXML {
    return unless /\.xmd$/;
    my $basename = $File::Find::name;
    $basename =~ s/\.xmd$//;
    push @xmdFiles, $basename;
}

# find the nc-file of the dataset and extract lat/lon
sub extractNcFile {
    my ($opendapDir, $dataDir, $basename, $dataset) = @_;
    my %metaData = $dataset->getMetadata();
    my $dataref;
    if (exists $metaData{dataref}) {
        $dataref = (ref $metaData{dataref} ? $metaData{dataref}[0] : $metaData{dataref});
    }
    my $ncFile;
    if ($dataref && $dataref =~ /^\Q$opendapDir\E.*catalog.html\?dataset=/) {
        # file based datasets, not catalogues
        # http://damocles.met.no:8080/thredds/catalog/data/met.no/itp01/catalog.html?dataset=met.no/itp01/itp01_itp1grd1890.nc
        # /metno/damocles/data/                                                              met.no/itp01/itp01_itp1grd1890.nc
        $ncFile = $dataref;
        $ncFile =~ s/^\Q$opendapDir\E.*catalog.html\?dataset=/$dataDir/;
    }
    if ($ncFile && (!-f $ncFile)) {
        undef $ncFile;
    }
    return $ncFile;
}

# extract lat/lon information as polygons or points from the used latitude/longitude variables
# given as CF convention
# extracts also bounding-box if given as global northernmost_latitude, ...
# return (errors      => \@errors,
#         polygons    => \@lonLatPolygons,
#         points      => \@lonLatPoints,
#         boundingBox => \%boundingBox{east,north,west, south});
sub extractLonLat {
    my ($ncFile) = @_;
    my $nc = new MetNo::NcFind($ncFile);

    my %boundingBox;
    my @lonLatPolygons;
    my @lonLatPoints;
    my @errors;
    my %globAtt = map {$_ => 1} $nc->globatt_names;
    if (exists $globAtt{northernmost_latitude} &&
        exists $globAtt{southernmost_latitude} &&
        exists $globAtt{westernmost_longitude} &&
        exists $globAtt{easternmost_longitude})
       {
       	$boundingBox{north} = $nc->globatt_value('northernmost_latitude');
       	$boundingBox{south} = $nc->globatt_value('southernmost_latitude');
       	$boundingBox{west} = $nc->globatt_value('westernmost_longitude');
        $boundingBox{east} = $nc->globatt_value('easternmost_longitude');
    }
    # find latitude/longitude variables (variables with units degree(s)_(north|south|east|west))    
    my %latDims = map {$_ => 1} $nc->findVariablesByAttributeValue('units', qr/degrees?_(north|south)/);
    my %lonDims = map {$_ => 1} $nc->findVariablesByAttributeValue('units', qr/degrees?_(east|west)/);    


    # lat/lon pairs can, according to CF-1.3 belong in differnt ways to a variable
    # a) var(lat,lon), lat(lat), lon(lon) (CF-1.3, 5.1)
    # b) var(x,y), var:coordinates = "lat lon ?", lat(x,y), lon(x,y) (CF-1.3, 5.2, 5.6)
    # c) var(t), var:coordinates = "lat lon ?", lat(t), lon(t) (CF-1.3, 5.3-5.5)
    #
    # a) and b) will be translated to a polygon describing the outline
    # c) will be translated to a list of lat/lon points
    
    # find variables directly related to each combination of lat/lon (a)
    my @lonLatCombinations;
    foreach my $lat (keys %latDims) {
        foreach my $lon (keys %lonDims) {
            push @lonLatCombinations, [$lon,$lat];
        }
    }
    my @lonLatDimVars;
    my @usedLonLatCombinations;
    my @unUsedLonLatCombinations;
    foreach my $llComb (@lonLatCombinations) {
        my @llDimVars = $nc->findVariablesByDimensions($llComb);
        if (@llDimVars) {
            push @lonLatDimVars, @llDimVars;  
            push @usedLonLatCombinations, $llComb;
        } else {
            push @unUsedLonLatCombinations, $llComb;
        }
    }
    foreach my $llCom (@usedLonLatCombinations) {
        # build a polygon around all outer points
        my @lons = $nc->get_values($llCom->[0]);
        my @lats = $nc->get_values($llCom->[1]);
        if (@lons && @lats) {
            my @polygon;
            push @polygon, map{[$_, $lats[0]]} @lons;
            push @polygon, map{[$lons[-1], $_]} @lats;
            push @polygon, map{[$_, $lats[-1]]} reverse @lons;
            push @polygon, map{[$lons[0], $_]} reverse @lats;
            push @lonLatPolygons, \@polygon;            
        }
    }
    
    # get the coordinates values to find lat/lon pairs (b and c)
    my @coordVars = $nc->findVariablesByAttributeValue('coordinates', qr/.*/);
    # remove the variables already detected as class a)
    my %lonLatDimVars = map {$_ => 1} @lonLatDimVars;
    @coordVars = map {exists $lonLatDimVars{$_} ? () : $_} @coordVars;

    my @lonLatCoordinates;
    foreach my $coordVar (@coordVars) {
        my @coordinates = split ' ', $nc->att_value($coordVar, 'coordinates');
        my %coordinates = map {$_ => 1} @coordinates;
        my @tempUnusedLonLatCombinations = @unUsedLonLatCombinations;
        @unUsedLonLatCombinations = ();
        foreach my $llComb (@tempUnusedLonLatCombinations) {
            if (exists $coordinates{$llComb->[0]} and
                exists $coordinates{$llComb->[1]}) {
                push @lonLatCoordinates, $llComb;
                push @usedLonLatCombinations, $llComb;    
            } else {
                push @unUsedLonLatCombinations, $llComb;
            }
        }
    }
    foreach my $llCoord (@lonLatCoordinates) {
        # $llCoord is a used lon/lat combination for case b and c
        # use case b if lat and lon are 2d, case c for 1d
        my $lonName = $llCoord->[0];
        my $latName = $llCoord->[1];
        my @latDims = $nc->dimensions($latName);
        my @lonDims = $nc->dimensions($lonName);
        if (@latDims != @lonDims) {
            my $msg = "number $latName dimensions (@latDims) != $lonName dimensions (@lonDims), skipping ($latName,$lonName)"; 
            warn $msg;
            push @errors, $msg;
        } elsif (1 == @latDims) {
            # case c)
            my ($lons, $lats) = $nc->get_lonlats($lonName, $latName);
            while (@$lons) {
                push @lonLatPoints, [shift @$lons, shift @$lats];
            }
        } elsif (2 == @latDims) {
            # case b)
            my @lonBorders = $nc->get_bordervalues($lonName);
            my @latBorders = $nc->get_bordervalues($latName);
            if (scalar @lonBorders == scalar @latBorders) {
                my @polygon = map {[$_, shift @latBorders]} @lonBorders;
                push @lonLatPolygons, \@polygon;
            } else {
                my $msg = "$latName dimension ".(scalar @latBorders)." != $lonName dimensions ".(scalar @lonBorders).", skipping";
                warn $msg;
                push @errors, $msg;
            } 
        } else {
            my $msg = "$latName and $lonName are of dimension ".(scalar @latDims). ". Don't know what to do, skipping.";
            warn $msg;
            push @errors, $msg;
        }
    }
    
    return (errors => \@errors, polygons => \@lonLatPolygons, points => \@lonLatPoints, boundingBox => \%boundingBox);
}

