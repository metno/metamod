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
    $helper = MetamodWeb::Test::Helper->new();
    $helper->setup_environment();
}

BEGIN { use_ok 'Catalyst::Test', 'MetamodWeb' }
BEGIN { use_ok 'MetamodWeb::Controller::Admin' }

ok( request('/admin')->is_success, 'Request should succeed' );
done_testing();
