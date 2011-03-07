#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use Cwd;
use FindBin;
use File::Find;

use lib "$FindBin::Bin/../lib";

eval "use Test::Pod::Coverage 1.04";
plan skip_all => 'Test::Pod::Coverage 1.04 required' if $@;
plan skip_all => 'set TEST_POD to enable this test' unless $ENV{TEST_POD};


# since the all_modules() does not handle that you run the test script from
# other location than one above t/ we must find the modules our selves.
my @modules = ();
my $start_dir = "$FindBin::Bin/../lib/";
find(\&wanted, $start_dir );

sub wanted {

    return if !( $_ =~ /.*\.pm$/ );

    # remove the start directory part
    my $filepath = $File::Find::name;
    $filepath =~ s/$start_dir//;
    $filepath =~ s/ \/ /::/xg;
    $filepath =~ s/.pm$//;

    push @modules, $filepath;

}


#my @modules = all_modules(Cwd::realpath("$FindBin::Bin/../lib"));
foreach my $m ( @modules ){
    pod_coverage_ok( $m, "Pod coverage for $m" );
}

