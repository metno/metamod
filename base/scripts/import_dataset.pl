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
use FindBin;
use Getopt::Long;
use Log::Log4perl qw();
use Log::Log4perl::CommandLine qw(:all :noinit);
use Data::Dumper;
use Pod::Usage;
use lib ("$FindBin::Bin/../../common/lib", '.');
use Metamod::DatasetImporter;
use Metamod::Config;

=head1 NAME

B<import_dataset.pl> - Import an dataset or a directory with datasets into the metadata database

=head1 DESCRIPTION

Imports an XML file or a directory of metadata XML files inthe the metadata database.

=head1 USAGE

  import_dataset.pl <file or dir> [options]

Options:

=over 4

=item --config

Path to application directory or application config file.

=item --verbose | -v

Set loglevel to INFO

=item --debug | -d

Set loglevel to DEBUG

=item --warn

Set loglevel to WARN

=item --error

Set loglevel to ERROR

=item --quiet | -q

Set loglevel to OFF

=back

Note that the --config option may come before the filename/directory argument, but the loglevel
options must come after or they will eat up the next argument.

=head1 TODO

Rewrite so can call Metamod::DatasetImporter directly to import file instead of via shell

=cut

#print STDERR Dumper \@ARGV;

my $config_file_or_dir = $ENV{METAMOD_MASTER_CONFIG};
my $verbose = 0;

GetOptions('config=s' => \$config_file_or_dir, # don't fail in case set in ENV
           'verbose|v'  => \$verbose);

if(!Metamod::Config->config_found($config_file_or_dir)){
    pod2usage(1);
}

if ( scalar @ARGV != 1 ) { # allow multiple file names? TODO
    pod2usage(1);
}

my $config = Metamod::Config->new($config_file_or_dir);

my $logger = Log::Log4perl->get_logger('metamod.base.import_dataset');
Log::Log4perl::CommandLine::handlelogoptions();

my $inputfile;
my $inputDir;
if ( -f $ARGV[0] ) {
    $inputfile = $ARGV[0];
}
elsif ( -d $ARGV[0] ) {
    $inputDir = $ARGV[0];
}
else {
    die "Unknown inputfile or inputdir: $ARGV[0]\n";
}

if ( defined($inputfile) ) {

    #  Evaluate block to catch runtime errors (including "die()")
    my $dbh = $config->getDBH();
    eval { update_database($inputfile); };

    #  Check error string returned from eval
    #  If not empty, an error has occured
    if ($@) {
        print STDERR "Error while importing $inputfile : $@\n";
        $logger->error("$inputfile (single file) database error: $@");
        $dbh->rollback or die $dbh->errstr;
    }
    else {
        $dbh->commit or die $dbh->errstr;
        $logger->info("$inputfile successfully imported (single file)");
    }
    $dbh->disconnect;
}
elsif ( defined($inputDir) ) {
   process_directories($inputDir);
}


# callback function from File::Find for directories
sub process_found_file {
    my ($dbh) = @_;
    my $file = $File::Find::name;
    if ($file =~ /\.xm[ld]$/ and -f $file) {
        $logger->info("$file -accepted");
        my $basename = substr $file, 0, length($file)-4; # remove .xm[ld]
        if ($file eq "$basename.xml" and -f "$basename.xmd") {
            # ignore .xml file, will be processed together with .xmd file
        } else {
            # import to database
            eval { update_database( $file ); };
            if ($@) {
                $dbh->rollback or $logger->logdie( $dbh->errstr );
                $logger->error("$file database error: $@");
                if ( my $stm = $dbh->{"Statement"} ) {
                    $logger->error("SQL Statement: < $stm > ");
                }
            }
            else {
                $dbh->commit or $logger->logdie( $dbh->errstr );
                $logger->info("$basename successfully imported");
            }
        }
    }
}

sub process_directories {
    my (@dirs) = @_;

    my $dbh = $config->getDBH();
    foreach my $xmldir (@dirs) {
        my $xmldir1          = $xmldir;
        $xmldir1 =~ s/^ *//g;
        $xmldir1 =~ s/ *$//g;
        my @files_to_consume;
        if ( -d $xmldir1 ) {
            # xm[ld] files newer than $last_updated
            File::Find::find({wanted => sub {process_found_file($dbh)},
                              no_chdir => 1},
                              $xmldir1);
        }
    }
    # disconnect database after done work
    $dbh->disconnect;
}

# ------------------------------------------------------------------
sub update_database {
    my ($inputBaseFile) = @_;
    printf STDERR "Importing %s\n", $inputBaseFile if $verbose;

    my $importer = Metamod::DatasetImporter->new();
    $importer->write_to_database($inputBaseFile); # dies on failure

    return;
}

=head1 SEE ALSO

L<Metamod::DatasetImporter>

=head1 AUTHOR

Heiko Klein, E<lt>heikok@met.noE<gt>

=head1 LICENSE

Copyright (C) 2008 The Norwegian Meteorological Institute.

METAMOD is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

=cut
