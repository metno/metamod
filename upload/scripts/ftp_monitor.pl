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

use lib ( '../../common/lib', getTargetDir('lib'), getTargetDir('scripts') );

use POE qw(Component::Schedule);
use POE::Component::Cron;
use Metamod::Utils;
use Metamod::UploadHelper;

my $upload_helper = Metamod::UploadHelper->new();
my $logger = $upload_helper->logger;
my $config = $upload_helper->config;

=head1 NAME

ftp_monitor.pl

=head1 DESCRIPTION

Monitor FTP file uploads from data providers. Start digest_nc.pl on
uploaded files.

=head1 USAGE

See Metamod::UploadHelper

=cut

#  Action starts here:
#  -------------------

my $sleeping_seconds      = 60;
if ( $config->get('TEST_IMPORT_SPEEDUP') and $config->get('TEST_IMPORT_SPEEDUP') > 1 ) {
    $sleeping_seconds = 1;
}

eval {
    if ( $ARGV[0] && $ARGV[0] eq 'test' ) {
        print STDERR "Testrun: " . $ARGV[0] . "\n";
        main_loop( $ARGV[0] );
    } elsif(0 == @ARGV) {
        print STDERR "Not running as daemon. Stop me with Ctrl + C\n";
        #main_loop();
        #$upload_helper->get_dataset_institution(); # now run automatically by process_files
        $upload_helper->ftp_process_hour();
    } else {
        my ($logFile, $pidFile) = @ARGV;
        Metamod::Utils::daemonize($logFile, $pidFile);
        #$SIG{TERM} = \&sigterm;
        #&main_loop();
        start_cronjob();
    }
};
if ($@) {
    $upload_helper->syserrorm( "SYS", "ABORTED: " . $@, "", "", "" );
} else {
    $upload_helper->syserrorm( "SYS", "NORMAL TERMINATION", "", "", "" );
}

# let POE handle kills since custom event handlers don't work under it
#our $SIG_TERM = 0;
#sub sigterm { ++$SIG_TERM; }
#$SIG{TERM} = \&sigterm;

#
# ----------------------------------------------------------------------------
#
#sub main_loop {
#    my ($testrun) = @_;    # if test, always run, but only once
#    print STDERR "Starting main_loop...\n";
#
#    &init;
#
#    #
#    #  Loop which will continue until terminated SIG{TERM}.
#    #
#    #  For each new hour, the loop will check (in the ftp_process_hour
#    #  routine) if any FTP-processing are scheduled (looking in the %ftp_events hash).
#    #
#    #  After processing, the routine will wait until the system clock arrives at
#    #  a new fresh hour. Then the loop repeats, and new processing will eventually
#    #  be perfomed.
#    #
#
#    my @ltime         = localtime( mmTtime::ttime() );
#    my $current_day   = $ltime[3];                       # 1-31
#    my $hour_finished = -1;
#
#    while ( ( !$SIG_TERM ) || $testrun ) {
#        @ltime = localtime( mmTtime::ttime() );
#        my $newday       = $ltime[3];                    # 1-31
#        my $current_hour = $ltime[2];                    # 0-23
#        #printf STDERR "...looping...%s > %s?\n", $current_hour, $hour_finished;
#        if ( $current_day != $newday || ( $testrun && $testrun eq 'newday' ) ) {
#            &clean_up_problem_dir(); # move to separate job - FIXME
#            &clean_up_repository();  # move to separate job - FIXME
#            $file_in_error_counter = 1;
#            $hour_finished         = -1;
#            $current_day           = $newday;
#        }
#        if ( $current_hour > $hour_finished ) {
#            &get_dataset_institution( \%dataset_institution );
#            &ftp_process_hour( \%ftp_events, $current_hour );
#            @ltime         = localtime( mmTtime::ttime() );
#            $hour_finished = $ltime[2];                       # 0-23
#        }
#        if ($testrun) { last; }
#        sleep($sleeping_seconds);
#    }
#}

sub ftp_monitor {
    my ($kernel, $heap, $session) = @_[KERNEL, HEAP, SESSION];

    my $upload_helper = Metamod::UploadHelper->new();
    $logger->debug("FTP Monitor session " . $_[SESSION]->ID . " started at " . scalar(gmtime) . " UTC.");

    #$upload_helper->get_dataset_institution(); # now run automatically by process_files
    $upload_helper->ftp_process_hour();

    $logger->info("FTP Monitor session " . $_[SESSION]->ID . " finished.");

}

sub cleanup_dirs {
    my ($kernel, $heap, $session) = @_[KERNEL, HEAP, SESSION];

    $upload_helper->$logger->debug("Upload cleanup session " . $_[SESSION]->ID . " started at " . scalar(gmtime) . " UTC.");

    $upload_helper->clean_up_problem_dir();
    $upload_helper->clean_up_repository();

    $logger->info("Upload cleanup session " . $_[SESSION]->ID . " finished.");

}

sub start_cronjob { # not yet in use - will continue media july 2011 -ga

    my $crontab = $config->get('FTP_CRONTAB') || '30 04 * * *'; # FIXME - move to defaults

    my $monitor = POE::Session->create(
        inline_states => {
            _start    => sub {
                            $logger->info("FTP Monitor initialized with schedule $crontab");
                        },
            monitor   => \&ftp_monitor,
            _stop     => sub {
                            $logger->info("FTP Monitor session ", $_[SESSION]->ID, " has stopped.");
                        },
        }
    );

    my $sched = POE::Component::Cron->from_cron( $crontab => $monitor->ID => 'monitor' );

    # cleanup

    my $crontab2 = $config->get('CLEANUP_CRONTAB') || '15 00 * * *'; # FIXME - move to defaults

    my $cleanup = POE::Session->create(
        inline_states => {
            _start    => sub {
                            $logger->info("Upload cleanup initialized with schedule $crontab2");
                        },
            monitor   => \&cleanup_dirs,
            _stop     => sub {
                            $logger->info("Upload cleanup session ", $_[SESSION]->ID, " has stopped.");
                        },
        }
    );

    my $sched2 = POE::Component::Cron->from_cron( $crontab2 => $monitor->ID => 'cleanup' );

    POE::Kernel->run();

}
