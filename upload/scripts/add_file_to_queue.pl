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

# small routine to get lib-directories relative to the installed file
sub getTargetDir {
    my ($finalDir) = @_;
    my ( $vol, $dir, $file ) = File::Spec->splitpath(__FILE__);
    $dir = $dir ? File::Spec->catdir( $dir, ".." ) : File::Spec->updir();
    $dir = File::Spec->catdir( $dir, $finalDir );
    return File::Spec->catpath( $vol, $dir, "" );
}

use lib ( getTargetDir('lib'), getTargetDir('scripts'), '../../common/lib' );
use TheSchwartz;
use Metamod::Queue;
use Metamod::Config;

# Parse cmd line params
my $config_file_or_dir;
GetOptions ('config=s' => \$config_file_or_dir) or usage();

if(!Metamod::Config->config_found($config_file_or_dir)){
    print STDERR "Could not find the configuration on the commandline or the in the environment\n";
    exit 3;
}
my $mm_config = Metamod::Config->new($config_file_or_dir);

my $queue = Metamod::Queue->new( 'mm_config' => $mm_config);

if (scalar @ARGV != 1) {
   die "\nUsage:\n\n     $0 abs_path_to_ncfile\n\n";
}
my $abs_path_to_ncfile = $ARGV[0];
my $success = $queue->insert_job(
    job_type => 'Metamod::Queue::Worker::Upload',
    job_parameters => { file => "$abs_path_to_ncfile", type => 'INDEX' }, # TAF, FTP
);

if( ! $success ){
    die "Could not add $abs_path_to_ncfile to processing queue!\n";
}

sub usage {
    print "usage: $0 [ --config <configpath> ] [ --pid <pidfile> ] [ --log <logfile> ] \n";
    exit 1;
}
