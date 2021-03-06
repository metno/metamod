#!/usr/bin/perl -w

=begin licence

--------------------------------------------------------------------------
METAMOD - Web portal for metadata search and upload

Copyright (C) 2008 met.no

Contact information:
Norwegian Meteorological Institute
Box 43 Blindern
0313 OSLO
NORWAY
email: egil.storen@met.no

This file is part of METAMOD

METAMOD is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

METAMOD is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with METAMOD; if not, write to the Free Software
Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
--------------------------------------------------------------------------

=end licence

=cut

use strict;
use warnings;
use File::Spec;

use FindBin;
use lib ( "$FindBin::Bin/../../common/lib", );

use Getopt::Long;
use Pod::Usage;
use TheSchwartz;

use Metamod::Utils;
use Metamod::Queue::Worker::Upload;
use Metamod::Config;
use Metamod::UploadHelper;

=head1 NAME

upload_monitor.pl

=head1 DESCRIPTION

Monitor web file uploads from data providers via event queue.
Start digest_nc.pl on uploaded files.

=head1 USAGE

upload_monitor.pl [ --test | --pidfile <path> ] [ --logfile <path> ] [ --config <path> ]

=over

=item --config

Path to the configuration (file or dir). Mandatory unless set via environment variable.

=item --pidfile

Path to the pid file to use when running in daemon mode. Also requires --logfile

=item --logfile

Path to the log file to use (mandatory when running in daemon mode, otherwise optional if/when implemented)

=item --test

Run the script in test mode.

=back

=cut

my $test;
my $logfile;
my $pidfile;
my $config_file_or_dir;

GetOptions ('pidfile|p=s'   => \$pidfile,                # name of pid file - if given, run as daemon
            'logfile|l=s'   => \$logfile,                # optional, redirect STDERR and STDOUT here
            'config=s'      => \$config_file_or_dir,     # path to config dir/file
            'test!'         => \$test,                   # dry run
) or pod2usage();

if(!Metamod::Config->config_found($config_file_or_dir)){
    pod2usage "Could not find the configuration on the commandline or the in the environment\n";
}

if( $pidfile && !$logfile){
    pod2usage("You must specify both --logfile and --pidfile when running in daemon mode");
}

my $config = Metamod::Config->new($config_file_or_dir);
my $upload_helper = Metamod::UploadHelper->new();

# setup queue
my $queue_worker = TheSchwartz->new(
    databases => [
        {
            dsn  => $config->getDSN_Userbase(),
            user => $config->get('PG_WEB_USER'),
            pass => $config->get('PG_WEB_USER_PASSWORD')
        }
    ]
);

eval {
    if ($test) {

        print STDERR "Testrun\n";
        $queue_worker->can_do('Metamod::Queue::Worker::Upload');
        $queue_worker->work_until_done(); # built-in TheSchwartz method, exiting when job queue is empty

    } elsif ($pidfile) {

        print STDERR "Daemonizing upload monitor (see $logfile)\n";
        Metamod::Utils::daemonize($logfile, $pidfile);
        $queue_worker->can_do('Metamod::Queue::Worker::Upload');
        $queue_worker->work();

    } else {

        print STDERR "upload monitor: Not running as daemon. Stop me with Ctrl + C\n";
        $queue_worker->can_do('Metamod::Queue::Worker::Upload');
        $queue_worker->work();
    }
};

if ($@) {
    $upload_helper->syserrorm( "SYS", "ABORTED: " . $@, "", "", "" );
} else {
    $upload_helper->syserrorm( "SYS", "NORMAL TERMINATION", "", "", "" );
}


# END
