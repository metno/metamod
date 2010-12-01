use strict;
use warnings;

use Test::More tests => 3;
use Test::Pod::Coverage;
use Test::WWW::Mechanize::Catalyst;

BEGIN { use_ok 'MetamodWeb' }
BEGIN { use_ok 'MetamodWeb::Controller::Dataset' }

my $mech = Test::WWW::Mechanize::Catalyst->new(catalyst_app => 'MetamodWeb');

$mech->get( '/dataset' );
ok( !$mech->success(), 'Fetching dataset/ should not return a page' );

#pod_coverage_ok( 'MetamodWeb::Controller::Dataset', 'Pod coverage ok' );