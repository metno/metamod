#!/usr/bin/perl -w
use strict;
my $fname = $ARGV[0];
#
#  Slurp in the content of a file
#
unless (-r $fname) {die "Can not read from file: $fname\n";}
open (FFF,$fname);
undef $/;
my $content = <FFF>;
$/ = "\n"; 
close (FFF);
#
#  Split string using regexp:
#
my @datasets = split(/<dataset>/m,$content);
#
# foreach value in an array
#
foreach my $dset (@datasets) {
   $dset =~ s/\n   /\n/mg;
#
#  Check if expression matches RE:
#
   if ($dset =~ /<drpath>DAMOC\/([^<]*)<\/drpath>/m) {
      my $xmlname = $1; # First matching ()-expression
      my $xmlfile = "$xmlname.xml";
#
#  Open file for writing
#
      open (XML,">$xmlfile");
      print XML "<dataset ownertag=\"DAM\">";
      print XML $dset;
      close (XML);
   }
}
