#!/usr/bin/perl -w

=begin LICENCE

----------------------------------------------------------------------------
  METAMOD - Web portal for metadata search and upload

  Copyright (C) 2008 met.no

  Contact information:
  Norwegian Meteorological Institute
  Box 43 Blindern
  0313 OSLO
  NORWAY
  email: egil.storen@met.no

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
use File::Copy;
use File::Path;
use File::Spec;
use FindBin qw($Bin);

use lib "$Bin/common/lib";
use Metamod::LoggerConfigParser;

#
#  Check command line arguments
#
my %commandline_options = (); # Hash containing commandline options of the form --opt or --opt=val
                              # $commandline_options{"--opt"} == "val" (or empty)
my $appdir;
my $argcount = 0; # Counts number of normal arguments (not containing '=')
my $optcount = 0; # Counts number of option arguments (containing '=')
foreach my $cmdarg (@ARGV) {
   if ($cmdarg =~ /^([^=]+)=(.*)$/) {
      my $opt = $1;
      my $val = $2;
      $commandline_options{$opt} = $val;
      $optcount++;
   } else {
      $appdir = $cmdarg;
      $argcount++;
   }
}
if ($argcount != 1 || ($optcount > 0 && $optcount != 2) ||
      ($optcount > 0 && !exists($commandline_options{'--from'})) ||
      ($optcount > 0 && !exists($commandline_options{'--to'}))) {
   die "\nUsage:\n\n1.     $0 application_directory\n\n" .
       "where 'application_directory' is the name of a directory containing the application\n" .
       "specific files. Inside this directory, there must be a master_config.txt file.\n\n" .
       "2.     $0 --from=sourcefile --to=targetfile application_directory\n\n" .
       "If these two options are present, the normal behaviour is suspended. The only thing\n" .
       "that happens are copying with substitutions (according to the master_config.txt file)" .
       "from the sourcefile to the targetfile.\n\n";
}
#
#   Read the configuration file:
#
my $configMaster = 'master_config.txt';
my $configfile = "$appdir/$configMaster";
my $appfilelist = $appdir . '/filelist.txt';
my $appName = (File::Spec->splitdir( $appdir))[-1];
my $version;
my $majorVersion;
{
    open my $verFH, "$Bin/VERSION" or die "cannot read VERSION-file at $Bin/VERSION: $!\n";
    while (defined (my $line = <$verFH>)) {
        if ($line =~ /version\s+(\d+\.\w+)\.(\w+)\s+/i) {
            $version = $1 . '.' . $2;
            $majorVersion = $1;
            last;
        }
    }
    unless (defined $majorVersion) {
        die "could not read version from VERSION file\n";
    }
}
if ($optcount == 0) { # Supress this message if only "copy with substitution" is done
   print "\nConfiguring application '$appName' with Metamod $majorVersion ($version)\n\n";
}

#######################
#
# Process master_config
#
my %conf;
my $missing_variables = 0;

#  Open config file for reading
my $config_modified = (stat($configfile))[9];
unless (-r $configfile) {die "Can not read from file: $configfile\n";}
open (CONFIG,$configfile);

my %newfilenames = ();
my $value = "";
my $varname = "";
my $origname = "";
my $newname = "";
my $line = "";

#  Loop through all lines in config file:
while (<CONFIG>) {
   chomp($_);
   $line = $_;

   # check for something (looks like we're closing a multi-line assignment?)
   if ($line =~ /^[A-Z0-9_#!]/ && $varname ne "") {
      if (length($origname) > 0) {
         $conf{$varname . ':' . $origname . ':' . $newname} = $value;
         $newfilenames{$origname . ':' . $newname} = 1;
      } else {
         $conf{$varname} = $value;
      }
      $varname = "";
   }

   if ($line =~ /^([A-Z0-9_]+)\s*=(.*)$/) {  # this looks like a single-line assignment
      $varname = $1; # First matching ()-expression
      $value = $2; # Second matching ()-expression
      $value =~ s/^\s*//;
      $value =~ s/\s*$//;
   } elsif ($line =~ /^!substitute_to_file_with_new_name\s+(\S+)\s+=>\s+(\S+)\s*$/) {
      $origname = $1;
      $newname = $2;
   } elsif ($line =~ /^!end_substitute_to_file_with_new_name\s*$/) {
      $origname = "";
      $newname = "";
   } elsif ($line !~ /^#/ && $line !~ /^\s*$/) {  # append value in multi-line assignment
      $value .= "\n" . $line;
   }
}

if ($varname ne "") {  # fall-off multi-line assignment (end of file)
   $conf{$varname} = $value;
}

close (CONFIG);
# finished processing config

#
# Start processing output files
#

if ($optcount > 0) {
   # Only copy (with substitutions) one file to a targetfile. Then exit:
   my $sourcefile = $commandline_options{'--from'};
   my $targetfile = $commandline_options{'--to'};
   print "Copy and substitute from $sourcefile to $targetfile\n";
   &substcopy($sourcefile,$targetfile);
   exit;
}

# now we need to copy a bunch of files into target dir
if (!exists($conf{'TARGET_DIRECTORY'})) {
   die "TARGET_DIRECTORY is not defined in $configfile";
}

#
#  Create an array of pathes (@flistpathes). Each element in this array
#  is the name of a file containing a list of source files to be
#  copied to the target directory.
#
my @flistpathes = ();
my $targetdir = $conf{'TARGET_DIRECTORY'};
$targetdir = &substituteval($targetdir);

#
# Install the config-file
#
if (! -f "$targetdir/$configMaster" or ($config_modified > (stat _)[9])) {
   print "Copy to $targetdir/$configMaster\n";
   copy($configfile, "$targetdir/$configMaster") or
      die "Could not copy $configfile to $targetdir: $!";
}

# install link from /etc/metamod-$majorVersoin/$appName.cfg to $targetdir/$configMaster
# NOTE: this only works when running as root, and should not be run on development servers
{
    my $etcDir = "/etc/metamod-$majorVersion";
    if (-d $etcDir) {
        my $etcConfig = "$etcDir/$appName.cfg";
        unlink $etcConfig; # need root for this
        symlink("$targetdir/$configMaster", $etcConfig)
            or print STDERR "unable to create symlink from $etcConfig -> $targetdir/$configMaster\n";
    } else {
        print STDERR "Cannot create configuration-symlink in $etcDir: no such directory\n\n";
    }
}

#
# get list over files to process
#
if (!exists($conf{'SOURCE_DIRECTORY'})) {
   die "SOURCE_DIRECTORY is not defined in $configfile";
}
my $sourcedir = $conf{'SOURCE_DIRECTORY'};
$sourcedir = &substituteval($sourcedir);
if (-r $sourcedir . '/common/filelist.txt') {
   push (@flistpathes,$sourcedir . '/common/filelist.txt');
}
foreach my $module qw(METAMODBASE METAMODSEARCH METAMODUPLOAD METAMODQUEST METAMODPMH METAMODHARVEST METAMODTHREDDS) {
   if (exists($conf{$module . '_DIRECTORY'}) and $conf{$module . '_DIRECTORY'} ne "") {
      my $moduledir = $conf{$module . '_DIRECTORY'};
      $moduledir = &substituteval($moduledir);
      push (@flistpathes,$moduledir . '/filelist.txt');
   }
}
push (@flistpathes, $appdir . '/filelist.txt');


#
# start processing source files
#
my %copied_targetnames = ();
foreach my $filelistpath (@flistpathes) {
#
#  Read the list of file names to be copied.
#  For each of these files where the modification time is larger
#  than the corresponding file in the target directory tree,
#  the file is copied to the target directory tree. While copying,
#  substitutions are made according to the configuration file.
#
   my $topdir = $filelistpath;
   $topdir =~ s:/[^/]*$::; # $topdir is the directory containing the
                           # current filelist.txt file
   # Open source file for reading
   unless (-r $filelistpath) {die "Can not read from file: $filelistpath\n";}
   open (FILES,$filelistpath);
   print "--- Processing $filelistpath:\n";

   # Loop through all lines in source file:
   while (<FILES>) {
      chomp($_);
      next unless /\w+/;
      my $filename = $_;
      my $ch1 = substr($filename,0,1);
      if ($ch1 eq '=') { # File will be copied unmodified
         $filename = substr($filename,1);
      }
      my $srcfilepath = $topdir . '/' . $filename;
      if (!( -e $srcfilepath)) {
         print "Unknown file in $filelistpath: $filename [$srcfilepath]\n";
      } else {
         my @targetfilenames = ();
         my $rex = '^' . $filename . ':';
         foreach my $oldandnew (grep {/$rex/} keys %newfilenames) {
            my ($old,$new) = split(/:/,$oldandnew);
            push @targetfilenames, $new;
         }
         if (scalar @targetfilenames == 0) {
            push @targetfilenames, $filename;
         }
         foreach my $targetname (@targetfilenames) {
            my $targetfile = $targetdir . '/' . $targetname;
            if ( exists($copied_targetnames{$targetname})
                 || !( -e $targetfile)
                 || (stat($srcfilepath))[9] > (stat($targetfile))[9]
                 || ($ch1 ne '=' and $config_modified > (stat($targetfile))[9])
               ) {
               # File $filename or the config file is modified later than $targetfile:
               # (or the file has already been copied from another filelist - this
               # ensures that files from the lattermost part of the sequence of filelists
               # are chosen).
               my $dirpath = $targetdir . '/' . $targetname;
               $dirpath =~ s/\/[^\/]*$//;
               mkpath($dirpath);
               #my $current_count = $missing_variables;
               if ($ch1 eq '=') { # copy contents verbatim
                  print "Copy to $targetdir/$targetname\n";
                  copy($srcfilepath, $targetdir . '/' . $targetname) or
                           die "Could not copy $srcfilepath to $targetdir: $!";
               } else { # process contents before copying
                  print "Copy and substitute to $targetdir/$targetname\n";
                  &substcopy($topdir, $filename, $targetdir, $targetname);
               }
               if ($targetfile =~ /([^.]+)$/) {
                  if ($1 eq "pl" || $1 eq "sh") {
                     chmod 0755, $targetfile;
                  }
                  #if ($1 eq "sh" and $current_count < $missing_variables) {
                  #   die "Fatal error: Missing config definitions for shell script $filename";
                  #} # not really a good idea since you get errors for scripts you never will run (e.g. harvester and thredds)
               }
               $copied_targetnames{$targetname} = 1;
            }
         }
      }
   }
   close (FILES);
}


my $logger_config = File::Spec->catfile( $targetdir, 'logger_config.ini' );
my $lcp = Metamod::LoggerConfigParser->new( { verbose => 1 } );
$lcp->create_and_write_configs($configfile,$logger_config);

# install the catalyst application
my $catalyst_dir = "$sourcedir/catalyst";
my $catalyst_install_dir = "$targetdir";
my $catalyst_lib_dir = "$catalyst_install_dir/lib";
chdir $catalyst_dir or die "Could not chdir to $catalyst_dir: $!";

# If local::lib has been installed on the machine then PERL_MM_OPT will be set with INSTALL_BASE
# which conflicts with PREFIX. We want to use PREFIX since it allows us to set LIB as well.
$ENV{PERL_MM_OPT} = '' if exists $ENV{PERL_MM_OPT};

system 'perl', 'Makefile.PL', "PREFIX=$catalyst_install_dir", "LIB=$catalyst_lib_dir";
system 'make';
system 'make install';

if ($missing_variables > 0) {
   print "NOTE: All [==...==] constructs found that were not defined in the configuration file\n" .
                "      were substituted with empty values\n";
}

my $appuser = $conf{'APPLICATION_USER'};
my $webrun = $conf{'WEBRUN_DIRECTORY'};
if ($appuser) {
   my $owner = getpwuid( (stat($webrun))[4] );
   print STDERR "webrun dir '$webrun' is owned by user '$owner'\n";
   warn "Webrun directory ($webrun) should be owned by user $appuser (not $owner)" unless $owner eq $appuser;
}

system "$targetdir/scripts/gen_httpd_conf.pl", $targetdir;

#----------------------------------------------------------------------
# END
#----------------------------------------------------------------------

sub substcopy {
   # copies a file with inline processing
   my $inputdir;
   my $inputfile = "";
   my $inputpath;
   my $outputdir;
   my $outputfile = "";
   my $outputpath;

   # Check number of arguments
   if (scalar @_ == 4) {
      $inputdir = $_[0];
      $inputfile = $_[1];
      $outputdir = $_[2];
      $outputfile = $_[3];
      $inputpath = "$inputdir/$inputfile";
      $outputpath = "$outputdir/$outputfile";
   } elsif (scalar @_ == 2) {
      $inputpath = $_[0];
      $outputpath = $_[1];
   } else {
      die "\nsubstcopy:     Wrong number of arguments\n\n";
   }

   # Open target file for writing
   open (OUT,">$outputpath") or die "Couldn't open $outputpath for writing";

   # Open source file for reading
   unless (-r "$inputpath")
          {die "Can not read from file: $inputpath\n";}
   open (IN,"$inputpath");
   while (<IN>) {
      chomp($_);
      my $sline = $_;
      $sline = &substituteval($sline,$inputfile,$outputfile);
      print OUT $sline . "\n";
   }
   close (IN);
   close (OUT);
   # copy executable flag from source (svn)
   chmod(0755, $outputpath) if -x $inputpath;
}

sub substituteval {
   # process subtitution, either on string or source file
   my $textline;
   my $ifil = "";
   my $ofil = "";
   if (scalar @_ == 3) {
      ($textline,$ifil,$ofil) = @_;
   } else {
      ($textline) = @_;
   }
   my $scount = 0;
   my $substituted;
   my $vname = "";
   do {
      my $valuefound = 0;
      $substituted = 0;
      if ($textline =~ /\[==([A-Z0-9_]+)==\]/) {
         $vname = $1; # First matching ()-expression
         my $value = "";

         #  Check if substitution key exists in config hash
         if (length($ifil) > 0 &&
                  exists($conf{$vname . ':' . $ifil . ':' . $ofil})) {
            $value = $conf{$vname . ':' . $ifil . ':' . $ofil};
            $valuefound = 1;
         } elsif (exists($conf{$vname})) {
            $value = $conf{$vname};
            $valuefound = 1;
         }
         my $reg = "\\[==" . $vname . "==\\]";
         if ($valuefound) {
#
#           Substitute all occurences of a match:
#
            $textline =~ s/$reg/$value/mg;
         } else {
            if (length($ifil) > 0) {
               print "WARNING: [==" . $vname . "==] in $ifil not configured\n";
            } else {
               print "WARNING: [==" . $vname . "==] not configured:\n";
               print "         $textline\n";
            }
            $textline =~ s/$reg//mg;
            $missing_variables++;
         }
         $substituted = 1;
         $scount++;
      }
   } while ($substituted == 1 && $scount < 20);
   if ($scount >= 20) {
      die "ERROR: Circular substitutions in $configfile involving [==$vname==]\n";
   }
   return $textline;
}
#----------------------------------------------------------------------

=head1 NAME

B<update_target.pl> - Metamod installer/tester

=head1 VERSION

[% VERSION %], last modified $Date: 2008-10-06 11:28:08 $

=head1 DESCRIPTION

This script copies the files listed in the various filelist.txt manifests into the
corresponding dirs in the target.
Also performs macro expansion of several shell scripts and other files, substituting
variables from master_config.txt.

=head1 USAGE

 trunk/update_target.pl application_directory
 trunk/update_target.pl --from=sourcefile --to=targetfile application_directory

=head1 OPTIONS

=head2 Parameters

=over 4

=item application_directory

'application_directory' is the name of a directory containing the application
specific files. Inside this directory, there must be a master_config.txt file.

=item --from

=item --to

If these two options are present, the normal behaviour is suspended. The only thing
that happens are copying with substitutions (according to the master_config.txt file)
from the sourcefile to the targetfile.

=back

=head1 LICENSE

Copyright (C) 2010 The Norwegian Meteorological Institute.

METAMOD is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

=cut
