#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 2;

use Test::WWW::Mechanize::Catalyst;

use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../common/lib";
use lib "$FindBin::Bin/lib";

use MetamodWeb::Test::Helper;

my $helper;

BEGIN {
    $ENV{METAMOD_LOG4PERL_CONFIG} = "$FindBin::Bin/log4perl_config.ini";

    $helper = MetamodWeb::Test::Helper->new();
    $helper->setup_environment();
}

BEGIN { use_ok 'MetamodWeb' }

my $mech = Test::WWW::Mechanize::Catalyst->new(catalyst_app => 'MetamodWeb');

$mech->get_ok('/', 'Request should succeed' );


