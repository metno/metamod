#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;
use FindBin;

use lib "$FindBin::Bin/../../../";

use Metamod::Config;
use MetNo::NcDigest qw( digest );

my $num_tests = 0;
use Test::More;
use Test::Files;
use Test::PerformanceRegression;

BEGIN {
    plan skip_all => 'unset NO_PERF_TESTS to run performance tests' if $ENV{NO_PERF_TESTS};
}

my $config = Metamod::Config->new("$FindBin::Bin/../../master_config.txt");
$config->initLogger();

my $out_dir = "$FindBin::Bin/xml_output/xml_output";
my $baseline_dir = "$FindBin::Bin/../../data/MetNo"; # dir with the correct xml files

my $perf = Test::PerformanceRegression->new();
my $digest_file = "$FindBin::Bin/../../data/MetNo/nc_files_to_digest.txt";

{
    my $file_to_test = "ecmwf_atmo0_5_2010-08-09_00.xml";
    my $baseline_file = "$baseline_dir/$file_to_test";
    my $out_file = "$out_dir/$file_to_test";

    my $test_content = sub {
        return compare_ok( $baseline_file, $out_file, 'Nc works' );
    };

    my $run_digest = sub {

        #remove any previous version of the out file since the order of some values will be
        # different in the second run
        unlink $out_file;
        digest( "$FindBin::Bin/..", $digest_file, 'DAM', $out_file );
    };

    $perf->statistic_perf_ok( $run_digest, $test_content, 'digest()' );

    BEGIN { $num_tests += 2 }
}

BEGIN { plan tests => $num_tests };

