use strict;
use warnings;
use Test::More tests => 3;
use Test::WWW::Mechanize::Catalyst;

BEGIN { use_ok 'MetamodWeb' }
BEGIN { use_ok 'MetamodWeb::Controller::Logout' }

my $mech = Test::WWW::Mechanize::Catalyst->new(catalyst_app => 'MetamodWeb');
$mech->get_ok('/logout', 'Request should succeed' );