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
our $VERSION = 0.1;

@EXPORT_OK = qw(findFiles isNetcdf);

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

sub isNetcdf {
	my ($file) = @_;
	my $fh;
	open ($fh, $file) or die "Cannot read $file: $!";
	my $buffer;
	if (sysread($fh, $buffer, 4) == 4) {
		if ($buffer eq "CDF\1") {
			return 1;
		}
	}
	return 0;
}

1;
__END__

=head1 NAME

Metamod::Utils - utilities for metamod

=head1 SYNOPSIS

  use Metamod::Utils qw(findFiles);
  
  my @files = findFiles('/tmp');
  my @numberFiles = findFiles('/tmp', sub {$_[0] =~ m/^\d/o});

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

=back

=head1 AUTHOR

Heiko Klein, E<lt>H.Klein@met.noE<gt>

=head1 SEE ALSO

L<File::Find>

=cut

