#!/usr/bin/perl -w

=begin licence

--------------------------------------------------------------------------
METAMOD - Web portal for metadata search and upload

Copyright (C) 2011 met.no

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
use Getopt::Long;
use Pod::Usage;

use FindBin;
use lib ("$FindBin::Bin/../../common/lib", '.');

use TheSchwartz;
use Metamod::Queue;
use Metamod::Config;

=head1 NAME

B<add_file_to_queue.pl> - enter job for upload_monitor to process given file

=head1 DESCRIPTION

Used for re-processing uploaded NetCDF files (or tarballs of such), or for testing

=head1 USAGE

  add_file_to_queue.pl [ --config <dir> ] <ncfile> ...

=cut

# Parse cmd line params
my $config_file_or_dir;
GetOptions ('config=s' => \$config_file_or_dir) or pod2usage(1);

if(!Metamod::Config->config_found($config_file_or_dir)){
    print STDERR "Could not find the configuration on the commandline or the in the environment\n";
    exit 3;
}
my $mm_config = Metamod::Config->new($config_file_or_dir);

my $queue = Metamod::Queue->new( 'mm_config' => $mm_config);

pod2usage(1) unless @ARGV;

foreach my $ncfile (@ARGV) {
    $queue->insert_job(
        job_type => 'Metamod::Queue::Worker::Upload',
        job_parameters => { file => "$ncfile", type => 'INDEX' }, # what about TAF, FTP?
    ) && print STDERR "File $ncfile added to processing queue.\n"
    or die "Could not add $ncfile to processing queue!\n";
}
