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
#
use strict;
use warnings;
use File::Path qw(mkpath);
use File::Spec;
use lib qw([==TARGET_DIRECTORY==]/lib);
use Metamod::Utils qw(findFiles isNetcdf trim);
use Metamod::Dataset;
use Metamod::DatasetTransformer;
use Metamod::Config;
my $config = new Metamod::Config;

use constant DEBUG => 0;

our $TARGETDIR      = $config->get('TARGET_DIRECTORY');
our $NCFILE_PREFIX  = File::Spec->catfile(trim($config->get('OPENDAP_DIRECTORY')), ""); # have directory-separator at end
our @PARENT_DIRS    = split (' ', $config->get('IMPORTDIRS'));
our $OPENDAP_PREFIX = trim($config->get('OPENDAP_URL'));
if (substr($OPENDAP_PREFIX, length($OPENDAP_PREFIX) -1) ne '/') {
	$OPENDAP_PREFIX .= '/';
}
our $ETCDIR         = File::Spec->catdir( $TARGETDIR, "etc" );
our $DIGESTNC   = File::Spec->catdir( $TARGETDIR, 'scripts', 'digest_nc.pl' );

if ( !-x $DIGESTNC ) {
	print STDERR "$0 needs to be called from the same directory as digest_nc.pl";
}

our $USAGE = <<EOT;
usage: $0 OUTPUT_XML_DIR
       $0 -i FILELIST OUTPUT_XML_DIR

example: $0 /tmp/testoutput
EOT

unless ( @ARGV == 1 || (@ARGV == 3 && $ARGV[0] eq '-i') ) {
	print STDERR $USAGE;
	exit 1;
}

our $OUTPUT_DIR;
our $FILELIST;
if (@ARGV == 1) {
   $OUTPUT_DIR = $ARGV[0];
} else {
   $OUTPUT_DIR = $ARGV[2];
   $FILELIST = $ARGV[1];
}
unless ( -d $NCFILE_PREFIX ) {
	print STDERR $USAGE, "\n";
	print STDERR "NCFILE_PREFIX $NCFILE_PREFIX: no such dir\n";
	exit 1;
}

if ($FILELIST) {
#
#  Slurp in the content of a file
#
   unless (-r $FILELIST) {die "Can not read from file: $FILELIST\n";}
   open (FLIST,$FILELIST);
   undef $/;
   my $pfiles = <FLIST>;
   chomp($pfiles);
   $/ = "\n"; 
   close (FLIST);
   my @parentFiles = split(/\s*\n\s*/m,$pfiles);
   &process_parentfiles(\@parentFiles);
} else {
   foreach my $parentDir (@PARENT_DIRS) {
	my @parentFiles = findFiles( $parentDir, sub { $_[0] =~ /\.xm[ld]$/; } );
	my %unique;
	@parentFiles = map {
		my $bn = Metamod::DatasetTransformer::getBasename($_);
		$unique{$bn}++ ? () : $_;
	} @parentFiles;
        &process_parentfiles(\@parentFiles);
   }
}

sub process_parentfiles {
        my ($ref_to_parentfiles) = @_;
	foreach my $parentFile (@$ref_to_parentfiles) {
		my $ds = Metamod::Dataset->newFromFile($parentFile);
		unless ($ds) {
			print STDERR "Cannot read dataset of $parentFile, skipping...\n";
			next;
		}
		if ( $ds->getParentName ) {
			next
			  ;  # dataset has parent => is child itself, no need to generate child
		}
		my %metadata = $ds->getMetadata;
		next unless exists $metadata{dataref};
		my $dataref = $metadata{dataref}[0];
        my $opendapURL = $OPENDAP_PREFIX . 'data/';
		if ( $dataref =~ s:^\Q$opendapURL\E:$NCFILE_PREFIX:o ) {
			if (!-d $dataref) {
				print STDERR "no such directory: $dataref, derifed from $OPENDAP_PREFIX, $NCFILE_PREFIX  $metadata{dataref}[0]";
				next;
			}
			# extract institution from original dataref, it is the first path after the general opendap url
			my $institution = $metadata{dataref}[0];
			$institution =~ s:\Q$opendapURL\E([^/]+)/.*:$1:o; 
			my @ncFiles = findFiles( $dataref, \&isNetcdf );
			foreach my $ncFile (@ncFiles) {
				my ( $vol, $directory, $file ) = File::Spec->splitpath($ncFile);
				my $freeFile = $file;
				$freeFile =~ s/\.[^.]+//;    # remove extension
				my %info = $ds->getInfo;
				my @parentDir = split '/', $info{name};
				my $xmlPath =
				  File::Spec->catfile( $OUTPUT_DIR, @parentDir, $freeFile . '.xml' );
				next if -f $xmlPath;
				mkpath( File::Spec->catdir( $OUTPUT_DIR, @parentDir ) );
				my $opendapRef = $ncFile;
				$opendapRef =~ s:\Q$NCFILE_PREFIX\E:$opendapURL:o;
				$opendapRef =~ s:[^/]+$::; # remove file
				$opendapRef .= 'catalog.html?dataset=' . join('/', $institution, $parentDir[-1], $file); 
				my $digestInput = "digest_input$$";
				open( my $digestFH, ">$digestInput" )
				  or die "Cannot write file $digestInput: $!\n";
				print $digestFH "$opendapRef\n";
				print $digestFH $ncFile, "\n";
				close $digestFH;
				my @command = (
					$DIGESTNC, $ETCDIR, $digestInput, $info{ownertag}, $xmlPath,
					"isChild"
				);
				if (DEBUG()) {
					print STDERR "@command\n";
					exit;
				}
				system(@command) == 0
				  or die "failed system-call: @command: $?\n";
				unlink $digestInput;
			}
		}
	}
}
