#!/usr/bin/perl -w

use FindBin;
use lib ("$FindBin::Bin/../../common/lib");

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
my ($pid, $errlog, $ownertag, $config_file_or_dir);
GetOptions ('pid|p=s' => \$pid,     # name of pid file - if given, run as daemon
            'log|l=s' => \$errlog,  # optional, redirect STDERR and STDOUT here
            'config=s' => \$config_file_or_dir,     # path to config dir/file
) or usage();

if(!Metamod::Config->config_found($config_file_or_dir)){
    print STDERR "Could not find the configuration on the commandline or the in the environment\n";
    exit 3;
}

# init config + logger
my $mm_config = Metamod::Config->new($config_file_or_dir);
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
    print "usage: $0 [ --config <configpath> ] [ --pid <pidfile> ] [ --log <logfile> ] \n";
    exit 1;
}
