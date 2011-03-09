#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

# required so that Pod::Coverage can find the modules
use FindBin;
use lib "$FindBin::Bin/..";


use File::Find;

eval "use Test::Pod::Coverage 1.04";
plan skip_all => 'Test::Pod::Coverage 1.04 required' if $@;
plan skip_all => 'set TEST_POD to enable this test' unless $ENV{TEST_POD};


# since the all_modules() does not handle that you run the test script from
# other location than one above t/ we must find the modules our selves.
my @modules = ();
my $start_dir = "$FindBin::Bin/../";
find(\&wanted, $start_dir );

plan tests => scalar @modules;

foreach my $m ( @modules ){
    pod_coverage_ok( $m, "Pod coverage for $m" );
}

sub wanted {

    return if !( $_ =~ /.*\.pm$/ );

    # remove the start directory part
    my $filepath = $File::Find::name;
    $filepath =~ s/$start_dir//;
    $filepath =~ s/ \/ /::/xg;
    $filepath =~ s/.pm$//;

    push @modules, $filepath;

}

