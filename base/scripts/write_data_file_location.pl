#!/usr/bin/perl

use strict;
use warnings;

use FindBin;

use lib "$FindBin::Bin/../../common/lib";
use lib "$FindBin::Bin/../../catalyst/lib";
use lib "$FindBin::Bin/../lib";

use Cwd qw(abs_path);
use File::Find;
use Getopt::Long;
use Log::Log4perl qw(:easy);
use Pod::Usage;

use Metamod::Dataset;
use Metamod::DBIxSchema::Userbase;

=head1 NAME

write_data_file_location.pl Parse metadata dataref to determine the data_file_location and write the result to the metadata files.

=head1 DESCRIPTION

=head1 SYNOPSIS

write_data_file_location.pl [options] [path to config file or dir] [dirname]

  Options:
    --overwrite Should data_file_location be overwritten if it already exists for a dataset

=cut

Log::Log4perl->easy_init($INFO);
my $logger = get_logger();

my $overwrite = '';

GetOptions( 'overwrite' => \$overwrite ) or pod2usage(1);

if( @ARGV != 2 ){
    pod2usage(1);
}

my $config_file_or_dir = shift @ARGV;
my $dirname = shift @ARGV;
my $config = Metamod::Config->new($config_file_or_dir);
$config->initLogger();


my $userbase_model;
my $external_repository = ($config->get('EXTERNAL_REPOSITORY') eq 'true') ? 1 : 0;
if( $external_repository ){
    my $userbase_dsn = $config->getDSN_Userbase();

    $userbase_model = Metamod::DBIxSchema::Userbase->connect($userbase_dsn, 'admin');
    $userbase_model->storage()->ensure_connected();

}

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

    my $datafile_path;
    if( $external_repository ){

        my $external_location = get_external_location($dataset, $userbase_model);

        next if !defined $external_location;

        # location should match part of the external location. We want the part
        # of location that comes after the match with external location.
        my @location_dirs = File::Spec->splitdir($location);
        my @external_dirs = File::Spec->splitdir($external_location);

        # find the first matching directory. We match agains the last dir in the external path
        my $location_index = 0;
        foreach my $dir (@location_dirs){

            $location_index++;

            last if $dir eq $external_dirs[-1];

        }

        my @location_rest;

        # no common directories. Just append to the end
        if( $location_index == scalar @location_dirs ){
            @location_rest = @location_dirs;
        } else {
           @location_rest = @location_dirs[$location_index .. $#location_dirs];
        }

        $datafile_path = File::Spec->catfile( $external_location, @location_rest );

    } else {
        $datafile_path = "${opendap_directory}/$location";
    }

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

sub get_external_location {
    my ($dataset, $model) = @_;

    my %info = $dataset->getInfo();
    my $name = $info{name};

    my $app_id;
    my $ds_name;

    # Only level 1 datasets are found in the data userbase so we drop the last
    # part of the dataset name as it is not relevant for the userbase query.
    if( $name =~ /^(.+?)\/(.+?)\/.+$/ ){
        $app_id = $1;
        $ds_name = $2;
    } else {
        $logger->error("Failed to parse the dataset name: $name");
        return;
    }

    my $userbase_ds = $model->resultset('Dataset')->search({ a_id => $app_id, ds_name => $ds_name } )->first();
    if( !defined $userbase_ds ){
        $logger->warn("Could not find dataset in the userbase: a_id : '$app_id', ds_name : '$ds_name'" );
        return;
    }

    my $location = $userbase_ds->infods()->search({i_type => 'LOCATION' } )->first();
    if( !defined $location ){
        $logger->warn("Could not find location for dataset: a_id : '$app_id', ds_name : '$ds_name'");
        return;
    }

    return $location->i_content();

}