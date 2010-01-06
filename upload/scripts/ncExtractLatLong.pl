#! /usr/bin/perl -w

=head1 NAME

ncExtractLatLong - extract lat/long information from datasets

=head1 SYNOPSIS

  ncExtractLatLong -x xmlDir [-O opendapdir -D datadir]

=head1 DESCRIPTION

This script will read all xml/xmd-files in a directory
For each dataset beloning to the xml/xmd data, it will read the
latitute/longitude information and put them to a xmll file 
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
	my ($latArray, $lonArray) = extractLatLong($ncFile) if $ncFile;
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

sub extractLatLong {
	my ($ncFile) = @_;
	my $nc = new PDL::NetCDF($ncFile, {REVERSE_DIMS => 1, MODE => O_RDONLY});
    my (@lat, @long);
    
    # find latitude/longitude variables (variables with units degree(s)_(north|south|east|west))    
    
    
    return (\@lat, \@long);	
}

sub findVariablesByAttributeValue {
	my ($nc, $attribute, $valueRegex) = @_;
	my @variables = $nc->getvariablenames;
	my @outVars;
	foreach my $var (@variables) {
		#my @attrs = $nc->getattributenames($var);
        my $val = $nc->getatt($attribute, $var);
        if (defined $val and ! ref $val) { # pdl-attributes not supported
        	if ($val =~ /$valueRegex/) {
        		push @outVars, $var;
        	}
        }
	}
	return @outVars;
}