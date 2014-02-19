use strict;
use warnings;
use Test::More;

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

BEGIN { use_ok 'Catalyst::Test', 'MetamodWeb' }
BEGIN { use_ok 'MetamodWeb::Controller::Map' }

ok( request('/search/map_search')->is_success, 'Request should succeed' ); # where did /search/map come from?
done_testing();
