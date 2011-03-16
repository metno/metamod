use strict;
use warnings;
use Test::More;
use Test::WWW::Mechanize::Catalyst;

use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../lib";
use lib "$FindBin::Bin/../../../common/lib";

use MetamodWeb::Test::Helper;

my $helper;

BEGIN {

    $helper = MetamodWeb::Test::Helper->new();
    $helper->setup_environment();

}

my $success = $helper->populate_userbase("$FindBin::Bin/access_control.sql");
if( !$success ){
    plan skip_all => "Failed to populate the userbase: " . $helper->errstr();
}

plan tests => 12;


my $mech = Test::WWW::Mechanize::Catalyst->new( catalyst_app => 'MetamodWeb' );
$mech->get_ok( '/userprofile', 'Un-authenticated access to userprofile' );

$mech->content_contains( '<input type="submit" value="Login" />', 'Redirected to login page' );

$mech->post_ok( '/login/authenticate', { username => 'dummy', password => 'dummy' }, 'Login with invalid username' );

$mech->content_contains( '<input type="submit" value="Login" />', 'On login page after unsuccessfull login' );

$mech->post_ok( '/login/authenticate', { username => 'test', password => 'test' }, 'Login with valid username' );

$mech->get_ok( '/userprofile', 'Fetchin user profile' );

$mech->content_contains( 'User information', 'User information page displayed' );

$mech->get_ok( '/logout', 'Logging out user' );

$mech->get_ok( '/userprofile', 'Fetching user profile for logged out user' );

$mech->content_contains( '<input type="submit" value="Login" />', 'Redirected to login page when accessing user profile' );

$mech->post_ok( '/login/authenticate', { username => 'test', password => 'test', return_path => '/userprofile' }, 'Login with return path' );

$mech->content_contains( 'User information', 'User information page displayed after login with return path' );

