#! /usr/bin/perl -w
# Small helper-script to generate a test-input set of XML data files
# It will generate a tar file of all xml/xmd parent files and max 5 xml/xmd child files per parent. 
#
# the results need to be manuall post processed
# the list needs to be added/exchanged manually
#
#----------------------------------------------------------------------------
#  METAMOD - Web portal for metadata search and upload
#
#  Copyright (C) 2008 met.no
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
use strict;
use warnings;

use Getopt::Std qw(getopts);
use File::Temp qw(tempfile);
use File::Find qw(find);
use File::Spec;
use Cwd qw(abs_path);

use vars qw(%Opts %XmlFiles $TopLevelDir);

sub printUsage {
	my ($msg, $exitVal) = @_;
    my $prg = $0;
    $prg =~ s:.*/::;
    print STDERR <<"EOT";
usage: $prg -d inputdirectory -o tarfile.tgz [-h]

EOT
    print $msg, "\n" if ($msg);
    exit($exitVal);
}

getopts("d:o:h", \%Opts) or printUsage(undef, 2);
printUsage() if ($Opts{h});
printUsage("missing input-directory -d", 2) unless $Opts{d} && -d $Opts{d};
$TopLevelDir = abs_path($Opts{d});
find (\&wanted, $TopLevelDir);

# print join "\n", map {"$_ => " . scalar @{ $XmlFiles{$_} }}sort keys %XmlFiles;

# generate file list
my ($fh, $filename) = tempfile(UNLINK => 1);
foreach my $key (keys %XmlFiles) {
	my $fileBaseName = $key;
	$fileBaseName =~ s:^\Q$TopLevelDir\E/?::;
	print $fh "$fileBaseName.xml\n";
	print $fh "$fileBaseName.xmd\n";
	my $childCount = 0;
	foreach my $child (@{ $XmlFiles{$key} }) {
		last if $childCount++ >= 5;
		$child =~ s:^\Q$TopLevelDir\E/?::;
        print $fh "$child.xml\n";
        print $fh "$child.xmd\n";
	}
}
close $fh;
my @tar = ("tar", "cvfz", $Opts{o}, "-C$TopLevelDir", "--files-from", $filename);
print "@tar\n";
system(@tar);


sub wanted {
	if (-f && /(.*)\.xmd$/) {
		my $name = $1;
		my $xml = $1 . '.xml';
		if (-f $xml) {
			# proper metadata file-pair, check for parent
			my $parentName = $name;
			$parentName =~ s/\_.*//;
			my $parentDir = File::Spec->updir;
			my $fullName = abs_path(File::Spec->catfile($File::Find::dir, $name));
			if (-f File::Spec->catfile($parentDir, "$parentName.xmd")) {
				my $fullParentName = abs_path(File::Spec->catfile($parentDir, $parentName));
				push @{ $XmlFiles{$fullParentName} }, $fullName
			} elsif (!exists $XmlFiles{$fullName}) {
                $XmlFiles{$fullName} = [];
            }
		}
	} 
}