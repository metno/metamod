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

use lib "..";
use Test::More tests => 7;

BEGIN {use_ok('Metamod::Utils', qw(findFiles isNetcdf trim));}

my @allFiles = findFiles('.');
ok((0 < grep {$_ =~ /00_Utils.t/} @allFiles), "finding 00_Utils.t in all");
my @numberFiles = findFiles('.', sub {$_[0] =~ /^\d/});
ok((0 < grep {$_ =~ /00_Utils.t/} @numberFiles), "finding 00_Utils.t in files starting with number");
foreach my $var (qw(.pl .t)) {
   my @files = findFiles('.', eval 'sub {$_[0] =~ /\Q$var\E$/o;}');
   if ($var eq ".pl") {
      ok((0 == grep {$_ =~ /00_Utils.t/} @files), "not finding 00_Utils.t in files ending with .pl");
   } elsif ($var eq ".t") {
      ok((0 < grep {$_ =~ /00_Utils.t/} @files), "finding 00_Utils.t in files ending with .t");
   }
}
my $var = '.t';
my @execFiles = findFiles('.', eval 'sub {$_[0] =~ /\Q$var\E$/o;}', sub {-x _});
is(scalar @execFiles, 1, "Utils.t only executable .t - file");

ok(isNetcdf("test.nc"), "test.nc is netcdf");
ok(!isNetcdf("00_Utils.t"), "test.nc is no netcdf");

is(trim("\nhallo\t "), "hallo", "trim");