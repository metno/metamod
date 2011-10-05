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
use Data::Dumper;

use Metamod::Utils;
use Metamod::Queue;
use Metamod::Queue::Worker;
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

GetOptions('config=s' => , \$config_file_or_dir, 'test!' => \$test, 'logfile=s' => \$logfile, 'pidfile=s' => \$pidfile) or pod2usage();

if( !$config_file_or_dir ){
    pod2usage("Missing config file or directory");
}

if( $pidfile && !$logfile){
    pod2usage("You must specify both --logfile and --pidfile when running in daemon mode");
}

my $config = Metamod::Config->new($config_file_or_dir);
my $upload_helper = Metamod::UploadHelper->new();

# setup queue
my $queue_worker = Metamod::Queue::Worker->new( 'Metamod::Queue::Worker::Upload' );


eval {
    if ($test) {

        print STDERR "Testrun...\n";
        #$queue_worker->work_until_done();
        my $job = $queue_worker->get_a_job;
        #print STDERR Dumper $job;
        $queue_worker->wojk_once($job);

    } elsif($pidfile) {

        Metamod::Utils::daemonize($logfile, $pidfile);
        $queue_worker->wojk();

    } else {

        # running in foreground
        print STDERR "Not running as daemon. Stop me with Ctrl + C\n";
        $queue_worker->wojk();
    }
};

if ($@) {
    $upload_helper->syserrorm( "SYS", "ABORTED: " . $@, "", "", "" );
} else {
    $upload_helper->syserrorm( "SYS", "NORMAL TERMINATION", "", "", "" );
}


# END
