#!/usr/bin/perl

use strict;
use warnings;

use FindBin;

use lib "$FindBin::Bin/../../common/lib";

use Cwd qw(abs_path);
use File::Find;
use Getopt::Long;
use Log::Log4perl qw(:easy);
use Pod::Usage;

use Metamod::Dataset;

=head1 NAME

write_data_file_location.pl Parse metadata dataref to determine the data_file_location and write the result to the metadata files.

=head1 DESCRIPTION

=head1 SYNOPSIS

write_data_file_location.pl [options] [dirname]

  Options:
    --overwrite Should data_file_location be overwritten if it already exists for a dataset

=cut

Log::Log4perl->easy_init($INFO);
my $logger = get_logger();

my $overwrite = '';

GetOptions( 'overwrite' => \$overwrite ) or pod2usage(1);

if( @ARGV != 1 ){
    pod2usage(1);
}

my $dirname = shift @ARGV;
my $config = Metamod::Config->new();


# We check if we can reach the data store. If that is not possible it is not
# possible to check that the parsed path is available and we don't want to
# continue.
my $opendap_directory = $config->get('OPENDAP_DIRECTORY');
if( ! -r $opendap_directory ){
    $logger->error("Cannot read the OPENDAP_DIRECTORY: $opendap_directory. No point to continue");
    exit 1;
}

my @metadata_files = ();
find( { wanted => \&is_metadata_file, no_chdir => 1 }, $dirname);

foreach my $file (sort @metadata_files){

    my $dataset = Metamod::Dataset->newFromFile($file);
    my %metadata = $dataset->getMetadata();

    # dataset location only relevant for level 2 datasets.
    next if !defined $dataset->getParentName();

    next if !exists $metadata{dataref};

    my $dataref = $metadata{dataref}->[0];

    # cannot parse datarefs that are not URLs
    next if ! ( $dataref =~ /^http(s)?:\/\//);

    my $location = dataref_to_location($dataref);

    next if !defined $location;

    if( !$overwrite && exists $metadata{data_file_location} ){
        $logger->info("$file already has 'data_file_location' and overwrite not set. Skipping");
        next;
    }

    my $datafile_path = "${opendap_directory}/$location";
    if( ! -e $datafile_path ){
        $logger->error("$datafile_path does not exist");
        next;
    }

    $dataset->removeMetadataName('data_file_location');
    $dataset->removeMetadataName('data_file_size');

    my $filesize = (stat($datafile_path))[7];
    my $new_metadata = {
        data_file_location => [$datafile_path],
        data_file_size     => [$filesize],
    };

    $dataset->addMetadata($new_metadata);
    $dataset->writeToFile($file);

}




sub is_metadata_file {

    return if !( $_ = /.*\.xml$/ );

    my $path = abs_path( $File::Find::name );
    push @metadata_files, $path;

}

sub dataref_to_location {
    my ($dataref) = @_;

    my $thredds_dataset_prefix = $config->get('THREDDS_DATASET_PREFIX');

    if( $dataref =~ /dataset=$thredds_dataset_prefix?(.*)/x ){
        return $1;
    } else {
        $logger->error( "Failed to parse: $dataref" );
        return;
    }

}