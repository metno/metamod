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

$Args{O} = 'http://thredds.met.no/thredds/';
$Args{D} = '/metno/damocles/data/';
getopts('x:O:D:h', \%Args) or pod2usage(2);
pod2usage(-exitval => 0,
          -verbose => 2) if $Args{h};
pod2usage(-exitval => 2,
          -msg => "Missing xml-inputdir (-x)") unless $Args{x};
$Args{D} .= '/' unless $Args{D} =~ m^/$^;

our @xmdFiles;
find(\&extractXML, $Args{x});
# cache of the previous parent
# parents will only be written, when a new parent is required
my ($lastParentBase, $lastParent, $lastParentRegion);
foreach my $basename (@xmdFiles) {
	my $dataset = Metamod::Dataset->newFromFile($basename);
    my $region = new Metamod::DatasetRegion();
    my $ncFile = extractNcFile($Args{O}, $Args{D}, $basename, $dataset) if $dataset;
    if ($ncFile) {
        print STDERR "working on $ncFile\n";
        my $nc = new MetNo::NcFind($ncFile);
        eval { 
            my %bb = $nc->findBoundingBoxByGlobalAttributes(qw(northernmost_latitude southernmost_latitude easternmost_longitude westernmost_longitude));
            $region->extendBoundingBox(\%bb);
        }; if ($@) {
            warn $@;
        }
        my %lonLatInfo = $nc->extractCFLonLat();
        foreach my $polygon (@{ $lonLatInfo{polygons} }) {
            $region->addPolygon($polygon);
        }
        foreach my $p (@{ $lonLatInfo{points} }) {
            $region->addPoint($p);
        }
        $dataset->setDatasetRegion($region);
        $dataset->writeToFile($basename);
        if ($dataset->getParentName()) {
            my ($vol, $dir, $file) = File::Spec->splitpath(File::Spec->rel2abs($basename));
            my @dirs = File::Spec->splitdir($dir);
            my $pFile = pop @dirs;
            while (($pFile eq "") and @dirs) {
                $pFile = pop @dirs;
            }
            my $parentBase = File::Spec->catfile($vol,File::Spec->catdir(@dirs), $pFile);
            if ($lastParentBase ne $parentBase) {
                # cleanup
                $lastParent->setDatasetRegion($lastParentRegion) if $lastParent;
                $lastParent->writeToFile($lastParentBase) if $lastParent;
                    
                # and the new one
                $lastParentBase = $parentBase;
                $lastParent = Metamod::Dataset->newFromFile($lastParentBase);
                $lastParentRegion = $lastParent->getDatasetRegion() if $lastParent;
            }
            if ($lastParent) {
                $lastParentRegion->addRegion($region);
            } else {
                warn "couldn't find parent of $basename at $parentBase ($pFile)\n";
            }
        }
    }
}
# write the parent not written yet
if ($lastParent) {
    $lastParent->setDatasetRegion($lastParentRegion);
    $lastParent->writeToFile($lastParentBase);
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

