#!/usr/bin/perl -w

=begin LICENSE

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

=end LICENSE
=cut

use strict;
use warnings;
use File::Spec;
use File::Find qw();
# small routine to get lib-directories relative to the installed file
sub getTargetDir {
    my ($finalDir) = @_;
    my ($vol, $dir, $file) = File::Spec->splitpath(__FILE__);
    $dir = $dir ? File::Spec->catdir($dir, "..") : File::Spec->updir();
    $dir = File::Spec->catdir($dir, $finalDir);
    return File::Spec->catpath($vol, $dir, "");
}

use FindBin;
use lib ("$FindBin::Bin/../../common/lib", getTargetDir('lib'), getTargetDir('scripts'), '.');

use Metamod::Dataset;
use Metamod::DatasetImporter;
use Metamod::DatasetTransformer::ToISO19115 qw(foreignDataset2iso19115);
use Metamod::Config qw(:init_logger);
use Metamod::Subscription;
use Log::Log4perl qw();
use Metamod::Utils qw();
use Data::Dumper;
use DBI;
use XML::LibXML::XPathContext;
use File::Spec qw();
use mmTtime;

my $config = new Metamod::Config();
my $logger = Log::Log4perl->get_logger('metamod.base.import_dataset');

#
#  Import datasets from XML files into the database.
#
#  With no command line arguments, this program will enter a loop
#  while monitoring a number of directories (@importdirs) where XML files are
#  found. As new XML files are created or updated in these directories,
#  they are imported into the database. The loop will continue as long as
#  you terminate the process.
#
#  With one command line argument, the program will import the XML file
#  given by this argument.
#

# wait-time between re-checking files
my $sleeping_seconds = $config->get('IMPORT_DATASET_WAIT_SECONDS');
if ( $config->get('TEST_IMPORT_SPEEDUP') > 1 ) {
    $sleeping_seconds = 0; # don't wait in test-case
}
if (!defined $sleeping_seconds or $sleeping_seconds < 0) {
    $sleeping_seconds = 600; # default 10minutes
}
my $importdirs_string          = $config->get("IMPORTDIRS");
my @importdirs                 = split( /\n/, $importdirs_string );
my $path_to_import_updated     = $config->get("WEBRUN_DIRECTORY").'/import_updated';
my $path_to_import_updated_new = $config->get("WEBRUN_DIRECTORY").'/import_updated.new';
my $path_to_logfile            = $config->get("LOG4ALL_SYSTEM_LOG");

#
#  Check number of command line arguments
#
if ( scalar @ARGV > 2 ) {
    die "\nUsage:\n\n   Import single XML file:     $0 filename\n"
      . "   Import a directory:         $0 directory\n"
      . "   Infinite monitoring loop:   $0\n"
      . "   Infinite daemon monitor:    $0 logfile pidfile\n\n";
}
my $inputfile;
my $inputDir;

# should subscription be activated or not. We do not want to activate subscriptions
# when the metabase is re-indexed i.e. the script is running in batch mode.
my $activateSubscriptions = 0;

if( @ARGV == 0 ){
    $activateSubscriptions = 1;
} elsif ( @ARGV == 1 ) {
    if ( -f $ARGV[0] ) {
        $inputfile = $ARGV[0];
    }
    elsif ( -d $ARGV[0] ) {
        $inputDir = $ARGV[0];
    }
    else {
        die "Unknown inputfile or inputdir: $ARGV[0]\n";
    }
} elsif ( @ARGV == 2 ) {
    $activateSubscriptions = 1;
    Metamod::Utils::daemonize($ARGV[0], $ARGV[1]);
}
our $SIG_TERM = 0;
sub sigterm {++$SIG_TERM;}
$SIG{TERM} = \&sigterm;

#
if ( defined($inputfile) ) {

    #
    #  Evaluate block to catch runtime errors
    #  (including "die()")
    #
    my $dbh = $config->getDBH();
    eval { &update_database($inputfile, $dbh); };

    #
    #  Check error string returned from eval
    #  If not empty, an error has occured
    #
    if ($@) {
        $logger->error("$inputfile (single file) database error: $@\n");
        $dbh->rollback or die $dbh->errstr;
    }
    else {
        $dbh->commit or die $dbh->errstr;
        $logger->info("$inputfile successfully imported (single file)\n");
    }
    $dbh->disconnect;
}
elsif ( defined($inputDir) ) {
   process_directories(-1, $inputDir);
}
else {
    &process_xml_loop();
}

# ------------------------------------------------------------------
sub process_xml_loop {

    #
    #  Infinite loop that checks for new or modified XML files as long as
    #  SIG_TERM (standard kill, Ctrl-C) has not been called.
    #
    $logger->info("Check for new datasets in @importdirs\n");
    while ( ! $SIG_TERM ) {

#    The file $path_to_import_updated was last modified in the previous
#    turn of this loop. All XML files that are modified later are candidates
#    for import in the current turn of the loop.
#    Get the modification time corresponding to the previous turn of the loop:
#
        my @status = stat($path_to_import_updated);
        if ( scalar @status == 0 ) {
            $logger->logdie("Could not stat $path_to_import_updated\n");
        }
        my $last_updated = $status[9];    # Seconds since the epoch
        my $checkTime = time();
        process_directories($last_updated, @importdirs);
        utime($checkTime, $checkTime, $path_to_import_updated)
            or die "Cannot touch $path_to_import_updated";
        sleep($sleeping_seconds);
    }
    $logger->info("Check for new datasets stopped\n");
}

# callback function from File::Find for directories
sub processFoundFile {
    my ($dbh, $last_updated) = @_;
    my $file = $File::Find::name;
    if ($file =~ /\.xm[ld]$/ and -f $file and (stat(_))[9] >= $last_updated) {
        $logger->info("$file -accepted\n");
        my $basename = substr $file, 0, length($file)-4; # remove .xm[ld]
        if ($file eq "$basename.xml" and -f "$basename.xmd" and (stat(_))[9] >= $last_updated) {
            # ignore .xml file, will be processed together with .xmd file
        } else {
            # import to database
            eval { &update_database( $file, $dbh ); };
            if ($@) {
                $dbh->rollback or $logger->logdie( $dbh->errstr . "\n");
                my $stm = $dbh->{"Statement"};
                $logger->error("$file database error: $@\n   Statement: $stm\n");
            }
            else {
                $dbh->commit or $logger->logdie( $dbh->errstr . "\n");
                $logger->info("$basename successfully imported\n");
            }
        }
    }
}

sub process_directories {
    my ($last_updated,@dirs) = @_;

    my $dbh = $config->getDBH();
    foreach my $xmldir (@dirs) {
        my $xmldir1          = $xmldir;
        $xmldir1 =~ s/^ *//g;
        $xmldir1 =~ s/ *$//g;
        my @files_to_consume;
        if ( -d $xmldir1 ) {
            # xm[ld] files newer than $last_updated
            File::Find::find({wanted => sub {processFoundFile($dbh, $last_updated)},
                              no_chdir => 1},
                              $xmldir1);
        }
    }
    # disconnect database after done work
    $dbh->disconnect;
}

# ------------------------------------------------------------------
sub update_database {
    my ($inputBaseFile, $dbh) = @_;

    my $importer = Metamod::DatasetImporter->new();
    $importer->write_to_database($inputBaseFile);

    return;
}