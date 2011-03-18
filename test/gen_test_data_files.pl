#!/usr/bin/perl

use strict;
use warnings;

use FindBin;

use lib "$FindBin::Bin/../common/lib";

use Cwd qw(abs_path);
use File::Find;
use File::Path;
use File::Spec;
use Getopt::Long;
use Log::Log4perl qw(:easy);
use Pod::Usage;

use Metamod::Dataset;

=head1 NAME

gen_test_data_files.pl - Generate dummy data files for all metadata files.

=head1 DESCRIPTION

Generate dummy data files for all the metadata files in a directory. This is
useful for testing the collection basket which requires file access to the data
files.

=head1 SYNOPSIS

gen_test_data_files.pl [metadata directory] [data directory]

=cut

Log::Log4perl->easy_init($INFO);
my $logger = get_logger();

if( @ARGV != 2 ){
    pod2usage(1);
}

my $config = Metamod::Config->new();

my $metadata_dir = abs_path( shift @ARGV );
my $data_dir = shift @ARGV;

# we start by doing some cleaning
rmtree($data_dir);

my @metadata_files = ();
find( \&is_metadata_file, $metadata_dir);


foreach my $file (sort @metadata_files){

    my $dataset = Metamod::Dataset->newFromFile($file);

    if( !defined $dataset ){
        $logger->warn("Could not create a dataset for $file");
        next;
    }

    # level 1 datasets do not have data associated with them
    next if !defined $dataset->getParentName();

    my %metadata = $dataset->getMetadata();

    # no dataref so no point to continue
    next if !exists $metadata{dataref};

    my $dataref = $metadata{dataref}->[0];

    my $location = dataref_to_location($dataref);

    my ($dummy, $directories, $file) = File::Spec->splitpath($location);
    my $dir_path = File::Spec->catdir($data_dir, $directories);

    if( ! -e $dir_path ){
        mkpath($dir_path);
    }

    my $file_path = File::Spec->catfile($dir_path, $file);

    # create random data up to 2 MB
    my $bytes = int(rand(1024)+1) * int(rand(1024)+1) * int(rand(2)+1);
    open my $DUMMY_DATA, '>', $file_path;
    print $DUMMY_DATA '0' x $bytes;
    close $DUMMY_DATA;


}

sub is_metadata_file {

    return if !( $_ = /.*\.xml$/ );

    my $path = $File::Find::name;
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
