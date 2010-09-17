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

package Uploadutils;
use base qw(Exporter);
use strict; 
use warnings;
use Data::Dumper;
use mmTtime;
use Metamod::Config;
use Log::Log4perl;

our $VERSION = 0.1;

our @EXPORT_OK = qw(notify_web_system
                    get_dataset_institution
                    shcommand_scalar
                    shcommand_array
                    get_basenames
                    intersect
                    union
                    subtract
                    get_date_and_time_string
                    decodenorm
                    string_found_in_file
                    current_time syserror
                    $config
                    $progress_report
                    $webrun_directory
                    $work_directory
                    $uerr_directory
                    $upload_ownertag
                    $application_id
                    $xml_directory
                    $target_directory
                    $opendap_directory
                    $opendap_url
                    $days_to_keep_errfiles
                    $path_to_syserrors
                    $path_to_shell_error
                    $local_url
                    $shell_command_error
                    @user_errors
                    );

use File::Find qw();
use POSIX qw();
use Fcntl qw(LOCK_SH LOCK_UN LOCK_EX);
use Metamod::Config;
#  
#  Global variables (constants after initialization):
#
our $config = new Metamod::Config();
our $progress_report = $config->get("TEST_IMPORT_PROGRESS_REPORT"); # If == 1, prints what
                                                         # is going on to stdout
our $webrun_directory = $config->get('WEBRUN_DIRECTORY');
our $work_directory = $webrun_directory . "/upl/work";
our $uerr_directory = $webrun_directory . "/upl/uerr";
our $upload_ownertag = $config->get('UPLOAD_OWNERTAG');
our $application_id = $config->get('APPLICATION_ID');
our $xml_directory = $webrun_directory . '/XML/' . $application_id;
our $target_directory = $config->get('TARGET_DIRECTORY');
our $opendap_directory = $config->get('OPENDAP_DIRECTORY');
our $opendap_url = $config->get('OPENDAP_URL');
our $days_to_keep_errfiles = 14;
our $path_to_syserrors = $webrun_directory . "/syserrors";
our $path_to_shell_error = $webrun_directory . "/upl/shell_command_error";
our $local_url = $config->get('LOCAL_URL');
#
# Global variable containing error messages from shell commands:
#
our $shell_command_error = "";
our @user_errors = ();
#
#---------------------------------------------------------------------------------
#
sub notify_web_system {
   my ($code,$dataset_name,$ref_uploaded_files,$path_to_errors_html) = @_;
   my @uploaded_basenames = &get_basenames($ref_uploaded_files);
   my @user_filenames = glob($webrun_directory . '/u1/*');
#
#  Get file sizees for each uploaded file:
#
   if ($progress_report == 1) {
      print "notify_web_system: $code,$dataset_name\n";
      print "                   $path_to_errors_html\n";
      print "                   Uploaded basenames:\n";
      print Dumper(\@uploaded_basenames);
   }
   my %file_sizes = ();
   my $i1 = 0;
   foreach my $fname (@$ref_uploaded_files) {
      my $basename = $uploaded_basenames[$i1];
      my @filestat = stat($fname);
      if (scalar @filestat == 0) {
         &syserror("SYS","Could not stat $fname", "", "notify_web_system", "");
         $file_sizes{$basename} = 0;
      } else {
         $file_sizes{$basename} = $filestat[7];
      }
      $i1++;
   }
#
#  Find current time
#
   my @time_arr = gmtime;
   my $year = 1900 + $time_arr[5];
   my $mon = $time_arr[4] + 1; # 1-12
   my $mday = $time_arr[3]; # 1-31
   my $hour = $time_arr[2]; # 0-23
   my $min = $time_arr[1]; # 0-59
   my $timestring = sprintf('%04d-%02d-%02d %02d:%02d UTC',$year, $mon, $mday, $hour, $min);
   my @found_basenames = ();
   my $ownerfile;
   foreach my $userfile (@user_filenames) {
#   
#     Slurp in the content of a file
#   
      unless (-r $userfile) {
         &syserror("SYS","Can not read from file: $userfile", "", "notify_web_system", "");
         next;
      }
      open (USERFILE,$userfile);
      undef $/;
      my $file_content = <USERFILE>;
      my @file_content_arr = split(/\n/,$file_content);
      $/ = "\n"; 
      close (USERFILE);
#
      my $rex = '<dir dirname="' . $dataset_name . '"';
      if ($file_content =~ /$rex/) {
         $ownerfile = $userfile;
      }
#
      my %positions = ();
      my $pos = 0;
      $rex = '<file name="([^"]*)"';
      foreach my $line (@file_content_arr) {
         if ($line =~ /$rex/) {
            my $basename = $1; # First matching ()-expression
            $positions{$basename} = $pos;
         }
         $pos++;
      }
      my $changes = 0;
      foreach my $basename (@uploaded_basenames) {
         if (exists($positions{$basename})) {
            my $pos = $positions{$basename};
            $file_content_arr[$pos] = '<file name="' . $basename . '" size="' .
                                      $file_sizes{$basename} .
                                      '" status="' . $code . $timestring . '" errurl="' .
                                      $path_to_errors_html . '" />';
            $changes = 1;
            push (@found_basenames,$basename);
         }
      }
      if ($changes == 1) {
         my $new_file_content = join("\n",@file_content_arr);
         open (USERFILE,">$userfile");
         print USERFILE $new_file_content;
         close (USERFILE);
      }
   }
   if (defined($ownerfile)) {
#   
#     Add <file> elements for the rest of the file names (those that
#     previously did not have any <file> element) to the userfile of
#     the dataset owner:
#
      if ($progress_report == 1) {
         print "                   Uploaded files:\n";
         print Dumper($ref_uploaded_files);
         print "                   found_basenames:\n";
         print Dumper(\@found_basenames);
      }
      my @rest_basenames = &subtract(\@uploaded_basenames,\@found_basenames);
      if ($progress_report == 1) {
         print "                   rest_basenames:\n";
         print Dumper(\@rest_basenames);
      }
      if (scalar @rest_basenames > 0) {
#   
#     Slurp in the content of a file
#   
         unless (-r $ownerfile) {
            &syserror("SYS","Could not read from $ownerfile", "", "notify_web_system", "");
            next;
         }
         open (USERFILE,$ownerfile);
         undef $/;
         my $file_content = <USERFILE>;
         my @file_content_arr = split(/\n/,$file_content);
         $/ = "\n"; 
         close (USERFILE);
#   
         my @new_file_content_arr = ();
         my $added_new_lines = 0;
         foreach my $line (@file_content_arr) {
            if ($line !~ /(<heading name=)|(<file name=)/) {
               if ($added_new_lines == 0) {
                  foreach my $basename (@rest_basenames) {
                     my $new_line = '<file name="' . $basename . '" size="' .
                                 $file_sizes{$basename} .
                                 '" status="' . $code . $timestring . '" errurl="' .
                                 $path_to_errors_html . '" />';
                     push (@new_file_content_arr,$new_line);
                  }
                  $added_new_lines = 1;
               }
            }
            push (@new_file_content_arr,$line);
         }
         my $new_file_content = join("\n",@new_file_content_arr);
         open (USERFILE,">$ownerfile");
         print USERFILE $new_file_content;
         close (USERFILE);
      }
      if ($progress_report == 1) {
         print "-notify_web_system\n";
      }
   } else {
      &syserror("SYS","dataset_not_owned_by_any_user", "", "notify_web_system", "");
   }
}
#
#---------------------------------------------------------------------------------
#
sub get_dataset_institution {
#
# Initialize hash connecting each dataset to a reference to a hash with the following
# elements:
#
# ->{'institution'} Name of institution as found in an <heading> element within the webrun/u1
#       file for the user that owns the dataset.
# ->{'email'} The owners E-mail address.
# ->{'name'} The owners name.
# ->{'key'} The directory key.
#
# If found, extra elements are included:
#
# ->{'location'} Location
# ->{'catalog'} Catalog
# ->{'wmsurl'} URL to WMS
#
# The last elements are taken from the line:
# <dir ... location="..." catalog="..." wmsurl="..."/>)
#
   my($ref_dataset_institution) = @_;
#   
#     Get all file names corresponding to a glob pattern:
#   
   my @files_found = glob($webrun_directory . '/u1/*');
   foreach my $filename (@files_found) {
#      
#        Slurp in the content of a file
#      
      unless (-r $filename) {
         &syserror("SYS","Can not read from file: $filename", "", "get_dataset_institution", "");
         next;
      }
      open (INPUTFILE,$filename);
      local $/;
      my $content = <INPUTFILE>;
      close (INPUTFILE);
#
      my $institution;
      if ($content =~ /<heading.* institution=\"([^\"]+)\"/m) {
         $institution = &decodenorm($1);
      } else {
         &syserror("SYS","institution_not_found_in_u1_file: $filename", "", "get_dataset_institution", "");
         next;
      }
#
      my $email;
      if ($content =~ /<heading.* email=\"([^\"]+)\"/m) {
         $email = &decodenorm($1);
      } else {
         &syserror("SYS","emailaddress_not_found_in_u1_file: $filename", "", "get_dataset_institution", "");
         next;
      }
#
      my $username;
      if ($content =~ /<heading.* name=\"([^\"]+)\"/m) {
         $username = &decodenorm($1);
      } else {
         &syserror("SYS","username_not_found_in_u1_file: $filename", "", "get_dataset_institution", "");
         next;
      }
#      
#        Collect all matches into an array
#        (no substrings allowed in REGEXP)
#      
      my @datasets = ($content =~ /<dir dirname=[^>]+>/mg);
      for (my $ix=0; $ix < scalar @datasets; $ix++) {
         my $rex1 = '<dir dirname="([^"]*)"';
         my $line = $datasets[$ix];
         if ($line =~ /$rex1/) {
            my $dataset_name = $1;
            $ref_dataset_institution->{$dataset_name} = {};
            $ref_dataset_institution->{$dataset_name}->{'institution'} = $institution;
            $ref_dataset_institution->{$dataset_name}->{'email'} = $email;
            $ref_dataset_institution->{$dataset_name}->{'name'} = $username;
            foreach my $k1 ('key', 'location', 'catalog', 'wmsurl') {
               my $rex2 = $k1 . '="([^"]*)"';
               if ($line =~ /$rex2/) {
                  $ref_dataset_institution->{$dataset_name}->{$k1} = &decodenorm($1);
               }
            }
         } else {
            &syserror("SYS","dirname_not_found_in_dir_element: $filename", "", "get_dataset_institution", "");
         }
      }
   }
}
#
#---------------------------------------------------------------------------------
#
sub shcommand_scalar {
   my ($command) = @_;
#   open (SHELLLOG,">>$path_to_shell_log");
#   print SHELLLOG "---------------------------------------------------\n";
#   print SHELLLOG $command . "\n";
#   print SHELLLOG "                    ------------RESULT-------------\n";
   my $result = `$command 2>$path_to_shell_error`;
#   print SHELLLOG $result ."\n";
#   close (SHELLLOG);
   if (-s $path_to_shell_error) {
#
#     Slurp in the content of a file
#
      unless (-r $path_to_shell_error) {die "Can not read from file: shell_command_error\n";}
      open (ERROUT,$path_to_shell_error);
      undef $/;
      $shell_command_error = <ERROUT>;
      $/ = "\n"; 
      close (ERROUT);
      if (unlink($path_to_shell_error) == 0) {
         die "Unlink file shell_command_error did not succeed\n";
      }
      $shell_command_error = $command . "\n" . $shell_command_error;
      return undef;
   }
   return $result;
}
#
#---------------------------------------------------------------------------------
#
sub shcommand_array {
   my ($command) = @_;
#   open (SHELLLOG,">>$path_to_shell_log");
#   print SHELLLOG "---------------------------------------------------\n";
#   print SHELLLOG $command . "\n";
   my $result1 = `$command 2>$path_to_shell_error`;
#   print SHELLLOG "                    ------------RESULT-------------\n";
#   print SHELLLOG $result1 . "\n";
#   close (SHELLLOG);
   my @result = split(/\n/,$result1);
   if (scalar @result == 0 && -s $path_to_shell_error) {
#
#     Slurp in the content of a file
#
      unless (-r $path_to_shell_error) {die "Can not read from file: shell_command_error\n";}
      open (ERROUT,$path_to_shell_error);
      undef $/;
      $shell_command_error = <ERROUT>;
      $/ = "\n"; 
      close (ERROUT);
      if (unlink($path_to_shell_error) == 0) {
         die "Unlink file shell_command_error did not succeed\n";
      }
      $shell_command_error = $command . "\n" . $shell_command_error;
   }
   return @result;
}
#
#---------------------------------------------------------------------------------
#
sub get_basenames {
   my ($ref) = @_;
   my @result = ();
   foreach my $path1 (@$ref) {
      my $path = $path1;
      $path =~ s:^.*/::;
      push (@result,$path);
   }
   return @result;
}
#
#---------------------------------------------------------------------------------
#
sub intersect {
   my ($a1,$a2) = @_;
   my %h1 = ();
   foreach my $elt (@$a1) {
      $h1{$elt} = 1;
   }
   my @result = ();
   foreach my $elt (@$a2) {
      if (exists($h1{$elt})) {
         push (@result,$elt);
      }
   }
   return @result;
}
#
#---------------------------------------------------------------------------------
#
sub union {
   my ($a1,$a2) = @_;
   my %h1 = ();
   foreach my $elt (@$a1,@$a2) {
      $h1{$elt} = 1;
   }
   return keys %h1;
}
#
#---------------------------------------------------------------------------------
#
sub subtract {
   my ($a1,$a2) = @_;
   my %h2 = ();
   foreach my $elt (@$a2) {
      $h2{$elt} = 1;
   }
   my @result = ();
   foreach my $elt (@$a1) {
      if (!exists($h2{$elt})) {
         push (@result,$elt);
      }
   }
   return @result;
}
#
#---------------------------------------------------------------------------------
#
sub get_date_and_time_string {
   my @ta;
   if (scalar @_ > 0) {
      @ta = localtime($_[0]);
   } else {
      @ta = localtime(mmTtime::ttime());
   }
   my $year = 1900 + $ta[5];
   my $mon = $ta[4] + 1; # 1-12
   my $mday = $ta[3]; # 1-31
   my $hour = $ta[2]; # 0-23
   my $min = $ta[1]; # 0-59
   my $datestring = sprintf ('%04d-%02d-%02d %02d:%02d',$year,$mon,$mday,$hour,$min);
   return $datestring;
};
#
#---------------------------------------------------------------------------------
#
sub decodenorm {
   my ($strn) = @_;
   $strn =~ s/^\s+|\s+$//g;
   if (length($strn) > 0) {
      my $new = "";
      my $numchar = "";
      my @a1 = split(//,$strn);
      foreach my $ch1 (@a1) {
         if ($ch1 =~ /[0-9A-F]/) {
            $numchar .= $ch1;
            if (length($numchar) == 2) {
               eval('$new .= chr(0x' . $numchar . ');');
               $numchar = '';
            }
         } else {
            $new .= $ch1;
            $numchar = '';
         }
      }
      return $new;
   } else {
      return '';
   }
};
#
#-----------------------------------------------------------------------------------
# Check if string found in file:
#
sub string_found_in_file {
   my ($searchfor,$fname) = @_;
   if (-r $fname) {
      open (FH,$fname);
      local $/ = undef;
      my $content = <FH>;
      close (FH);
      my $found = index($content,$searchfor);
      if ($found >= 0) {
         return 1;
      } else {
         return 0;
      }
   } else {
      return 0;
   }
};
#
#-----------------------------------------------------------------------------------
#  Find current time
#
sub current_time {
   my @ta = localtime();
   my $year = 1900 + $ta[5];
   my $mon = $ta[4] + 1; # 1-12
   my $mday = $ta[3]; # 1-31
   my $hour = $ta[2]; # 0-23
   my $min = $ta[1]; # 0-59
   my $datestring = sprintf ('%04d-%02d-%02d %02d:%02d',$year,$mon,$mday,$hour,$min);
   return $datestring;
};
#
#---------------------------------------------------------------------------------
# $errmsg = (NORMAL TERMINATION | error-message)
#
{
    my $logger = Log::Log4perl->get_logger('metamod.upload.Uploadutils');
    sub syserror {
        my ($type,$errmsg,$uploadname,$where,$what) = @_;
        my (undef, undef, $baseupldname) = File::Spec->splitpath($uploadname);

        if ($type eq "SYS" || $type eq "SYSUSER") {
            my $errMsg = "$type IN: $where: $errmsg; ";
            $errMsg .= "Uploaded file: $uploadname; " if $uploadname;
            $errMsg .= "Error: $what; " if $what;
            $errMsg .= "Stderr: $shell_command_error; ";
            if ($errmsg eq 'NORMAL TERMINATION') {
                $logger->info($errMsg."\n");
            } else {
                if ($type eq "SYS") {
                    $logger->error($errMsg."\n");
                } else {
                    $logger->warn($errMsg."\n");
                }
            }
        }
        if ($type eq "USER" || $type eq "SYSUSER") {
            # warnings about the uploaded data
            push(@user_errors, "$errmsg\nUploadfile: $baseupldname\n$what\n\n");
        }
        $shell_command_error = "";
    }
}
1;
