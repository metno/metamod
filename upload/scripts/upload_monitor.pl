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

# small routine to get lib-directories relative to the installed file
sub getTargetDir {
    my ($finalDir) = @_;
    my ( $vol, $dir, $file ) = File::Spec->splitpath(__FILE__);
    $dir = $dir ? File::Spec->catdir( $dir, ".." ) : File::Spec->updir();
    $dir = File::Spec->catdir( $dir, $finalDir );
    return File::Spec->catpath( $vol, $dir, "" );
}

use FindBin;
use lib ( "$FindBin::Bin/../../common/lib", getTargetDir('lib'), getTargetDir('scripts') );


use TheSchwartz;
use Metamod::Utils;
use Metamod::Queue::Worker::Upload;
use Metamod::Config;


=head1 NAME

upload_monitor.pl

=head1 DESCRIPTION

Monitor web file uploads from data providers via event queue.
Start digest_nc.pl on uploaded files.

=head1 USAGE

See Metamod::UploadMonitor (rewrite - FIXME)

=cut

my $config = Metamod::Config->new();

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
    if ( $ARGV[0] && $ARGV[0] eq 'test' ) {

        print STDERR "Testrun: " . $ARGV[0] . "\n";
        $queue_worker->can_do('Metamod::Queue::Worker::Upload');
        $queue_worker->work_until_done(); # built-in TheSchwartz method, exiting when job queue is empty

    } elsif(0 == @ARGV) {

        print STDERR "Not running as daemon. Stop me with Ctrl + C\n";
        $queue_worker->can_do('Metamod::Queue::Worker::Upload');
        $queue_worker->work();

    } else {

        my ($logFile, $pidFile) = @ARGV;
        Metamod::Utils::daemonize($logFile, $pidFile);
        $SIG{TERM} = \&sigterm;
        $queue_worker->can_do('Metamod::Queue::Worker::Upload');
        $queue_worker->work();

    }
};

if ($@) {
    &syserrorm( "SYS", "ABORTED: " . $@, "", "", "" );
} else {
    &syserrorm( "SYS", "NORMAL TERMINATION", "", "", "" );
}

# not sure if this is still necessary...
our $SIG_TERM = 0;
sub sigterm { ++$SIG_TERM; }
$SIG{TERM} = \&sigterm;

# END
