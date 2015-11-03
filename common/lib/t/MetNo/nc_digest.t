#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;
use FindBin;

use lib "$FindBin::Bin/../..";

my $num_tests = 0;
use Cwd qw(abs_path);
use File::Path;
use Test::More;
use Test::Files;

use Metamod::Config;
use Metamod::Test::Setup;
use MetNo::NcDigest qw( digest );

my $test_setup = Metamod::Test::Setup->new( master_config_file => "$FindBin::Bin/../master_config.txt" );
my $config = $test_setup->mm_config();

my $out_dir = "$FindBin::Bin/xml_output/xml_output"; # sure this is writeable? FIXME
my $baseline_dir = "$FindBin::Bin/../data/MetNo"; # dir with the correct xml files

if( !( -e $out_dir ) ){
    mkpath( $out_dir ) or die "Output dir not writeable: $!";
}

my $path_to_data = abs_path($baseline_dir);

my $digest_content = <<"END_DIGEST_CONTENT"; # this dataset requires a password to access - to be fixed?
http://thredds.met.no/thredds/catalog/data/met.no/ecmwf/catalog.html?dataset=met.no/ecmwf/ecmwf_atmo0_5_2010-08-09_00.nc
${path_to_data}/ecmwf_atmo0_5_2010-08-09_00.nc
END_DIGEST_CONTENT

my $digest_file = "$FindBin::Bin/../data/MetNo/nc_files_to_digest.txt";
open my $DIGEST, '>', $digest_file;
print $DIGEST $digest_content;
close $DIGEST;

{
    my $file_to_test = "ecmwf_atmo0_5_2010-08-09_00.xml";
    my $baseline_file = "$baseline_dir/$file_to_test";
    my $out_file = "$out_dir/$file_to_test";

    #remove any previous version of the out file since the order of some values will be
    # different in the second run
    unlink $out_file;
    digest( $digest_file, 'DAM', $out_file );

    TODO: {
        local $TODO = "Cannot compare MM2 files as strings as element ordering is random in perl 5.18";
        compare_ok( $baseline_file, $out_file, 'Parsing NC file' );
    }

    #print STDERR "Compared files:\n  $baseline_file\n  $out_file:\n";

    BEGIN { $num_tests += 1 }
}

BEGIN { plan tests => $num_tests };

