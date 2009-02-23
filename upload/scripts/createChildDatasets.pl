#!/usr/bin/perl -w
#
#---------------------------------------------------------------------------- 
#  METAMOD - Web portal for metadata search and upload 
# 
#  Copyright (C) 2009 met.no 
# 
#  Contact information: 
#  Norwegian Meteorological Institute 
#  Box 43 Blindern 
#  0313 OSLO 
#  NORWAY 
#  email: heiko.klein@met.no 
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

#
# create the child = file dataset files from the parent xml-files
#
# * parse parent xml files, find 'dataref' element, if this links to the known local
#   opendap-server, map the 'dataref' to the file-system file
# * run digset_nc on the child, output the file to the output-dir in the same structure 
#   as the parents
#
# THIS SCRIPT SHOULD ONLY BE RUN ONCE TO UPDATE THE OLD DATASETS. IT SHOULD THEREFOR NOT GET
# INSTALLED. FUTURE CHILD DATASET ARE GENERATED WITH NEWER VERSIONS OF upload_monitor.pl
#
use strict;
use warnings;
use File::Path qw(mkpath);
use File::Spec;
use lib qw(../../common/lib); 
use Metamod::Utils qw(findFiles isNetcdf);
use Metamod::Dataset;
use Metamod::DatasetTransformer;

our $ETCDIR = File::Spec->catdir("..", "etc");
our $DIGESTNC = "digest_nc.pl";

if (! -x $DIGESTNC) {
	print STDERR "$0 needs to be called from the same directory as digest_nc.pl";
}

our $USAGE = <<EOT;
usage: $0 PARENT_XML_DIR OPENDAP_PREFIX NCFILE_PREFIX OUTPUT_XML_DIR

example: $0 /metno/damocles/webrun_r2/XML http://damocles.met.no:8080/thredds/catalog/data /metno/damocles/data/data /tmp/testoutput
EOT

unless (@ARGV == 4) {
	print STDERR $USAGE;
	exit 1;
}

our ($PARENT_DIR, $OPENDAP_PREFIX, $NCFILE_PREFIX, $OUTPUT_DIR) = @_;
unless (-d $PARENT_DIR) {
	print STDERR $USAGE, "\n";
	print STDERR "PARENT_XML_DIR $PARENT_DIR: no such dir\n";
	exit 1;
}
unless (-d $NCFILE_PREFIX) {
   print STDERR $USAGE, "\n";
   print STDERR "NCFILE_PREFIX $NCFILE_PREFIX: no such dir\n";
   exit 1;
}

my @parentFiles = findFiles($PARENT_DIR, sub {$_[0] =~ /\.xm[ld]$/;});
my %unique;
@parentFiles = map {my $bn = Metamod::DatasetTransformer::getBasename($_); $unique{$bn}++ ? () : $_;} @parentFiles;
foreach my $parentFile (@parentFiles) {
   my $ds = Metamod::Dataset->newFromFile($parentFile);
   unless ($ds) {
   	print STDERR "Cannot read dataset of $parentFile, skipping...\n";
   	next;
   }
   if ($ds->getParentName) {
   	next; # dataset has parent => is child itself, no need to generate child
   }
   my %metadata = $ds->getMetadata;
   next unless exists $metadata{dataref};
   my $dataref = $metadata{dataref}[0];
   if ($dataref =~ s/^\Q$OPENDAP_PREFIX\E/$NCFILE_PREFIX/o) {
   	my @ncFiles = findFiles($dataref, \&isNetcdf);
   	foreach my $ncFile (@ncFiles) {
   		my ($vol, $directory, $file) = File::Spec->splitpath($ncFile);
   		$file =~ s/\.[^.]+//; # remove extension
   		my %info = $ds->getInfo;
   		my @parentDir = split '/', $info{name};
   		my $xmlPath = File::Spec->catfile($OUTPUT_DIR, @parentDir, $file . '.xml');
   		mkpath(File::Spec->catdir($OUTPUT_DIR, @parentDir));
         my $opendapRef = $ncFile;
         $opendapRef =~ s/\Q$NCFILE_PREFIX\E/$OPENDAP_PREFIX/o;
         my $digestInput = "digest_input$$";
         open (my $digestFH, ">$digestInput") or die "Cannot write file $digestInput: $!\n";
         print $digestFH , "\n";
         print $digestFH $ncFile, "\n";
         close $digestFH;
         my @command = ($DIGESTNC, $ETCDIR, $digestInput, $info{ownertag}, $xmlPath, "isChild");
         system(@command) == 0 
            or die "failed system-call: @command: $?\n";
         unlink $digestInput;
   	}
   }
}
