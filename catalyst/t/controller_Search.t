use strict;
use warnings;
use Test::More tests => 3;
use Test::WWW::Mechanize::Catalyst;

use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../common/lib";

BEGIN { use_ok 'MetamodWeb' }
BEGIN { use_ok 'MetamodWeb::Controller::Search' }

my $mech = Test::WWW::Mechanize::Catalyst->new(catalyst_app => 'MetamodWeb');
$mech->get_ok( '/search', 'Request should succeed' );

