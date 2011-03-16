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
plan skip_all => 'unset NO_TEST_POD to enable this test' if $ENV{NO_TEST_POD};


# since the all_modules() does not handle that you run the test script from
# other location than one above t/ we must find the modules our selves.
my @modules = ();
my $start_dir = "$FindBin::Bin/../lib/";
find(\&wanted, $start_dir );

plan tests => scalar @modules;

#my @modules = all_modules(Cwd::realpath("$FindBin::Bin/../lib"));
foreach my $m ( @modules ){

    # there is no requirement to document auto, begin and end since their meaning is defined
    # by Catalyst
    pod_coverage_ok( $m, { also_private => [ qr/^(auto)|(begin)|(end)$/ ] }, "Pod coverage for $m" );
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
