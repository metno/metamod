#!/usr/bin/env perl

use FindBin;
use lib "$FindBin::Bin/../../common/lib";

use strict;
use warnings;
use TheSchwartz;

use Metamod::Config;
use Metamod::Worker::PrepareDownload;

if ( 1 != @ARGV ) {
    print "usage: $0 <path to master_config.txt>\n";
    exit 1;
}

my $master_config = shift @ARGV;
$ENV{METAMOD_MASTER_CONFIG} = $master_config;

my $mm_config    = Metamod::Config->new($master_config);
my $queue_worker = TheSchwartz->new(
    databases => [
        {
            dsn  => $mm_config->getDSN_Userbase(),
            user => $mm_config->get('PG_WEB_USER'),
            pass => $mm_config->get('PG_WEB_USER_PASSWORD')
        }
    ]
);

$queue_worker->can_do('Metamod::Worker::PrepareDownload');
$queue_worker->work();
