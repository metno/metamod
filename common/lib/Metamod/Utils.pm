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
use strict; 
use warnings;

our $VERSION = do { my @r = (q$LastChangedRevision$ =~ /\d+/g); sprintf "0.%d", @r };

our @EXPORT_OK = qw(findFiles isNetcdf trim getFiletype remove_cr_from_file);

use File::Find qw();
use POSIX qw();

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
    'gzip' => [[0, pack("C2", 0x1f, 0x8b)]],
    'bzip2' => [[0, "BZh"]],
    'gzip-compress' => [[0, pack("C2", 0x1f, 0x9d)]],
    'pkzip' => [[0, pack("C4", 0x50, 0x4b, 0x03, 0x04)]], # PK..
    'tar' => [[257, "ustar"]],
    'nc3' => [[0, "CDF\1"], [0, "CDF\2"]],
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
        foreach my $magics (@{$magicNumber{$type}}) {
            my ($offset, $magic) = @$magics;
            if ((length($magic) + $offset) < $maxLength) {
                if (substr($buffer, $offset, length($magic)) eq $magic) {
                    return $type;
                }
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

sub remove_cr_from_file {
    my ($file) = @_;
    eval {
        my $backupFile = $file . "~";
        rename $file, $backupFile or die "Cannot rename $file $backupFile: $!";
        open my $inFH, "<$backupFile" or die "Cannot read $backupFile: $!";
        open my $outFH, ">$file" or die "Cannot write $file: $!"; 
        while (defined (my $line = <$inFH>)) {
            $line =~ tr/\r//d;
            print $outFH $line;
        }
        close $outFH;
        close $inFH;
        unlink $backupFile or die "Cannot unlink $backupFile: $!";
    };
    return $@;
}

sub daemonize {
    my ($logFile, $pidFile) = @_;
    # check if writing to pidFile is possible
    my $pidFH;
    if ($pidFile) {
       open $pidFH, ">$pidFile" or die "Cannot write pidfile $pidFile: $!";
    }
    my $logFH;
    if ($logFile) {
       open $logFH, ">>$logFile" or die "Cannot write logfile $logFile: $!";
    }
    my $pid;
    if ($pid = _Fork()) {exit 0;};
    POSIX::setsid()
        or die "Can't start a new session: $!";
    if ($pid = _Fork()) {exit 0;}; # fork twice / disable control-terminal
    if ($pidFH) {
        print $pidFH "$$\n";
        close $pidFH;
    }
    # close/redirect std filehandles
    open(STDIN,  "+>/dev/null"); # instead of closing
    if ($logFH) {
        open STDOUT, ">>&", $logFH or die "Can't redirect STDOUT to $logFile: $!";
    } else {
        open (STDOUT, ">/dev/null"); # instead of closing 
    }
    open STDERR, ">>&STDOUT" or die "Can't redirect STDERR: $!";
}

##---------------------------------------------------------------------------##
##  _Fork(): Try to fork if at all possible.  Function will croak
##  if unable to fork.
##
sub _Fork {
    my($pid);
    FORK: {
        if (defined($pid = fork)) {
            return $pid;
        } elsif ($! =~ /No more process/) {
            sleep 3;
            redo FORK;
        } else {
            die "Can't fork: $!";
        }
    }
}


1;
__END__

=head1 NAME

Metamod::Utils - utilities for metamod

=head1 SYNOPSIS

  use Metamod::Utils qw(findFiles isNetcdf trim);
  
  daemonize('/var/log/logfile','/var/pid/pidfile');
  
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

=item remove_cr_from_file($file)

remove \r from a file
returns error message on error, 0 on succes because it emulates a shell-script

=item trim($str)

Remove leading and trailing strings. Return string. Does not change inline.

=item daemonize($logFile, $pidFile)

Make the current process a daemon. Log all STDOUT and STDERR to $logFile, write the
generated pid to $pidFile.

=back

=head1 AUTHOR

Heiko Klein, E<lt>H.Klein@met.noE<gt>

=head1 SEE ALSO

L<File::Find>

=cut

