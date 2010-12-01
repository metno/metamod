#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 2;

use Test::WWW::Mechanize::Catalyst;

BEGIN { use_ok 'MetamodWeb' }

my $mech = Test::WWW::Mechanize::Catalyst->new(catalyst_app => 'MetamodWeb');

$mech->get_ok('/', 'Request should succeed' );


