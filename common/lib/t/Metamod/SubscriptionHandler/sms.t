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

use Test::More;
use Test::Files;

use Metamod::Config qw( :init_logger );
use Metamod::Dataset;
use Metamod::SubscriptionHandler::SMS;

my $num_tests;

$ENV{METAMOD_SUBSCRIPTION_SMS_DIRECTORY} = $FindBin::Bin;

{
    test__ds_file_name( 'DAMOC/itp04/itp04_itp4grd0013', 'itp04_itp4grd0013', 'Standard name' );

    test__ds_file_name( 'DAMOC\itp04\itp04_itp4grd0013', undef, 'Incorrect format' );

    BEGIN { $num_tests += 2 }

}

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

{
    my $dataset_file = "$FindBin::Bin/../../data/Metamod/SubscriptionHandler/itp04_itp4grd0013";
    my $ds           = Metamod::Dataset->newFromFile($dataset_file);

    my $location = '/dummy/file';
    my $handler = Metamod::SubscriptionHandler::SMS->new();
    my $ini_file = "$FindBin::Bin/itp04_itp4grd0013.ini";

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

BEGIN { plan tests => $num_tests }

sub test__ds_file_name {
    my ( $ds_name, $expected, $testname ) = @_;

    my $handler = Metamod::SubscriptionHandler::SMS->new();
    my $result  = $handler->_ds_file_name($ds_name);

    is( $result, $expected, "_ds_file_name: $testname" );

}
