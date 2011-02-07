use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'MetamodWeb' }
BEGIN { use_ok 'MetamodWeb::Controller::Admin' }

ok( request('/admin')->is_success, 'Request should succeed' );
done_testing();
