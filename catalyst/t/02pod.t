#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use FindBin;

eval "use Test::Pod 1.14";
plan skip_all => 'Test::Pod 1.14 required' if $@;
plan skip_all => 'unset NO_TEST_POD to enable this test' if $ENV{NO_TEST_POD};

all_pod_files_ok( all_pod_files( "$FindBin::Bin/../lib/" ) );
