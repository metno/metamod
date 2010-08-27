#! -*- perl -*-
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

use FindBin;
use lib "$FindBin::Bin/../";

use Test::More tests => 16;

BEGIN {use_ok('Metamod::Utils', qw(findFiles isNetcdf trim getFiletype remove_cr_from_file));}

my $DataDir = $FindBin::Bin . '/data/';


my @allFiles = findFiles($FindBin::Bin);
ok((0 < grep {$_ =~ /00_Utils.t/} @allFiles), "finding 00_Utils.t in all");
my @numberFiles = findFiles($FindBin::Bin, sub {$_[0] =~ /^\d/});
ok((0 < grep {$_ =~ /00_Utils.t/} @numberFiles), "finding 00_Utils.t in files starting with number");
foreach my $var (qw(.pl .t)) {
   my @files = findFiles($FindBin::Bin, eval 'sub {$_[0] =~ /\Q$var\E$/o;}');
   if ($var eq ".pl") {
      ok((0 == grep {$_ =~ /00_Utils.t/} @files), "not finding 00_Utils.t in files ending with .pl");
   } elsif ($var eq ".t") {
      ok((0 < grep {$_ =~ /00_Utils.t/} @files), "finding 00_Utils.t in files ending with .t");
   }
}
chmod 0755, $FindBin::Bin.'/00_Utils.t';
my $var = '.t';
my @execFiles = findFiles($FindBin::Bin, eval 'sub {$_[0] =~ /\Q$var\E$/o;}', sub {-x _});
is(scalar @execFiles, 1, "00_Utils.t only executable .t - file");

ok(isNetcdf($DataDir."test.nc"), "test.nc is netcdf");
ok(!isNetcdf($FindBin::Bin."/00_Utils.t"), "00_Utils.t is no netcdf");

ok(getFiletype($DataDir."test.nc") eq "nc3", "test.nc filetype is nc3");
ok(getFiletype($DataDir."test.gz") eq "gzip", "test.gz filetype is gzip");
ok(getFiletype($DataDir."test.bz2") eq "bzip2", "test.bz2 filetype is bzip2");
ok(getFiletype($DataDir."test.zip") eq "pkzip", "test.nc filetype is pkzip");
ok(getFiletype($FindBin::Bin."/00_Utils.t") eq "ascii", "00_Utils.t is ascii");

is(trim("\nhallo\t "), "hallo", "trim");

ok(remove_cr_from_file('does_not_exist'), 'error when removing from n.e. file');
{
    my $testFile = $FindBin::Bin.'/remove_cr_from_file.txt';
    open my $fh, ">$testFile" or die "Cannot write $testFile: $!\n";
    print $fh "\rbla\r\nstring\r\nb\r\rla\r";
    close $fh;
    remove_cr_from_file($testFile);
    open $fh, $testFile or die "Cannot read $testFile: $!\n";
    local $/;
    my $data = <$fh>;
    close $fh;
    is($data, "bla\nstring\nbla", 'remove_cr_from_file');
    unlink $testFile;
}