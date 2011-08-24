use strict;
use warnings;

use Test::More tests => 3;
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
BEGIN { use_ok 'MetamodWeb::Controller::Dataset' }

my $mech = Test::WWW::Mechanize::Catalyst->new(catalyst_app => 'MetamodWeb');

$mech->get( '/dataset' );
ok( $mech->success(), 'Fetching dataset/ should return a page' );

