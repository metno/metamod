#!/usr/bin/perl -w

use FindBin;
use lib "$FindBin::Bin/../../common/lib";
use lib "$FindBin::Bin/../lib";

use strict;
use warnings;
use Getopt::Long;
use TheSchwartz;

use Log::Log4perl qw(:easy get_logger);
Log::Log4perl->easy_init($DEBUG);

use Metamod::Config;
use Metamod::Utils;
use Metamod::Queue::Worker::PrepareDownload;


# Parse cmd line params
my ($pid, $errlog, $ownertag);
GetOptions ('pid|p=s' => \$pid,     # name of pid file - if given, run as daemon
            'log|l=s' => \$errlog,  # optional, redirect STDERR and STDOUT here
) or usage();

# init config + logger
my $master_config = shift @ARGV or usage();
my $mm_config    = Metamod::Config->new($master_config);
my $log = get_logger('metamod.basket');

# setup queue
my $queue_worker = TheSchwartz->new(
    databases => [
        {
            dsn  => $mm_config->getDSN_Userbase(),
            user => $mm_config->get('PG_WEB_USER'),
            pass => $mm_config->get('PG_WEB_USER_PASSWORD')
        }
    ]
);

# now we're ready for demonization
if ($pid) {
    # start daemon
    eval { Metamod::Utils::daemonize($errlog, $pid); };
    if ($@) {
        $log->fatal($@);
    } else {
        $log->info("prepare_download daemon started successfully");
    }
}


our $SIG_TERM = 0;
sub sigterm {++$SIG_TERM;}
$SIG{TERM} = \&sigterm;

eval {
    $queue_worker->can_do('Metamod::Queue::Worker::PrepareDownload');
    $queue_worker->work();
};
if ($@) {
    $log->error($@);
}


# END

sub usage {
    print "usage: $0 <path to master_config.txt>\n";
    exit 1;
}
