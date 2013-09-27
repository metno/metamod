#! /usr/bin/perl -w

=begin LICENCE

----------------------------------------------------------------------------
  METAMOD - Web portal for metadata search and upload

  Copyright (C) 2013 met.no

  Contact information:
  Norwegian Meteorological Institute
  Box 43 Blindern
  0313 OSLO
  NORWAY
  email: geir.aalberg@met.no

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
----------------------------------------------------------------------------

=end LICENCE

=cut

use strict;
use warnings;
use FindBin qw($Bin);
use Getopt::Long;
use Pod::Usage;
use POSIX;

my ($verbose, $update);
GetOptions(
    'verbose|v!'  => \$verbose,   # print yadda yadda
    'update|u!'   => \$update,    # update VERSION file from changelog (written to STDOUT)
) or pod2usage(1);
die "Only one -u or -v option allowed" if $verbose && $update;

my $mmVersion = "$Bin/../VERSION";
my $changeLog = "$Bin/changelog";

# read changelog
my ($chMajorVersion, $chMinorVersion);
open (my $ch, $changeLog) or die "Cannot read $changeLog: $!";
while (defined (my $line = <$ch>)) {
    if ($line =~ /metamod-(\d+\.\w+)\s+\((.+)\)/) {
        $chMajorVersion = $1;
        $chMinorVersion = $2;
        last;
    }
}
close $ch;
print "Version is ", $chMinorVersion || $chMajorVersion, "\n" if $verbose;
die "no changelog version" unless $chMajorVersion;

# read VERSION
my ($mmMajorVersion, $mmMinorVersion, $out);
my $date = strftime("%Y-%m-%d", localtime);
open (my $mh, $mmVersion) or die "Cannot read $mmVersion: $!";
while (defined (my $line = <$mh>)) {
    if ($line =~ /version (\d+\.\w+)(\.[^ ]+) of METAMOD/) {
        $mmMajorVersion = $1;
        $mmMinorVersion = "$1$2";
        if ($update) {
            $out = "This is version $chMinorVersion of METAMOD released $date\n";
        } else {
            last;
        }
    } else {
        $out .= $line;
    }
}
close $mh;
print "VERSION is ", $mmMinorVersion || $mmMajorVersion, "\n" if $verbose;
die "no VERSION version" unless $mmMajorVersion;

if ($update) {
    # write VERSION
    open ($mh, '>', $mmVersion) or die "Cannot read $mmVersion: $!";
    print $mh $out;
    close $mh;
} else {
    die "version mismatch between $mmVersion and $changeLog: $mmMajorVersion <=> $chMajorVersion"
        unless $chMajorVersion eq $mmMajorVersion;
}
exit 0;

=head1 NAME

B<checkVersion.pl> - compare/update METAMOD version numbers

=head1 DESCRIPTION

Compares version numbers between debian/changelog and ./VERSION,
optionally updating the latter.

VERSION is the authorative source of the release version number,
available via Metamod::Config::version().

=head1 USAGE

 checkVersion.pl -v | -u

=head1 AUTHOR

Heiko Klein, E<lt>heikok@met.noE<gt>

Geir Aalberg, E<lt>geira@met.noE<gt>

=head1 LICENSE

Copyright (C) 2010 The Norwegian Meteorological Institute.

METAMOD is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

=cut
