#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;

use lib "$FindBin::Bin/../../";

use Test::PerformanceRegression;

use File::Find;
use Test::More;
use Test::Files;
use Test::Exception;

my $num_tests = 0;

# test of remove_performance_log 
{
    lives_ok { Test::PerformanceRegression::remove_performance_log() } "Removing non-existant file";
    
    my @original_files = dir_contents();
    open my $TMP, '>', Test::PerformanceRegression::_default_filename();
    print $TMP 'test';
    close $TMP;
    
    dir_contains_ok( $FindBin::Bin, [qw( performance_regression.t-perf.log ) ], 'Default log file created' );
    
    Test::PerformanceRegression::remove_performance_log();
    dir_only_contains_ok( $FindBin::Bin, \@original_files, 'Performance log removed' );
    
    BEGIN { $num_tests +=3 }
        
}

# test for _pre_test
{

    test__pre_test( undef, [], undef, 'Pre test is undef' );    

    test__pre_test( 1, [], 1, 'Pre test is 1' );    
    
    test__pre_test( sub { return; }, [], undef, 'Pre test func returns false' );
    
    test__pre_test( sub { return 1; }, [], 1, 'Pre test func returns true' );
    
    test__pre_test( sub { return 1 if $_[0] == $_[1]; return; }, [ 1, 2 ], undef, 'Pre test that takes parameters. Returns false' );
    
    test__pre_test( sub { return 1 if $_[0] == $_[1]; return; }, [ 3, 3 ], 1, 'Pre test that takes parameters. Returns true' );
    
    BEGIN { $num_tests += 6 }
}

BEGIN { plan tests => $num_tests };

END {
    #ensure that no junk performance log exists when ending test
    Test::PerformanceRegression::remove_performance_log();
}

sub dir_contents {

    my @files = ();
    my $start_path_length = length( $FindBin::Bin ) + 1;
    my $wanted = sub { 
        return if $_ eq '.';
        push @files, substr( $File::Find::name, $start_path_length );  
    };

    find( $wanted, $FindBin::Bin );
    
    return @files; 
    
}

sub test__pre_test {
    my ( $pre_test, $pre_test_args, $expected, $testname ) = @_;

    my $perf = Test::PerformanceRegression->new();    
    my $result = $perf->_run_pre_test( $pre_test, @$pre_test_args );
    
    is( $result, $expected, "_run_pre_test: $testname" );
    
}
