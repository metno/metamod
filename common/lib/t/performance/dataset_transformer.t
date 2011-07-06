#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../";

use Data::Dumper;
use Metamod::Config;
use Test::PerformanceRegression;
use Metamod::ForeignDataset;
use Metamod::DatasetTransformer;

$ENV{METAMOD_SOURCE_DIRECTORY} = "$FindBin::Bin/../../../..";

my $config = Metamod::Config->new("$FindBin::Bin/../master_config.txt");
$config->initLogger();

my $num_tests = 0;
use Test::More;

BEGIN {
    plan skip_all => 'unset NO_PERF_TESTS to run performance tests' if $ENV{NO_PERF_TESTS};
}




my $perf = Test::PerformanceRegression->new();
my $data_dir = "$FindBin::Bin/../data/performance";

# performance tests for MM2 files
{
    my $mm2_file = "$data_dir/mm2";

    my $autodetect_sub = sub {
        my $transformer = Metamod::DatasetTransformer::autodetect($mm2_file);
        return $transformer;
    };

    my $autodetect_check = sub {
        my ($transformer) = @_;
        return isa_ok( $transformer, 'Metamod::DatasetTransformer::MM2', '$transformer' );
    };

    $perf->statistic_perf_ok( $autodetect_sub, $autodetect_check, 'MM2 autodetect()' );

    my $transformer = Metamod::DatasetTransformer::autodetect($mm2_file);
    $perf->statistic_perf_ok( sub { $transformer->transform(); }, 1, 'MM2 transform()', );

    BEGIN { $num_tests += 3 }
}

# performance test for DIF files
{
    my $dif_file = "$data_dir/dif";

    my $autodetect_sub = sub {
        my $transformer = Metamod::DatasetTransformer::autodetect($dif_file);
        return $transformer;
    };

    my $autodetect_check = sub {
        my ($transformer) = @_;
        return isa_ok( $transformer, 'Metamod::DatasetTransformer::DIF', '$transformer' );
    };

    $perf->statistic_perf_ok( $autodetect_sub, $autodetect_check, 'DIF autodetect()' );

    my $transformer = Metamod::DatasetTransformer::autodetect($dif_file);
    $perf->statistic_perf_ok( sub { $transformer->transform(); }, 1, 'DIF transform()', );

    BEGIN { $num_tests += 3 }

}

BEGIN { plan tests => $num_tests }