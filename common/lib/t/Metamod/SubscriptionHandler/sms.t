#!/usr/bin/perl -w

use strict;

use FindBin;

use lib "$FindBin::Bin/../../lib";
use lib "$FindBin::Bin/../../..";

# must override the master config file to use here before use import modules that use the config file.
BEGIN {
    my $config_file = "$FindBin::Bin/../../master_config.txt";
    $ENV{METAMOD_MASTER_CONFIG} = $config_file unless exists $ENV{METAMOD_MASTER_CONFIG};
}

use Cwd qw( abs_path );
use Test::More;
use Test::Files;

use Metamod::Config qw( :init_logger );
use Metamod::Dataset;
use Metamod::SubscriptionHandler::SMS;
use Metamod::TestUtils qw( init_userdb_test empty_userdb );

my $num_tests;

$ENV{METAMOD_SUBSCRIPTION_SMS_DIRECTORY} = $FindBin::Bin;

init_userdb_test("$FindBin::Bin/sms_test_data.sql");

# tests for the _ds_file_name function.
{
    test__ds_file_name( 'DAMOC/itp04/itp04_itp4grd0013', 'itp04_itp4grd0013', 'Standard name' );

    test__ds_file_name( 'DAMOC\itp04\itp04_itp4grd0013', undef, 'Incorrect format' );

    BEGIN { $num_tests += 2 }

}

# tests for _notify_sms()
{
    my $handler = Metamod::SubscriptionHandler::SMS->new();

    my $filename    = "$FindBin::Bin/last_changed";
    my $file_exists = -e $filename;
    is( $file_exists, undef, 'last_changed file does not exist before tests are run' );

    $handler->_notify_sms();
    $file_exists = -e $filename;
    is( $file_exists, 1, 'last_changed created if it does not exist' );

    my @file_info = stat $filename;
    my $mod_time  = ( stat $filename )[8];
    cmp_ok( abs( $mod_time - time ), '<', 1, 'last_changed file modification time.' );

    diag('Sleeping a couple of seconds so testing updating modification time works.');
    sleep(3);

    $handler->_notify_sms();
    $mod_time = ( stat $filename )[8];
    cmp_ok( abs( $mod_time - time ), '<', 1, 'last_changed modification time updated.' );

    unlink $filename;

    BEGIN { $num_tests += 4 }

}

# test for push_to_subscribers
{
    my $dataset_file = "$FindBin::Bin/../../data/Metamod/SubscriptionHandler/itp02_itp2grd0040";
    add_location( 'itp02', "$FindBin::Bin/../../data/Metamod/SubscriptionHandler" );
    my $ds = Metamod::Dataset->newFromFile($dataset_file);

    my $location = "$FindBin::Bin/../../data/Metamod/SubscriptionHandler/itp02_itp2grd0040.nc";
    my $handler  = Metamod::SubscriptionHandler::SMS->new();
    my $ini_file = "$FindBin::Bin/itp02_itp2grd0040.ini";

    my $subscription = [ { server => 'blabla' }, ];

    my $success = $handler->push_to_subscribers( $ds, $subscription );
    is( $success, undef, 'Pushing to subscribers fails when none of the subscribers have valid params' );

    $subscription = [
        {
            server        => 'some server',
            username      => 'user',
            password      => 'password',
            transfer_type => 'ftp',
            ftp_type      => 'active',
            directory     => '',
            U_email       => 'metamod@met.no'
        },
    ];

    my $ini_content = <<END_INI;
[transfer]
filepath=$location
transfers=transfer_1

[transfer_1]
U_email=metamod\@met.no
directory=
ftp_type=active
password=password
server=some server
transfer_type=ftp
username=user
END_INI

    $success = $handler->push_to_subscribers( $ds, $subscription );
    is( $success, 1, 'Single transfer return value' );
    file_ok( $ini_file, $ini_content, 'Single transfer file content' );

    my $mod_time = ( stat "$FindBin::Bin/last_changed" )[8];
    cmp_ok( abs( $mod_time - time ), '<', 1, 'last_changed modification time when .ini file written.' );

    $subscription = [
        {
            server        => 'some server',
            username      => 'user',
            password      => 'password',
            transfer_type => 'ftp',
            ftp_type      => 'active',
            directory     => '',
            U_email       => 'metamod@met.no'
        },
        {
            server        => 'other server',
            username      => 'user2',
            password      => 'password',
            transfer_type => 'ftp',
            ftp_type      => 'passive',
            directory     => '/files',
            U_email       => 'metamod@met.no'
        },

    ];

    $ini_content = <<END_INI;
[transfer]
filepath=$location
transfers=transfer_1,transfer_2

[transfer_1]
U_email=metamod\@met.no
directory=
ftp_type=active
password=password
server=some server
transfer_type=ftp
username=user

[transfer_2]
U_email=metamod\@met.no
directory=/files
ftp_type=passive
password=password
server=other server
transfer_type=ftp
username=user2
END_INI

    $success = $handler->push_to_subscribers( $ds, $subscription );
    is( $success, 1, 'Multiple transfer return value' );
    file_ok( $ini_file, $ini_content, 'Multiple transfer file content' );

    $subscription = [
        {
            server        => 'some server',
            password      => 'password',
            transfer_type => 'ftp',
            ftp_type      => 'active',
            directory     => '',
            U_email       => 'metamod@met.no'
        },
        {
            server        => 'other server',
            username      => 'user2',
            password      => 'password',
            transfer_type => 'ftp',
            ftp_type      => 'passive',
            directory     => '/files',
            U_email       => 'metamod@met.no'
        },

    ];

    $ini_content = <<END_INI;
[transfer]
filepath=$location
transfers=transfer_1

[transfer_1]
U_email=metamod\@met.no
directory=/files
ftp_type=passive
password=password
server=other server
transfer_type=ftp
username=user2
END_INI

    $success = $handler->push_to_subscribers( $ds, $subscription );
    is( $success, 1, 'Invalid subscriptions are skipped' );
    file_ok( $ini_file, $ini_content, 'Invalid subscriptions are skipped, file content' );

    # remove created files
    unlink "$FindBin::Bin/last_changed";
    unlink $ini_file;

    BEGIN { $num_tests += 8 }

}

# tests for _join_location_dataset_path
{
    my $handler = Metamod::SubscriptionHandler::SMS->new();

    my $location     = '/vol/osisaf/data/archive/ice/drift_lr/single_sensor/amsr-aqua';
    my $dataset_path = 'osisaf/met.no/ice/drift_lr/single_sensor/amsr-aqua/2010/02/';
    $dataset_path .= 'ice_drift_nh_polstere-625_amsr-aqua_201002221200-201002241200.nc.gz';
    my $result = $handler->_join_location_dataset_path( $location, $dataset_path );
    my $expected =
'/vol/osisaf/data/archive/ice/drift_lr/single_sensor/amsr-aqua/2010/02/ice_drift_nh_polstere-625_amsr-aqua_201002221200-201002241200.nc.gz';

    is( $result, $expected, '_join_location_dataset_path: Test 1' );

    BEGIN { $num_tests += 1 }

}

# tests for _get_file_location
{

    my $data_files_base = "$FindBin::Bin/../../data/Metamod/SubscriptionHandler";
    my $handler         = Metamod::SubscriptionHandler::SMS->new();

    my $dataset_file = "$data_files_base/itp08_itp8grd0329";
    my $ds           = Metamod::Dataset->newFromFile($dataset_file);
    my $result       = $handler->_get_file_location($ds);
    is( $result, undef, '_get_file_location: Dataset not in user database' );

    $dataset_file = "$data_files_base/itp07_itp7grd0022";
    $ds           = Metamod::Dataset->newFromFile($dataset_file);
    $result       = $handler->_get_file_location($ds);
    is( $result, undef, '_get_file_location: Dataset has no location' );

    $dataset_file = "$data_files_base/itp05_itp5grd0236";
    $ds           = Metamod::Dataset->newFromFile($dataset_file);
    add_location( 'itp05', $data_files_base );
    $result = $handler->_get_file_location($ds);
    my $expected = "$data_files_base/itp05_itp5grd0236.nc";
    is( $result, $expected, '_get_file_location: Dataset has location and is not in sub dir' );

    $dataset_file = "$data_files_base/itp04_itp4grd0013";
    $ds           = Metamod::Dataset->newFromFile($dataset_file);
    add_location( 'itp04', $data_files_base );
    $result   = $handler->_get_file_location($ds);
    $expected = "$data_files_base/subdir/subdir2/itp04_itp4grd0013.nc";
    is( $result, $expected, '_get_file_location: Dataset has location and is in sub dir' );

    $dataset_file = "$data_files_base/itp03_itp3grd0170";
    $ds           = Metamod::Dataset->newFromFile($dataset_file);
    add_location( 'itp03', $data_files_base );
    $result = $handler->_get_file_location($ds);
    is( $result, undef, '_get_file_location: Dataset has location, but cannot be found' );

    BEGIN { $num_tests += 5 }

}

BEGIN { plan tests => $num_tests }

sub test__ds_file_name {
    my ( $ds_name, $expected, $testname ) = @_;

    my $handler = Metamod::SubscriptionHandler::SMS->new();
    my $result  = $handler->_ds_file_name($ds_name);

    is( $result, $expected, "_ds_file_name: $testname" );

}

sub add_location {
    my ( $ds_name, $location ) = @_;

    my $userbase = Metamod::mmUserbase->new();

    if ( !$userbase->dset_find( 'TEST', $ds_name ) ) {
        die "Could not find the dataset '$ds_name' in the user database";
    }

    $userbase->infoDS_put( 'LOCATION', "$location" );
    $userbase->close();

}

END {
    empty_userdb();
}
