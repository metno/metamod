#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;

use lib "$FindBin::Bin/../../";

my $num_tests = 0;

use Test::PerformanceRegression;
use Test::Builder::Tester;
use Test::More;

my $fast_sub = sub {
    my $i = 0;
    for (1 .. 10 ){
        $i += $_;
    }
    return $i
};

my $slow_sub = sub {
    my $i = 0;
    for (1 .. 1_000_000 ){
        $i += $_;
    }
    return $i        
};

# tests for perf_ok
{
    
    my $perf = Test::PerformanceRegression->new();
    
    test_out('ok 1 # skip Result of pre tests failed. No reason to check performance');
    $perf->perf_ok( sub { return }, undef, 'empty sub 2' );
    test_test( 'perf_ok(): pre test value is false' );

    test_out('ok 1 # skip Result of pre tests failed. No reason to check performance');
    $perf->perf_ok( sub { return (1,2); }, sub { return $_[0] == $_[1] }, 'empty sub 3' );
    test_test( 'perf_ok(): pre test code returns false' );
    
    my $tag = 'perf_ok()';
    test_out('ok 1 # skip Have no previous performance result');    
    $perf->perf_ok( $slow_sub, 1, $tag );
    test_test( 'perf_ok(): no previous result.' );    

    # update the numbers
    $perf->_write_result();
    $perf->previous_result( $perf->_read_result() );

    test_out('ok 1 - Performance of perf_ok()');    
    $perf->perf_ok( $fast_sub, 1, $tag );
    test_test( 'perf_ok(): Previous result and is faster' );    
    
    # remove the old result.
    Test::PerformanceRegression::remove_performance_log();

    # update the numbers
    $perf->_write_result();
    $perf->previous_result( $perf->_read_result() );

    test_out('ok 1 # skip Have no previous performance result');    
    $perf->perf_ok( $fast_sub, 1, $tag );
    test_test( 'perf_ok(): no previous result.' );    
    
    # update the numbers
    $perf->_write_result();
    $perf->previous_result( $perf->_read_result() );

    test_out('not ok 1 - Performance of perf_ok()');
    test_err( qr/.*/xism );    
    $perf->perf_ok( $slow_sub, 1, $tag );    
    test_test( 'perf_ok(): Previous result and is slower' );    
    
    BEGIN { $num_tests += 6 }
}


# tests for statistic_perf_ok
{
    
    my $perf = Test::PerformanceRegression->new();
    
    test_out('ok 1 # skip Result of pre tests failed. No reason to check performance');
    $perf->statistic_perf_ok( sub { return }, undef, 'empty sub 2' );
    test_test( 'statistic_perf_ok(): pre test value is false' );

    test_out('ok 1 # skip Result of pre tests failed. No reason to check performance');
    $perf->statistic_perf_ok( sub { return (1,2); }, sub { return $_[0] == $_[1] }, 'empty sub 3' );
    test_test( 'statistic_perf_ok(): pre test code returns false' );
    
    my $tag = 'statistic_perf_ok()';
    test_out('ok 1 # skip Have no previous performance result');    
    $perf->statistic_perf_ok( $slow_sub, 1, $tag );
    test_test( 'statistic_perf_ok(): no previous result.' );    

    # update the numbers
    $perf->_write_result();
    $perf->previous_result( $perf->_read_result() );

    test_out('ok 1 - Performance of statistic_perf_ok()');    
    $perf->statistic_perf_ok( $fast_sub, 1, $tag );
    test_test( 'statistic_perf_ok(): Previous result and is faster' );    
    
    # remove the old result.
    Test::PerformanceRegression::remove_performance_log();

    # update the numbers
    $perf->_write_result();
    $perf->previous_result( $perf->_read_result() );

    test_out('ok 1 # skip Have no previous performance result');    
    $perf->statistic_perf_ok( $fast_sub, 1, $tag );
    test_test( 'statistic_perf_ok(): no previous result.' );    
    
    # update the numbers
    $perf->_write_result();
    $perf->previous_result( $perf->_read_result() );

    test_out('not ok 1 - Performance of statistic_perf_ok()');
    test_err( qr/.*/xism );    
    $perf->statistic_perf_ok( $slow_sub, 1, $tag );    
    test_test( 'statistic_perf_ok(): Previous result and is slower' );    
    
    BEGIN { $num_tests += 6 }
}

BEGIN { plan tests => $num_tests }

END {
    # ensure that the performance log is deleted.
    Test::PerformanceRegression::remove_performance_log();    
}