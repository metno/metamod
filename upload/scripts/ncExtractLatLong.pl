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
use MetNo::NcFind;
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
        my ($latArray, $lonArray, $bb) = extractLatLong($ncFile);
        my %info = $dataset->getInfo;
        open my $fh, ">$basename.xmlbb"
           or die "Cannot write $basename.xmlbb: $!";
        print $fh '<datasetRegion dataset="'.$info{name}.'">'."\n";
        print $fh '<latitudeValues>'.join(" ", map {sprintf "%.3f", $_} @$latArray).'</latitudeValues>'. "\n" if @$latArray;
        print $fh '<longitudeValues>'.join(" ", map {sprintf "%.3f", $_} @$lonArray).'</longitudeValues>'. "\n" if @$latArray;
        print $fh '<boundingBox north="'.$bb->{north}.'" south="'.$bb->{south}.'" east="'.$bb->{east}.'" west="'.$bb->{west}.'" />'."\n" if scalar keys %$bb;
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

# extract lat/long from the used latitude/longitude variables
# return list of latitude/longitude, and bb if southernmost, easternmost, westernmost, and nothernmost global attributes
# are given
# return \@lat, \@lon, '%boundingBox {east,north,west, south}'
sub extractLatLong {
    my ($ncFile) = @_;
    my $nc = new MetNo::NcFind($ncFile);

    my %boundingBox;
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
    my @latVars = $nc->findVariablesByAttributeValue('units', qr/degrees?_(north|south)/);
    my @lonVars = $nc->findVariablesByAttributeValue('units', qr/degrees?_(east|west)/);    
    
    # get the coordinates values to find lat/lon pairs
    my @coordVars = $nc->findVariablesByAttributeValue('coordinates', qr/.*/);
    my %coords;
    foreach my $coordVar (@coordVars) {
        $coords{$nc->att_value($coordVar, 'coordinates')}++;
    }
    my %latVars = map {$_ => 1} @latVars;
    my %lonVars = map {$_ => 1} @lonVars;
    my @latLonPairs;
    foreach my $coord (keys %coords) {
        my @coordVars = split ' ', $coord;
        foreach my $coordVar (@coordVars) {
            # get the latitude and longitude variables of the coordinates
            my @lats = grep {$_ eq $coordVar} keys %latVars;
            my @lons = grep {$_ eq $coordVar} keys %lonVars;
            if (@lats == 0 or @lons == 0) {
                next;
            } elsif (@lats > 1 or @lons > 1) {
                warn "found several lat/lon coordinates in $ncFile\n";
            } else {
                push @latLonPairs, [$lats[0], $lons[0]];
                # remove the lat/lon pair
                delete $latVars{$lats[0]};
                delete $lonVars{$lons[0]};
            }
        }
    }
    if (scalar keys %latVars == 1 and scalar keys %lonVars == 1) {
        # on lat/lon pair left, just add
        push @latLonPairs, [keys %latVars, keys %lonVars];
    }
    # make a long list of lats and longs
    my (@lat, @lon);
    foreach my $latLonPair (@latLonPairs) {
        my ($llon, $llat) = $nc->get_lonlats($latLonPair->[1], $latLonPair->[0]);
        push @lat, @$llat;
        push @lon, @$llon;
    }
    return (\@lat, \@lon, \%boundingBox);	
}

