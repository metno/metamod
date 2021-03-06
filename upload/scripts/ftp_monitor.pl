#!/usr/bin/perl -w

=begin LICENSE

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

=end LICENSE

=cut

use strict;
use warnings;
use File::Spec;
use FindBin;
use lib ("$FindBin::Bin/../../common/lib");
use Getopt::Long;
use POE qw(Component::Schedule);
use POE::Component::Cron;
use Metamod::Utils;
use Metamod::UploadHelper;
use Pod::Usage;

=head1 NAME

ftp_monitor.pl

=head1 DESCRIPTION

Monitor FTP file uploads from data providers. Start digest_nc.pl on
uploaded files.

=head1 USAGE

ftp_monitor.pl [ --test | --pidfile <path> ] [ --logfile <path> ] [ --config <path> ]

=over

=item --config

Path to the configuration (file or dir). Mandatory unless set via environment variable.

=item --pidfile

Path to the pid file to use. Runs in daemon mode, Also requires --logfile

=item --logfile

Path to the log file to use (mandatory when running in daemon mode, otherwise optional if/when implemented)

=item --test

Run the script in test mode (no loop)

=back

=head1 TODO

Rewrite to trap SIGINT in ftp_monitor - L<http://www.perlmonks.org/?node_id=93004>

=head1 SEE ALSO

L<Metamod::UploadHelper>

=cut


# Parse cmd line params
my ($pidfile, $logfile, $test, $config_file_or_dir);
GetOptions ('pidfile|p=s'   => \$pidfile,               # name of pid file - if given, run as daemon
            'logfile|l=s'   => \$logfile,               # optional, redirect STDERR and STDOUT here
            'config=s'      => \$config_file_or_dir,    # path to config dir/file
            'test!'         => \$test,                  # dry run
            'help'          => sub { pod2usage(1) },    # for the helpless
) or pod2usage(2);

if(!Metamod::Config->config_found($config_file_or_dir)){
    pod2usage "Could not find the configuration on the commandline or the in the environment\n";
}

if( $pidfile && !$logfile){
    pod2usage("You must specify both --logfile and --pidfile when running in daemon mode");
}

my $config = Metamod::Config->new($config_file_or_dir);
my $upload_helper = Metamod::UploadHelper->new();
my $logger = $upload_helper->logger;

# can we skip this now?
my $sleeping_seconds      = 60;
#if ( $config->has('TEST_IMPORT_SPEEDUP') and $config->get('TEST_IMPORT_SPEEDUP') > 1 ) {
#    $sleeping_seconds = 1;
#}

our $ok_to_run = 1;

eval {
    if ($test) {

        print STDERR "Testrun...\n";
        $upload_helper->ftp_process_hour();

    } elsif ($pidfile) {

        print STDERR "Daemonizing ftp monitor (see $logfile)\n";
        Metamod::Utils::daemonize($logfile, $pidfile);
        start_cronjob();

    } else {

        print STDERR "ftp monitor: Not running as daemon. Stop me with Ctrl + C\n";
        use sigtrap 'handler' => \&int_handler, 'INT';
        while( $ok_to_run ) {
            $upload_helper->ftp_process_hour();
            sleep $sleeping_seconds;
        }

    }
};
if ($@) {
    $upload_helper->syserrorm( "SYS", "ABORTED: " . $@, "", "", "" );
} else {
    $upload_helper->syserrorm( "SYS", "NORMAL TERMINATION", "", "", "" );
}

sub int_handler {
    print STDERR "Terminating ftp monitor\n";
    $ok_to_run = 0;
}

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

=head1 AUTHORS

Geir Aalberg, E<lt>geira\@met.noE<gt>,

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut
