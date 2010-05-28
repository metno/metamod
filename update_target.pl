#!/usr/bin/perl -w
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
#  email: egil.storen@met.no 
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
#
use strict;
use File::Copy;
use File::Path;
use File::Spec;
use FindBin qw($Bin);

#
#  Check number of command line arguments
#
if (scalar @ARGV != 1) {
   die "\nUsage:\n\n     $0 application_directory\n\n" .
       "where 'application_directory' is the name of a directory containing the application\n" .
       "specific files. Inside this directory, there must be a master_config.txt file.\n\n";
}
my $appdir = $ARGV[0];
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
print "\nConfiguring application '$appName' with Metamod $majorVersion ($version)\n\n";


my %conf;
my $missing_variables = 0;
#
#  Open file for reading
#
my $config_modified = (stat($configfile))[9];
unless (-r $configfile) {die "Can not read from file: $configfile\n";}
open (CONFIG,$configfile);
#
#  Loop through all lines read from a file:
#
my %newfilenames = ();
my $value = "";
my $varname = "";
my $origname = "";
my $newname = "";
my $line = "";
while (<CONFIG>) {
   chomp($_);
   $line = $_;
#   
#     Check if expression matches RE:
#   
   if ($line =~ /^[A-Z0-9_#!]/ && $varname ne "") {
      if (length($origname) > 0) {
         $conf{$varname . ':' . $origname . ':' . $newname} = $value;
         $newfilenames{$origname . ':' . $newname} = 1;
      } else {
         $conf{$varname} = $value;
      }
      $varname = "";
   }
   if ($line =~ /^([A-Z0-9_]+)\s*=(.*)$/) {
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
   } elsif ($line !~ /^#/ && $line !~ /^\s*$/) {
      $value .= "\n" . $line;
   }
}
if ($varname ne "") {
   $conf{$varname} = $value;
}
close (CONFIG);
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
{
    my $etcDir = "/etc/metamod-$majorVersion";
    if (-d $etcDir) {
        my $etcConfig = "$etcDir/$appName.cfg";
        unlink $etcConfig;
        symlink("$targetdir/$configMaster", $etcConfig)
            or print STDERR "unable to create symlink from $etcConfig -> $targetdir/$configMaster\n";
    } else {
        print STDERR "Cannot create configuration-symlink in $etcDir: no such directory\n\n";
    }
}
    

if (!exists($conf{'SOURCE_DIRECTORY'})) {
   die "SOURCE_DIRECTORY is not defined in $configfile";
}
my $sourcedir = $conf{'SOURCE_DIRECTORY'};
$sourcedir = &substituteval($sourcedir);
if (-r $sourcedir . '/common/filelist.txt') {
   push (@flistpathes,$sourcedir . '/common/filelist.txt');
}
foreach my $module qw(METAMODBASE METAMODSEARCH METAMODUPLOAD METAMODQUEST METAMODPMH METAMODHARVEST METAMODTHREDDS) {
   if (exists($conf{$module . '_DIRECTORY'})) {
      my $moduledir = $conf{$module . '_DIRECTORY'};
      $moduledir = &substituteval($moduledir);
      push (@flistpathes,$moduledir . '/filelist.txt');
   }
}
push (@flistpathes, $appdir . '/filelist.txt');
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
#
#  Open file for reading
#
   unless (-r $filelistpath) {die "Can not read from file: $filelistpath\n";}
   open (FILES,$filelistpath);
   print "--- Processing $filelistpath:\n";
#
#  Loop through all lines read from a file:
#
   while (<FILES>) {
      chomp($_);
      my $filename = $_;
      my $ch1 = substr($filename,0,1);
      if ($ch1 eq '=') { # File will be copied unmodified
         $filename = substr($filename,1);
      }
      my $srcfilepath = $topdir . '/' . $filename;
      if (!( -e $srcfilepath)) {
         print 'Unknown file in ' . $filelistpath . ': ' . $filename . "\n";
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
            if (exists($copied_targetnames{$targetname}) || !( -e $targetfile) ||
                 (stat($srcfilepath))[9] > (stat($targetfile))[9] ||
                 ($ch1 ne '=' and $config_modified > (stat($targetfile))[9]) ) {
#
#        File $filename or the config file is modified later than $targetfile:
#        (or the file has already been copied from another filelist - this
#        ensures that files from the lattermost part of the sequence of filelists
#        are chosen).
#      
               my $dirpath = $targetdir . '/' . $targetname;
               $dirpath =~ s/\/[^\/]*$//;
               mkpath($dirpath);
               if ($ch1 eq '=') {
                  print "Copy to $targetdir/$targetname\n";
                  copy($srcfilepath, $targetdir . '/' . $targetname) or
                           die "Could not copy $srcfilepath to $targetdir: $!";
               } else {
                  print "Copy and substitute to $targetdir/$targetname\n";
                  &substcopy($topdir, $filename, $targetdir, $targetname);
               }
               if ($targetfile =~ /([^.]+)$/) {
                  if ($1 eq "pl" || $1 eq "sh") {
                     chmod 0755, $targetfile;
                  }
               }
               $copied_targetnames{$targetname} = 1;
            }
         }
      }
   }
   close (FILES);
}
if ($missing_variables > 0) {
   print "NOTE: All [==...==] constructs found that were not defined in the configuration file\n" .
                "      were substituted with empty values\n";
}
#
#----------------------------------------------------------------------
sub substcopy {
#
#  Check number of arguments
#
   if (scalar @_ != 4) {
      die "\nsubstcopy:     Wrong number of arguments\n\n";
   }
   my $inputdir = $_[0];
   my $inputfile = $_[1];
   my $outputdir = $_[2];
   my $outputfile = $_[3];
#
#  Open file for writing
#
   open (OUT,">$outputdir/$outputfile");
#
#  Open file for reading
#
   unless (-r "$inputdir/$inputfile") 
          {die "Can not read from file: $inputdir/$inputfile\n";}
   open (IN,"$inputdir/$inputfile");
   while (<IN>) {
      chomp($_);
      my $sline = $_;
      $sline = &substituteval($sline,$inputfile,$outputfile);
      print OUT $sline . "\n";
   }
   close (IN);
   close (OUT);
}

sub substituteval {
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
#      
#        Check if key exists in hash
#      
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
         }
         else {
            if (length($ifil) > 0) {
               print "WARNING: [==" . $vname . "==] in $ifil not found\n";
            } else {
               print "WARNING: [==" . $vname . "==] not found:\n";
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
