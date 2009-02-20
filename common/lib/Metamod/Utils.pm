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

@EXPORT_OK = qw(findFiles);

use File::Find qw();

sub findFiles {
   my ($dir, $pattern) = @_;
   my @files;
   if ($pattern) {
      my $regex = qr/$pattern/; # precompile
        File::Find::find(sub {-f && /$regex/ && push @files, $File::Find::name;}, $dir);     
   } else {
      File::Find::find(sub {-f && push @files, $File::Find::name;}, $dir);
   }
   return @files;
}

1;
__END__

=head1 NAME

Metamod::Utils - utilities for metamod

=head1 SYNOPSIS

  use Metamod::Utils qw(findFiles);
  
  my @files = findFiles('/tmp');
  my @numberFiles = findFiles('/tmp', qr{^\d});

=head1 DESCRIPTION

This modules is a collection of small functions useful when working with Metamod.
The functions are listed below:

=over 8

=item findFiles($dir, [$pattern]])

Return all files in the directory, matching the otional pattern.
This uses internally File::Find. 

=back

=head1 AUTHOR

Heiko Klein, E<lt>H.Klein@met.noE<gt>

=head1 SEE ALSO

L<File::Find>

=cut

