#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use FindBin;
use MetamodWeb;

eval "use Test::Pod::Coverage 1.04";
plan skip_all => 'Test::Pod::Coverage 1.04 required' if $@;
plan skip_all => 'set TEST_POD to enable this test' unless $ENV{TEST_POD};

#all_pod_coverage_ok( 'Full POD coverage' );

my @modules = all_modules('lib');
foreach my $m ( @modules ){
    pod_coverage_ok( $m, "Pod coverage for $m" );
}

