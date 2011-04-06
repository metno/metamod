#  METAMOD - Web portal for metadata search and upload
#
#  Copyright (C) 2009 met.no
#
#  Contact information:
#  Norwegian Meteorological Institute
#  Box 43 Blindern
#  0313 OSLO
#  NORWAY
#  email: Heiko.Klein@met.no
#
#  This file is part of METAMOD
#
#  METAMOD is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  METAMOD is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with METAMOD; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#----------------------------------------------------------------------------

#
# This script fixes a bug introduced in Metamod::DatasetTransformer::DIF.pm v0.3:
#     timestamp has been introduced instead of datestamp
# It should be applied on all datasets created with that Transformer,
# that is all datasets retrieved by OAI-PMH 
#

use lib '../lib';
use constant USAGE => 'usage: fixDIFDatasetsIn2_1.pl BACKUP_DIR dataset1.xmd dataset2.xmd ...'; 

# The following versions make sure that the fixed versions are installed 
use Metamod::ForeignDataset 0.3;
use Metamod::DatasetTransformer::DIF 0.4;
use File::Spec;

if (@ARGV < 2 and (!-d $ARGV[0]) and (! -f $ARGV[1])) {
	print STDERR USAGE(), "\n";
	exit(1);
}

my $backupDir = shift @ARGV;

FILE: while (defined (my $file = shift @ARGV)) {
	my $ds;
    eval {$ds = Metamod::ForeignDataset->newFromFile(Metamod::DatasetTransformer::getBasename($file));};
    if ($@) {print STDERR "$@ in $file, skip ...\n"; next FILE;}
    unless ($ds) {
    	print STDERR "Couldn't parse/open dataset: $file\n";
    	next FILE;
    }
    my %info = $ds->getInfo;
    if ($info{timestamp}) {
    	# create backup
    	my ($volume,$directories,$filename) = File::Spec->splitpath( $file );
    	my $backupPath = File::Spec->catfile($backupDir, $filename);
    	eval {$ds->writeToFile($backupPath);};
    	if ($@) {
    		print STDERR "Cannot write backup to $backupPath ($@), skip ...\n";
    		next FILE;
    	}
    	
    	# fix datestamp to match format
    	unless ($info{datestamp}) {
    		$info{datestamp} = $info{timestamp};
    	}
    	if (length $info{datestamp} == 10) {
            $info{datestamp} .= 'T00:00:00Z';
        }
        if (length $info{datestamp} != 20) {
            warn "$date". $info{$date}." not in format YYYY-MM-DDTHH:MM:SSZ in $file\n";
        }
        
        # creationDate should have been set to datestamp if not existing
        # but was set to timestamp instead
        if ($info{creationDate} eq $info{timestamp}) {
        	$info{creationDate} = $info{datestamp}
        }
    	delete $info{timestamp};
    	
    	# create the new dataset
    	$ds->replaceInfo(\%info);
    	$ds->writeToFile($file);
    	print "fixed $file\n";
    }
}