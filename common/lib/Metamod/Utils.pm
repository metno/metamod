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

package Metamod::Utils;
use base qw(Exporter);
our $VERSION = 0.2;

@EXPORT_OK = qw(findFiles isNetcdf trim getFiletype);

use File::Find qw();

sub findFiles {
   my ($dir, @funcs) = @_;
   my @files;
   
   File::Find::find(sub {-f && _execFuncs($_, @funcs) && push @files, $File::Find::name;}, $dir);
   return @files;
}

sub _execFuncs {
	my ($file, @funcs) = @_;
	foreach my $func (@funcs) {
		return 0 unless $func->($file);
	}
	return 1;
}

# name, offset, magic-number
my %magicNumber = (
    'gzip' => [0, pack("C2", 0x1f, 0x8b)],
    'bzip2' => [0, "BZh"],
    'gzip-compress' => [0, pack("C2", 0x1f, 0x9d)],
    'pkzip' => [0, pack("C4", 0x50, 0x4b, 0x03, 0x04)], # PK..
    'tar' => [257, "ustar"],
    'nc3' => [0, "CDF\1"],
);
sub getFiletype {
	my ($filename) = @_;
	# simple 'file' replacement
	if ($filename =~ /\.tar$/i) {
		return 'tar'; # pre-posix tar files don't have a magic number
	}
	if (-T $filename) {
		return 'ascii'
	}
	open (my $f, $filename) or die "Cannot read $filename: $!";
	my $maxLength = sysread($f, my $buffer, 1024); # setting 1024 as max offset
	foreach my $type (keys %magicNumber) {
		my ($offset, $magic) = @{$magicNumber{$type}};
		if ((length($magic) + $offset) < $maxLength) {
			if (substr($buffer, $offset, length($magic)) eq $magic) {
				return $type;
			}  
		}
	}
	return "";
}

sub isNetcdf {
    return getFiletype(@_) eq 'nc3';
}

sub trim {
	my ($str) = @_;
	$str =~ s/^\s+//;
	$str =~ s/\s+$//;
	return $str;
}

1;
__END__

=head1 NAME

Metamod::Utils - utilities for metamod

=head1 SYNOPSIS

  use Metamod::Utils qw(findFiles isNetcdf trim);
  
  my @files = findFiles('/tmp');
  my @numberFiles = findFiles('/tmp', sub {$_[0] =~ m/^\d/});

  # precompile pattern with variables
  foreach my $var (qw(.x .y .z)) {
  	   my @files = findFiles('/tmp', eval 'sub{$_[0] =~ m/$var$/o}');
  	   print scalar @files , " files ending with $var\n";
  }

  if (isNetcdf("file.nc")) {
  	   # ... do something with a nc file
  }
  
  my $trimmed = trim("  string  "); # $trimmed = "string"
  
  
=head1 DESCRIPTION

This modules is a collection of small functions useful when working with Metamod.
The functions are listed below:

=over 8

=item findFiles($dir, [@callbacks]])

Return all files in the directory. The each callback-function will be called with
the filename as $_[0] parameter. All callbacks need to return true for the file.
The callbacks have in addition access to the following variables: $File::Find::name and 
$File::Find::dir. In addition the perl-special _ filehandle is set due to a previously checked -f.
See stat or -X in L<perlfunc>.

An example follows:

  my %files;
  foreach my $appendix (qw(.xml .xmd)) {
     $files{$appendix} = findFiles('/dir',
                                   sub {$_[0] =~ /$appendix$/o},
                                   sub {-x _});
  }

The o flag of the pattern will make sure, that the pattern is only compiled once for
each time the sub is compiled (that is twice), instead of for each file. Only executables
will be selected.


=item isNetcdf($file)

Checks if a file is a netcdf file by checking the first 3 bytes (magic-key) of the file to be CDF.
It will die if the file is not readable.

=item getFiletype($file)

get the filetype of a file. Supported files are: nc3, gzip, gzip-compressed, bzip2, pkzip,
ascii and tar

ascii detection works with perls -T option
tar detection uses file-extension only for pre-POSIX tar (normally the case)

=item trim($str)

Remove leading and trailing strings. Return string. Does not change inline.

=back

=head1 AUTHOR

Heiko Klein, E<lt>H.Klein@met.noE<gt>

=head1 SEE ALSO

L<File::Find>

=cut

