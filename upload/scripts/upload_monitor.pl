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
use lib qw([==TARGET_DIRECTORY==]/scripts [==TARGET_DIRECTORY==]/lib);
use File::Copy;
use File::Path;
use Fcntl qw(LOCK_SH LOCK_UN LOCK_EX);
use Data::Dumper;
use Mail::Mailer;
use mmTtime;
$| = 1;
#
#  upload_monitor.pl
#  -----------------
#
#  Monitor file uploads from data providers. Start digest_nc.pl on
#  uploaded files.
#
#  Files are either uploaded to an FTP area, or interactively to an HTTP area
#  using the web interface. The top level directory pathes for these two areas are
#  given by the global variables $ftp_dir_path and $upload_dir_path.
#
#  FTP uploads:
#
#  Uploads to the FTP area are only done by data providers having an agreement
#  with the data repository authority to do so. This agreement designates which
#  datasets the data provider will upload data to. Typically, such agreements
#  are made for operational data uploaded by automatic processes at the data
#  provider site. The names of the datasets covered by such agreements are 
#  found in the text file [==WEBRUN_DIRECTORY==]/ftp_events described below.
#  
#  This script will search for files at any directory level beneath the
#  $ftp_dir_path directory. Any file that have a basename matching glob pattern
#  '<dataset_name>_*' (where <dataset_name> is the name of the dataset) will
#  be treated as containing a possible addition to that dataset.
#
#  HTTP uploads:
#
#  The directory structure of the HTTP upload area mirrors the directory
#  structure of the final data repository (the $opendap_directory defined
#  below). Thus, any HTTP-uploaded file will end up in a directory where both
#  the institution acronym and the dataset name are found in the directory
#  path. Even so, all file names are required to match the '<dataset_name>_*'
#  pattern (this requirement is enforced by the web interface).
#
#  Overall operation:
#
#  The script executes an infinite loop as long as the file $path_continue_monitor
#  exists. After each repetition of the loop body, the script waits for 
#  $sleeping_seconds seconds.
#
#  The ftp_events file contains, for each of the datasets, the hours at which
#  the FTP area should be checked for additions. The HTTP area will be checked at
#  each repetition of the loop body.
#
#  In order to avoid processing of incomplete files, the age of any file has
#  to be above a threshold. This threshold is given in the ftp_events file for
#  files uploaded with FTP, and may vary between datasets. For files uploaded
#  with HTTP, this threshold is a configurable constant ($upload_age_threshold).
#  
#  Uploaded files are either individual netCDF files (or CDL files), or they are
#  archive files (tar) containing several netCDF/CDL files. Both file types may 
#  be gzip compressed. The data provider may upload several files for the same
#  dataset within a short period of time. The digest_nc.pl script will work best
#  if it can, during one invocation, digest all the files uploaded during such
#  a period. To achieve this, the script will not process a file if any other
#  file are found for the same dataset that have not reached the age prescribed
#  by the threshold.
#
#  When a new set of files for a given dataset is found to be ready for processing
#  (either from the FTP area or from the HTTP area), the file names are sent to
#  the process_files subroutine.
#  
#  The process_files subroutine will copy the files to the $work_expand directory
#  where any archive files are expanded. An archive file may contain a directory
#  tree. All files in a directory tree (and all the other files in the $work_expand
#  directory) are copied to another directory, $work_flat. This directory has a
#  flat structure (no subdirectories). A name collision arising from files with same
#  basename but from different parts of a directory tree, is considered an error.
#
#  Any CDL file now found in the $work_flat directory is converted to netCDF. The
#  set of uncompressed netCDF-files that now populate the $work_flat directory, is
#  sent to the digest_nc.pl script for checking.
#  
#  Error handling:
#  
#  Various errors may arise during this file processing operation. The errors are
#  divided into four different categories:
#
#  1. Errors arising from external system environment. Such errors will usually not
#     occur. They will only arise if system resources are exhausted, or if anything
#     happens to the file system (like permission changes on important files and
#     directories). If any such error arise, the script will die and an abortion error
#     message will be recorded in the system error log.
#  
#  2. Internal system errors. These errors are mainly caused by failing shell commands
#     (file, tar, gunzip etc.). They may also arise when any inconsistency are found
#     that may indicate bugs in the script. The script will continue, but the 
#     processing of the offending uploaded file will be discontinued. The file will
#     be moved to the $problem_dir_path directory and an error message will be
#     recorded in the system error log. In addition, the user will be notified
#     about an internal system error that prohibited processing of the file.
#     These errors may be caused by uploaded files that are corrupted,
#     or not of the expected format. (Note to myself: In that case the error category
#     should be changed to category 3 below).
#  
#  3. User errors that makes furher prosessing of an uploaded file impossible. The
#     file will be moved to the $problem_dir_path directory and an error message will
#     be recorded in the system error log. In addition, the user will be notified
#     with an indication of the nature of the error.
#
#  4. Other user errors. These are mainly caused by non-complience with the 
#     requirements found in the conf_digest_nc.xml file. All such errors are conveyed
#     to the user through the nc_usererrors.out file. A summary of this file is
#     constructed in the form of a self-explaining HTML file (using the
#     print_usererrors.pl script).
#  
#  All uploaded files that were processed with no errors, or with only
#  category 4 errors, are deleted after the expanded version of the files are
#  copied to the data repository. The status of the files are recorded in the
#  appropriate file in the u1 subdirectory of the $webrun_directory directory.
#  
#  In the $problem_dir_path directory the files are renamed according to the following
#  scheme: A 6 digit number, DDNNNN, are constructed where DD is the day number in
#  the month and NNNN is starting on 0001 each new day, and increments with 1 for
#  each file copied to the directory. The new file name will be:
#
#     DDNNNN_<basename>
#
#  where <basename> is the basename of the uploaded file name.
#  
#  Files older than a prescribed number of days will be deleted from the 
#  $problem_dir_path directory.
#  
#  Global variables (constants after initialization):
#
my $progress_report = [==TEST_IMPORT_PROGRESS_REPORT==]; # If == 1, prints what
                                                         # is going on to stdout
my $ftp_dir_path = '[==UPLOAD_FTP_DIRECTORY==]';
my $upload_dir_path = '[==UPLOAD_DIRECTORY==]';
my $webrun_directory = '[==WEBRUN_DIRECTORY==]';
my $work_directory = $webrun_directory . "/upl/work";
my $uerr_directory = $webrun_directory . "/upl/uerr";
my $work_expand = $work_directory . "/expand";
my $work_flat = $work_directory . "/flat";
my $work_start = $work_directory . "/start";
my $upload_ownertag = '[==UPLOAD_OWNERTAG==]';
my $application_id = '[==APPLICATION_ID==]';
my $xml_directory = $webrun_directory . '/XML/' . $application_id;
my $xml_history_directory = $webrun_directory . '/XML/history';
my $target_directory = '[==TARGET_DIRECTORY==]';
my $opendap_directory = '[==OPENDAP_DIRECTORY==]';
my $opendap_url = '[==OPENDAP_URL==]';
my $path_continue_monitor = $webrun_directory . "/upl/CONTINUE_UPLOAD_MONITOR";
my $sleeping_seconds = 60;
if ([==TEST_IMPORT_SPEEDUP==] > 1) {
   $sleeping_seconds = 1;
}
my $upload_age_threshold = [==UPLOAD_AGE_THRESHOLD==];
my %all_ftp_datasets;     # Initialized in sub read_ftp_events. For each dataset
                          # found in the ftp_events file, this hash contains the
                          # number of days to keep the files in the repository.
                          # If this number == 0, the files are kept indefinitely.
my $days_to_keep_errfiles = 14;
my $problem_dir_path = $webrun_directory . "/upl/problemfiles";
my $path_to_syserrors = $webrun_directory . "/syserrors";
my $path_to_shell_error = $webrun_directory . "/upl/shell_command_error";
# my $path_to_shell_log = $webrun_directory . "/upl/shell_log";
my $local_url = '[==LOCAL_URL==]';
#
#  Dynamic global variables:
#
my %dataset_institution;     # Updated in sub get_dataset_institution
my $shell_command_error = "";
my %files_to_process = ();   # Hash containing, for each uploaded file to 
                             # be processed (full path), the modification
                             # time of that file. This hash is re-
                             # initialized for each new batch of files
                             # to be processed for the same dataset.
my $file_in_error_counter;
my @user_errors = ();
#
#  Action starts here:
#  -------------------
#
eval {
   &main_loop();
};
if ($@) {
   &syserror("SYS", "ABORTED: " . $@, "", "", "");
} else {
   &syserror("SYS", "NORMAL TERMINATION", "", "", "");
}
#
# ----------------------------------------------------------------------------
#
sub main_loop {
#
#  Make sure static directories exists:
#
   foreach my $directory ($work_directory,$work_start,$work_expand,$work_flat,
          $uerr_directory,$xml_directory,$xml_history_directory,$problem_dir_path) {
      mkpath($directory);
   }
#
#  Change to work directory
#
   unless (chdir $work_directory) {
      die "Could not cd to $work_directory: $!\n";
   }
#
#  Initialize hash (%ftp_events) that regulates which datasets are uploaded through
#  FTP, and how often this script will check for new files for these datasets.
#
#  The hash is based on a text file containing lines of the following format:
#
#  dataset_name wait_minutes days_to_keep_files hour1 hour2 hour3 ...
#
#     wait_minutes        The minimum age of a new ftp file. If a file has less age
#                         than this value, the file is left for later processing.
#
#     days_to_keep_files  Number of days where the files are to remain
#                         unchanged on the repository. When this period 
#                         expires, the files will be deleted and substituted
#                         with files containing only metadata. This is done
#                         in sub 'clean_up_repository'.
#                         If this number == 0, the files are kept indefinitely.
#
#     hourN               These numbers (0-23) represents the times during a day
#                         where checking for new files take place.
#
#  For each hourN, a hash key is constructed as "dataset_name hourN" and the
#  corresponding value is set to wait_minutes.
#
   my %ftp_events = ();
   &read_ftp_events(\%ftp_events);
   if ($progress_report == 1) {
      print "Dump av hash ftp_events:\n";
      print Dumper(\%ftp_events);
   }

#
#  Initialize hash that contain the institution code for each dataset.
#  The hash will be filled with updated info from the directory 
#  $webrun_directory/u1 at the beginning of each repetition of the loop.
#
   %dataset_institution = ();
#
#  Loop which will continue until the file $path_continue_monitor is no longer
#  found.
#
#  For each new hour, the loop will check (in the ftp_process_hour
#  routine) if any FTP-processing are sceduled (looking in the %ftp_events hash).
#  Also, the loop will check for new files in the web upload area
#  (the web_process_uploaded routine).
#
#  After processing, the routine will wait until the system clock arrives at
#  a new fresh hour. Then the loop repeats, and new processing will eventually
#  be perfomed. 
#
   &get_dataset_institution(\%dataset_institution);
   my @ltime = localtime(mmTtime::ttime());
   my $current_day = $ltime[3]; # 1-31
   my $hour_finished = -1;
   $file_in_error_counter = 1;
   while (-e $path_continue_monitor) {
      @ltime = localtime(mmTtime::ttime());
      my $newday = $ltime[3]; # 1-31
      my $current_hour = $ltime[2]; # 0-23
      if ($current_day != $newday) {
         &clean_up_problem_dir();
         &clean_up_repository();
         $file_in_error_counter = 1;
         $hour_finished = -1;
         $current_day = $newday;
      }
      if ($current_hour > $hour_finished) {
         &get_dataset_institution(\%dataset_institution);
         &ftp_process_hour(\%ftp_events,$current_hour);
         &web_process_uploaded();
         @ltime = localtime(mmTtime::ttime());
         $hour_finished = $ltime[2]; # 0-23
      }
      sleep($sleeping_seconds);
   }
}
#
# ----------------------------------------------------------------------------
#
sub read_ftp_events {
#   
#  Load the content of the ftp_events file into a hash.
#   
   my ($eventsref) = @_;
   my $eventsfile = $webrun_directory . '/ftp_events';
   if (-r $eventsfile) {
      open (EVENTS,$eventsfile);
      while (<EVENTS>) {
         chomp($_);
         my $line = $_;
         $line =~ s/^\s+//;
         my @tokens = split(/\s+/,$line);
         if (scalar @tokens >= 4) {
            my $dataset_name = $tokens[0];
            my $wait_minutes = $tokens[1];
            my $days_to_keep_files = $tokens[2];
            $all_ftp_datasets{$dataset_name} = $days_to_keep_files;
            for (my $ix=3; $ix < scalar @tokens; $ix++) {
               my $hour = $tokens[$ix];
               my $eventkey = "$dataset_name $hour";
               $eventsref->{$eventkey} = $wait_minutes;
            }
         }
      }
      close (EVENTS);
   }
}
#
# ----------------------------------------------------------------------------
#
sub ftp_process_hour {
#   
#  Check the FTP upload area.
#
#  For all datasets scheduled to be processed at the current hour, check
#  if the newest file in the dataset have large enough age. If so, process
#  the files in that dataset.
#   
   my ($eventsref,$current_hour) = @_;
   if ($progress_report == 1) {
      print "-------- ftp_process_hour: Entered at current_hour: $current_hour\n";
   }
   my $rex = " 0*$current_hour" . '$';
   my @matches = grep(/$rex/,keys %$eventsref);
   foreach my $eventkey (@matches) {
      my ($dataset_name,$hour) = split(/\s+/,$eventkey);
      my $wait_minutes = $eventsref->{$eventkey};
      my $pattern = '"' . $dataset_name . '_*"';
      my @files_found = &shcommand_array("find $ftp_dir_path -name $pattern");
      if (scalar @files_found == 0 && length($shell_command_error) > 0) {
         &syserror("SYS","find_fails", "", "ftp_process_hour", "");
         next;
      }
      my $current_epoch_time = mmTtime::ttime(); 
      my $age_seconds = 60*60*24;
      %files_to_process = ();
      foreach my $filename (@files_found) {
         if (-r $filename) {
            my @file_stat = stat($filename);
            if (scalar @file_stat == 0) {
               die "Could not stat $filename\n";
            }
#            
#             Get last modification time of file
#             (seconds since the epoch)
#            
            my $modification_time = mmTtime::ttime($file_stat[9]);
            if ($current_epoch_time - $modification_time < $age_seconds) {
               $age_seconds = $current_epoch_time - $modification_time;
            }
            $files_to_process{$filename} = $modification_time;
         }
      }
      my $filecount = scalar (keys %files_to_process);
      if ($filecount > 0) {
         if ($progress_report == 1) {
            print "-------- ftp_process_hour: $filecount files from $dataset_name with age $age_seconds\n";
         }
      }
      if ($filecount > 0 && $age_seconds > 60 * $wait_minutes) {
         my $datestring = &get_date_and_time_string($current_epoch_time - $age_seconds);
         &process_files($dataset_name,'FTP',$datestring);
      }
   }
#   print "Dump av hash all_ftp_datasets:\n";
#   print Dumper(\%all_ftp_datasets);
#
#  Move any file in the ftp upload area not belonging to a dataset to the
#  $problem_dir_path directory (the actual moving is done in the syserror
#  routine). Only move files older than 5 hours. Newer files may be temporary
#  files waiting to be renamed by the uploading software:
#
   my @all_files_found = &shcommand_array("find $ftp_dir_path -type f");
   if (scalar @all_files_found == 0 && length($shell_command_error) > 0) {
      &syserror("SYS","find_fails_2", "", "ftp_process_hour", "");
   } else {
      foreach my $filename (@all_files_found) {
         my $dataset_name;
         if ($filename =~ /([^\/_]+)_[^\/]*$/) {
            $dataset_name = $1; # First matching ()-expression
         }
         if (!defined($dataset_name) || 
                scalar grep($dataset_name eq $_, keys %all_ftp_datasets) == 0) {
            my @file_stat = stat($filename);
            if (scalar @file_stat == 0) {
               die "Could not stat $filename\n";
               &syserror("SYS","Could not stat $filename", "", "ftp_process_hour", "");
            } else {
#            
#             Get last modification time of file
#             (seconds since the epoch)
#            
               my $current_epoch_time = mmTtime::ttime(); 
               my $modification_time = mmTtime::ttime($file_stat[9]);
               if ($current_epoch_time - $modification_time > 60*60*5) {
                  &syserror("SYS","file_with_no_dataset", $filename, "ftp_process_hour", "");
               }
            }
         }
      }
   }
}
#
# ----------------------------------------------------------------------------
#
sub web_process_uploaded {
#   
#  Check the WEB upload area.
#
   my %datasets = ();
   my @files_found = &shcommand_array("find $upload_dir_path -type f");
   if (scalar @files_found == 0 && length($shell_command_error) > 0) {
      &syserror("SYS","find_fails", "", "web_process_uploaded", "");
   }
   foreach my $filename (@files_found) {
      my $dataset_name;
      if ($filename =~ /([^\/_]+)_[^\/]*$/) {
         $dataset_name = $1; # First matching ()-expression
         if (!exists($datasets{$dataset_name})) {
            $datasets{$dataset_name} = [];
         }
         push (@{$datasets{$dataset_name}},$filename);
      }
   }
   foreach my $dataset_name (keys %datasets) {
      my $current_epoch_time = mmTtime::ttime(); 
      my $age_seconds = 60*$upload_age_threshold + 1;
      %files_to_process = ();
      foreach my $filename (@{$datasets{$dataset_name}}) {
         if (-r $filename) {
            my @file_stat = stat($filename);
            if (scalar @file_stat == 0) {
               die "Could not stat $filename\n";
            }
#            
#             Get last modification time of file
#             (seconds since the epoch)
#            
            my $modification_time = mmTtime::ttime($file_stat[9]);
            if ($current_epoch_time - $modification_time < $age_seconds) {
               $age_seconds = $current_epoch_time - $modification_time;
            }
            $files_to_process{$filename} = $modification_time;
         }
      }
      my $filecount = scalar (keys %files_to_process);
      if ($filecount > 0 && $age_seconds > 60 * $upload_age_threshold) {
         my $datestring = &get_date_and_time_string($current_epoch_time - $age_seconds);
         &process_files($dataset_name,'WEB',$datestring);
      }
   }
}
#
# ----------------------------------------------------------------------------
#
sub process_files {
#   
#  Process uploaded files for one dataset from either the FTP or web area.
#  Names of the uploaded files are found in the global %files_to_process hash.
#
#  Uploaded files are either single files or archives (tar). Archives are expanded
#  and one archive file will produce many expanded files. Both single files
#  and archives can be compressed (gzip). All such files are uncompressed.
#  The uncompressed expanded files are either netCDF (*.nc) or CDL (*.cdl).
#  CDL files are converted to netCDF.
#  
#  Arguments:
#
#  $dataset_name     - Name of the dataset
#  $ftp_or_web       - ='FTP' if the files are uploaded through FTP,
#                      ='WEB' if files are uploaded through the web application.
#  $datestring       - Date/time of the last uploaded file as "YYYY-MM-DD HH:MM"
#   
   my ($dataset_name,$ftp_or_web,$datestring) = @_;
#   
   @user_errors = ();
   my %orignames = (); # Connects the names of the expanded files to the full path of the 
                       # original names of the uploaded files.
   my $errors = 0;
   if ($progress_report == 1) {
      print "-------- Files to process for dataset $dataset_name at $datestring\n";
      print Dumper(\%files_to_process);
   }
   if (! exists($dataset_institution{$dataset_name})) {
      foreach my $uploadname (keys %files_to_process) {
         &move_to_problemdir($uploadname);
      }
      &syserror("SYSUSER","dataset_not_initialized", "", "process_files", "Dataset: $dataset_name");
      return;
   }
#
#  Clean up the work_start, work_flat and work_expand directories:
#
   foreach my $dir ($work_start,$work_expand,$work_flat) {
      &shcommand_scalar("rm -rf $dir/*");
      if (length($shell_command_error) > 0) {
         die "Unable to clean up $dir: $shell_command_error";
      }
   }
#
   foreach my $uploadname (keys %files_to_process) {
      $errors = 0;
      my $baseupldname = $uploadname;
      my $extention;
      if ($uploadname =~ /\/([^\/]+)$/) {
         $baseupldname = $1; # First matching ()-expression
      }
      if ($baseupldname =~ /\.([^.]+)$/) {
         $extention = $1; # First matching ()-expression
      }
#      
#     Copy uploaded file to the work_start directory
#      
      if (copy($uploadname,$work_start . '/' . $baseupldname) == 0) {
         die "Copy to workdir did not succeed. Uploaded file: $uploadname Error code: $!\n";
      }
      my $newpath = $work_start . '/' . $baseupldname;
#      
#     Get type of file and act accordingly:
#      
      my $filetype = &shcommand_scalar("file $newpath");
      if (!defined($filetype)) {
         &syserror("SYS","file_command_fails_1", $uploadname, "process_files", "");
         next;
      }
#
      if (index($filetype,"gzip compressed data") >= 0) {
#         
#           Uncompress file:
#         
         my $result = &shcommand_scalar("gunzip $newpath");
         if (!defined($result)) {
            &syserror("SYSUSER","gunzip_problem_with_uploaded_file", $uploadname, "process_files", "");
            $errors = 1;
            next;
         }
         if (defined($extention) && $extention eq "gz") {
#            
#              Strip ".gz" extention from $baseupldname
#            
            $baseupldname = substr($baseupldname,0,length($baseupldname)-3);
            undef $extention;
            if ($baseupldname =~ /\.([^.]+)$/) {
               $extention = $1; # First matching ()-expression
            }
         } elsif (defined($extention) && $extention eq "tgz") {
#            
#              Substitute "tgz" extention with "tar"
#            
            $baseupldname = substr($baseupldname,0,length($baseupldname)-3) . 'tar';
            $extention = 'tar';
         } else {
            &syserror("SYSUSER","uploaded_filename_with_missing_gz_or_tgz", $uploadname, "process_files", "");
            $errors = 1;
            next;
         }
         $newpath = $work_start . '/' . $baseupldname;
         $filetype = &shcommand_scalar("file $newpath");
         if (!defined($filetype)) {
            &syserror("SYS","file_command_fails_2", $uploadname, "process_files", "");
            $errors = 1;
            next;
         }
      }
#
      if (index($filetype,"tar archive") >= 0) {
         if (!defined($extention) || $extention ne "tar") {
            &syserror("SYSUSER","uploaded_filename_with_missing_tar_ext", $uploadname, "process_files", "");
            $errors = 1;
            next;
         }
#         
#        Get all component file names in the tar file:
#         
         my @tarcomponents = &shcommand_array("tar tf $newpath");
         if (length($shell_command_error) > 0) {
            &syserror("SYSUSER","unable_to_unpack_tar_archive", $uploadname, "process_files", "");
            next;
         }
         my %basenames = ();
         my $errcondition = "";
#         
#        Check the component file names:
#         
         foreach my $component (@tarcomponents) {
            if (substr($component,0,1) eq "/") {
               &syserror("USER","uploaded_tarfile_with_abs_pathes",
                         $uploadname, "process_files", "Component: $component");
               $errors = 1;
               next;
            }
            my $basename = $component;
            if ($component =~ /\/([^\/]+)$/) {
               $basename = $1; # First matching ()-expression
            }
            if (exists($basenames{$basename})) {
               &syserror("USER","uploaded_tarfile_with_duplicates",
                         $uploadname, "process_files", "Component: $basename");
               $errors = 1;
               next;
            }
            $basenames{$basename} = 1;
            $orignames{$basename} = $uploadname;
            if (index($basename,$dataset_name . '_') < 0) {
               &syserror("USER","uploaded_tarfile_with_illegal_component_name",
                         $uploadname, "process_files", "Component: $basename");
               $errors = 1;
            }
         }
         if ($errors == 0) {
#            
#           Expand the tar file onto the $work_expand directory
#            
            unless (chdir $work_expand) {
               die "Could not cd to $work_expand: $!\n";
            }
            my $tar_results = &shcommand_scalar("tar xf $newpath");
            if (length($shell_command_error) > 0) {
               &syserror("SYSUSER","tar_xf_fails", $uploadname, "process_files", "");
               next;
            }
#            
#           Move all expanded files to the $work_flat directory, which
#           will not contain any subdirectories. Check that no duplicate
#           file names arise.
#            
            foreach my $component (@tarcomponents) {
               my $bname = $component;
               if ($component =~ /\/([^\/]+)$/) {
                  $bname = $1; # First matching ()-expression
               }
               if (-e $work_flat . '/' . $bname) {
                  &syserror("USER","uploaded_tarfile_with_component_already_encountered",
                            $uploadname, "process_files", "Component: $bname");
                  $errors = 1;
                  next;
               }
               if (move($component,$work_flat) == 0) {
                  die "Move component $component to work_flat. Move did not succeed. Error code: $!\n";
               }
            }
            if ($errors == 1) {
               &syserror("SYS","uploaded_tarfile_with_components_already_encountered",
                         $uploadname, "process_files", "");
            }
         } else {
            &syserror("SYS","errors_in_tar_components", $uploadname, "process_files", "");
            next;
         }
      } else {
#         
#        Move file directly to $work_flat:
#         
         if (-e $work_flat . '/' . $baseupldname) {
            &syserror("SYSUSER","uploaded_file_already_encountered", $uploadname, "process_files", "");
            $errors = 1;
         } else {
            if (move($newpath,$work_flat) == 0) {
               die "Move newpath $newpath to work_flat. Move did not succeed. Error code: $!\n";
            }
            $orignames{$baseupldname} = $uploadname;
         }
      }
   }
#   print "Original upload names of expanden files:\n";
#   print Dumper(\%orignames);
#   
#  All files are now unpacked/expanded and moved to the $work_flat directory:
#   
   unless (chdir $work_flat) {
      die "Could not cd to $work_flat: $!\n";
   }
   &purge_current_directory(\%orignames);
   my @expanded_files = glob("*");
#         
#  Convert CDL files to netCDF:
#         
   $errors = 0;
   my %problem_upl_files = ();
   foreach my $expandedfile (@expanded_files) {
      my $uploadname;
      if (exists($orignames{$expandedfile})) {
         $uploadname = $orignames{$expandedfile};
      } else {
         die "Expanded file $expandedfile have no corresponding upload file\n";
      }
      my $extention;
      if ($expandedfile =~ /\.([^.]+)$/) {
         $extention = $1; # First matching ()-expression
      }
      my $filetype = &shcommand_scalar("file $expandedfile");
      if (length($shell_command_error) > 0) {
         die "file $expandedfile fails: $shell_command_error";
      }
      if (index($filetype,"text") >= 0) {
         my $path_to_remove_cr = $target_directory . '/scripts/remove_cr.sh';
         my $dummy = &shcommand_scalar("$path_to_remove_cr $expandedfile");
         if (length($shell_command_error) > 0) {
            &syserror("SYS","remove_cr_failed",$uploadname, "process_files","");
            $problem_upl_files{$uploadname} = 1;
            $errors = 1;
         }
      }
      if ($errors == 0 && defined($extention) && $extention eq 'cdl' && index($filetype,"text") >= 0) {
         my $firstline = &shcommand_scalar("head -1 $expandedfile");
         if (length($shell_command_error) > 0) {
            die "head -1 $expandedfile fails: $shell_command_error";
         }
         if ($firstline =~ /^\s*netcdf\s/) {
            my $ncname = substr($expandedfile,0,length($expandedfile) - 3) . 'nc';
            if (scalar grep($_ eq $ncname,@expanded_files) > 0) {
               &syserror("USER","cdlfile_collides_with_ncfile_already_encountered",
                         $uploadname, "process_files", "File: $expandedfile");
               $problem_upl_files{$uploadname} = 1;
               $errors = 1;
            } else {
               my $result = &shcommand_scalar("ncgen $expandedfile -o $ncname");
               if (unlink($expandedfile) == 0) {
                  die "Unlink file $expandedfile did not succeed\n";
               }
               if (length($shell_command_error) > 0) {
                  my $diagnostic = $shell_command_error;
                  $diagnostic =~ s/^[^\n]*\n//m;
                  $diagnostic =~ s/\n/ /mg;
                  &syserror("USER","ncgen_fails_on_cdlfile",
                            $uploadname, "process_files",
                            "File: $expandedfile\nCDLfile: $expandedfile\nDiagnostic: $diagnostic");
                  if (-e $ncname && unlink($ncname) == 0) {
                     die "Unlink file $ncname did not succeed\n";
                  }
                  $problem_upl_files{$uploadname} = 1;
                  $errors = 1;
                  next;
               }
            }
         } else {
            &syserror("USER","text_file_with_cdl_extention_not_a_cdlfile",
                      $uploadname, "process_files", "File: $expandedfile");
            $problem_upl_files{$uploadname} = 1;
            $errors = 1;
            next;
         }
      }
   }
   if ($errors == 1) {
      foreach my $uploadname (keys %problem_upl_files) {
         &syserror("SYS","problems_with_cdl_files",$uploadname, "process_files", "");
      }
   }
   &purge_current_directory(\%orignames);
#   
   unless (chdir $work_directory) {
      die "Could not cd to $work_directory: $!\n";
   }
#   
#  Decide if this batch of netCDF files are all new files, or if some of them has been
#  uploaded before. If any re-uploads, find the XML-file representing most of the existing
#  files in the repository that are not affected by re-uploads. Base the digest_nc.pl run
#  on this XML file.
#
   my $command = "find $work_flat -type f -name \"$dataset_name" . '_*" -print';
   my @uploaded_files = &shcommand_array($command);
#   print "Uploaded files:\n";
#   print Dumper(\@uploaded_files);
   if (length($shell_command_error) > 0) {
      &syserror("SYS","find_fails", "", "process_files", "");
   }
   my @uploaded_basenames = &get_basenames(\@uploaded_files);
   my $destination_dir = $opendap_directory . "/" . 
                         $dataset_institution{$dataset_name}->[0] . "/" . $dataset_name;
   $command = "find $destination_dir -type f -name \"$dataset_name" . '_*" -print';
   my @existing_files = &shcommand_array($command);
   if (length($shell_command_error) > 0) {
      &syserror("SYS","find_fails_2", "", "process_files", "");
   }
   my @existing_basenames = &get_basenames(\@existing_files);
   my @reuploaded_basenames = &intersect(\@uploaded_basenames,\@existing_basenames);
   my @reprocess_basenames = ();
   my $xmlpath = $webrun_directory . '/XML/' . $application_id . '/' . $dataset_name . '.xml';
   if (scalar @reuploaded_basenames > 0) {
#
#  Some of the new files have been uploaded before:
#
      @reprocess_basenames = &revert_XML_history($dataset_name,
                                                        \@existing_basenames,
                                                        \@reuploaded_basenames,
                                                        \@uploaded_basenames,
                                                        $xmlpath);
   }
   my @digest_input = ();
   foreach my $fname (@uploaded_files) {
      push (@digest_input,$fname);
   }
   foreach my $fname (@reprocess_basenames) {
      push (@digest_input,$destination_dir . '/' . $fname);
   }
   my $destination_url = $opendap_url;
   if ($destination_url !~ /\/$/) {
      $destination_url .= '/';
   }
   $destination_url .= 'data/' . $dataset_institution{$dataset_name}->[0] . "/" . $dataset_name . "/";
   open (DIGEST,">digest_input");
   print DIGEST $destination_url . "\n";
   foreach my $fname (@digest_input) {
      print DIGEST $fname . "\n";
   }
   close (DIGEST);
   my @originally_uploaded = keys %files_to_process;
#
#  Run the digest_nc.pl script and process user errors if found:
#
   my $path_to_etc = $target_directory . '/etc';
   my $path_to_digest_nc = $target_directory . '/scripts/digest_nc.pl';
#   
#  Run the digest_nc.pl script:
#   
   $command = "$path_to_digest_nc $path_to_etc digest_input $upload_ownertag $xmlpath";
   if ($progress_report == 1) {
      print "RUN:    $command\n";
   }
   my $result = &shcommand_scalar($command);
   if (defined($result)) {
      open (DIGOUTPUT,">digest_out");
      print DIGOUTPUT $result . "\n";
      close (DIGOUTPUT);
   }
   my $usererrors_path = "nc_usererrors.out";
   open (USERERRORS,">>$usererrors_path");
   foreach my $line (@user_errors) {
      print USERERRORS $line;
   }
   close (USERERRORS);
#
   if (length($shell_command_error) > 0) {
      &syserror("SYS","digest_nc_fails", "", "process_files", "");
      foreach my $uploadname (keys %files_to_process) {
         &move_to_problemdir($uploadname);
      }
   } else {
#
#     Move new files to the data repository:
#
      foreach my $filepath (@digest_input) {
         my $bname = $filepath;
         if ($filepath =~ /\/([^\/]+)$/) {
            $bname = $1; # First matching ()-expression
         }
         if ($filepath ne $destination_dir . "/$bname") {
            if (move($filepath,$destination_dir) == 0) {
               &syserror("SYS","Move $filepath to destination_dir did not succeed. Error code: $!",
                         "", "process_files", "");
            }
         }
      }
      if (-z $usererrors_path) {
#
#     No user errors:
#
         &notify_web_system('File accepted ', $dataset_name, \@originally_uploaded, "");
      } else {
#         
#     User errors found (by digest_nc.pl or this script):
#         
         my @bnames = &get_basenames(\@originally_uploaded);
         my $bnames_string = join(", ",@bnames);
         my $timecode = substr($datestring,8,2) . substr($datestring,11,2) . 
                        substr($datestring,14,2);
         my $name_html_errfile = $dataset_name . '_' . $timecode . '.html';
         my $path_to_errors_html = $uerr_directory . '/' . $name_html_errfile;
         my $errorinfo_path = "errorinfo";
         open (ERRORINFO,">$errorinfo_path");
         print ERRORINFO $path_to_errors_html . "\n";
         print ERRORINFO $bnames_string . "\n";
         print ERRORINFO $datestring . "\n";
         close (ERRORINFO);
         my $url_to_errors_html = $local_url . '/upl/uerr/' . $name_html_errfile;
         my $path_to_print_usererrors = $target_directory . '/scripts/print_usererrors.pl';
         my $path_to_usererrors_conf = $path_to_etc . '/usererrors.conf';
#   
#     Run the print_usererrors.pl script:
#   
         my $result = &shcommand_scalar(
              "$path_to_print_usererrors " .
                 "$path_to_usererrors_conf " .
                 "$usererrors_path " .
                 "$errorinfo_path "
            );
         if (length($shell_command_error) > 0) {
            &syserror("SYS","print_usererrors_fails", "", "process_files", "");
         }
         &notify_web_system('Errors found ', $dataset_name, \@originally_uploaded,
                            $url_to_errors_html);
#
#     Send mail to owner of the dataset:
#
         my $recipient = $dataset_institution{$dataset_name}->[1];
         my $username = $dataset_institution{$dataset_name}->[2] . " ($recipient)";
[==TEST_EMAIL_RECIPIENT==]         $recipient = '[==OPERATOR_EMAIL==]'; # <-- Remove this when production ready
         my $external_url = $url_to_errors_html;
         if (substr($external_url,0,7) ne 'http://') {
            $external_url = '[==BASE_PART_OF_EXTERNAL_URL==]' . $url_to_errors_html;
         }
         my $mailbody = '[==EMAIL_BODY_WHEN_UPLOAD_ERROR==]';
         $mailbody =~ s/\[OWNER\]/$username/mg;
         $mailbody =~ s/\[DATASET\]/$dataset_name/mg;
         $mailbody =~ s/\[URL\]/$external_url/mg;
         $mailbody .= "\n";
         $mailbody .= '[==EMAIL_SIGNATURE==]';
         my $subject = '[==EMAIL_SUBJECT_WHEN_UPLOAD_ERROR==]';
         my $sender = '[==FROM_ADDRESS==]';
         my $mailer = Mail::Mailer->new;
         my %headers = ( To => $recipient,
                         Subject => $subject,
                         From => $sender,
                       );
         $mailer->open(\%headers);
         print $mailer $mailbody;
         $mailer->close;
      }
      foreach my $uploadname (keys %files_to_process) {
         if (unlink($uploadname) == 0) {
            &syserror("SYS","Unlink file $uploadname did not succeed","", "process_files", "");
         }
      }
      &update_XML_history($dataset_name,\@uploaded_basenames,\@existing_basenames);
   }
}
#
#---------------------------------------------------------------------------------
#
sub purge_current_directory {
   my ($ref_orignames) = @_;
   foreach my $basename (keys %$ref_orignames) {
      my $upldname = $ref_orignames->{$basename};
      if (! exists($files_to_process{$upldname})) {
         if (-e $basename) {
            if (unlink($basename) == 0) {
               &syserror("SYS","Unlink file $basename did not succeed","", "purge_current_directory", "");
            }
         }
         delete $ref_orignames->{$basename};
      }
   }
}
#
#---------------------------------------------------------------------------------
#
sub revert_XML_history {
   my ($dataset_name,$existing_basenames,$reuploaded_basenames,$uploaded_basenames,$path_to_xml_file) = @_;
#
#  For each dataset,
#  a history file is maintained that tracks the changes to the XML file and the
#  dataset files in the repository that the XML file represents. 
#
#  This history file is constructed by the Dumper utility from a reference to an
#  array ($ref_xml_history).
#  Each element in this array is another reference to an array comprising two elements:
#
#  ->[0] Reference to an array of basenames representing all files that the
#        corresponding XML file describes.
#
#  ->[1] Reference to a scalar containing the XML text
#
#  The XML history array is sorted with the newest basname-set/XML-file first.
#
#  This routine search through the entries in this array to find the first entry 
#  with a basename-set that have no common basenames with the basename-set in the
#  $reuploaded_basenames (array reference). When such an entry is found, the current
#  XML file is reverted to the XML text found in this entry, and the history file
#  is adjusted accordingly. The routine returns an array comprising all basenames
#  in the repository that must be re-processed due to this revertion to an older
#  XML file.
#
   my $xml_history_filename = $xml_history_directory . '/' . $dataset_name . '.hst';
   my $xml_filename = $xml_directory . '/' . $dataset_name . '.xml';
   if (-r $xml_history_filename) {
      open (XMLHISTORY,$xml_history_filename);
#
#  Retrieve a dumped hash reference from file
#  with all referenced data.
#  Will also work on array references.
#
      undef $/;
      my $xml_history = <XMLHISTORY>;
      $/ = "\n";
      my $ref_xml_history = eval($xml_history);
      close (XMLHISTORY);
#
#  Create the new XML history array:
#
      my @new_xml_history = ();
      my $ref_unaffected_basenames;
      foreach my $ref (@$ref_xml_history) {
         my @common_basenames = &intersect($ref->[0], $reuploaded_basenames);
         if (scalar @common_basenames == 0) {
            if (scalar @new_xml_history == 0) {
#         
#              Revert to this older XML-file:
#         
               open (XMLFILE,">$xml_filename");
               print XMLFILE $ref->[1];
               close (XMLFILE);
               print "Dataset $dataset_name : Revert to an older XML file\n";
               $ref_unaffected_basenames = $ref->[0];
            }
            push (@new_xml_history,$ref);
         }
      }
      my @reprocess_basenames = ();
      if (!defined($ref_unaffected_basenames)) {
#      
#        All files for this dataset has to be re-processed. Remove XML- and
#        XML-history files:
#      
         if ($progress_report == 1) {
            print "Dataset $dataset_name : All files for this dataset has to be re-processed\n";
         }
         if (unlink($path_to_xml_file) == 0) {
            &syserror("SYS","Unlink file $path_to_xml_file did not succeed","", "revert_XML_history", "");
         }
         if (unlink($xml_history_filename) == 0) {
            &syserror("SYS","Unlink file $xml_history_filename did not succeed","", "revert_XML_history", "");
         }
         @reprocess_basenames = &subtract($existing_basenames,$reuploaded_basenames);
      } else {
#      
#        Write new XML-history file:
#      
         open (XMLHISTORY,">$xml_history_filename");
         $Data::Dumper::Indent = 1;
         print XMLHISTORY Dumper(\@new_xml_history);
         close (XMLHISTORY);
         @reprocess_basenames = &subtract($existing_basenames,$ref_unaffected_basenames);
      }
      return @reprocess_basenames;
   } else {
      &syserror("SYS","no_XML_history_file", "", "revert_XML_history", "");
      if (unlink($path_to_xml_file) == 0) {
         &syserror("SYS","Unlink file $path_to_xml_file did not succeed","", "revert_XML_history", "");
      }
      return ();
   }
}
#
#---------------------------------------------------------------------------------
#
sub update_XML_history {
   my ($dataset_name,$uploaded_basenames,$existing_basenames) = @_;
#
#  A new XML file has just been created for the dataset. Update the XML
#  history file.
#
   my $xml_history_filename = $xml_history_directory . '/' . $dataset_name . '.hst';
   my $xml_filename = $xml_directory . '/' . $dataset_name . '.xml';
   if (-r $xml_filename) {
      open (XMLFILE,$xml_filename);
      undef $/;
      my $xml_file = <XMLFILE>;
      $/ = "\n";
      close (XMLFILE);
      my @new_xml_history;
      my @old_and_new = &union($uploaded_basenames,$existing_basenames);
      my @new_element = (\@old_and_new,\$xml_file);
      if (-r $xml_history_filename) {
         open (XMLHISTORY,$xml_history_filename);
         undef $/;
         my $xml_history = <XMLHISTORY>;
         $/ = "\n";
         my $ref_xml_history = eval($xml_history);
         close (XMLHISTORY);
	 if (defined($ref_xml_history)) {
            @new_xml_history = (\@new_element,@$ref_xml_history);
	 } else {
            @new_xml_history = (\@new_element);
         }
      } else {
         @new_xml_history = (\@new_element);
      }
#      
#     Write new XML-history file:
#      
      open (XMLHISTORY,">$xml_history_filename");
      $Data::Dumper::Indent = 1;
      print XMLHISTORY Dumper(\@new_xml_history);
      close (XMLHISTORY);
   } else {
      &syserror("SYS","XML file $xml_filename not found", "", "update_XML_history", "");
   }
}
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
         unless (-r $ownerfile) {die "Can not read from file: $ownerfile\n";}
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
# Initialize hash connecting each dataset to a reference to an array with three
# elements:
#
# ->[0] Name of institution as found in an <heading> element within the webrun/u1
#       file for the user that owns the dataset.
# ->[1] The owners E-mail address.
# ->[2] The owners name.
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
      undef $/;
      my $content = <INPUTFILE>;
      $/ = "\n"; 
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
      my @datasets = ($content =~ /<dir dirname=\"[^\"]+\"/mg);
      for (my $ix=0; $ix < scalar @datasets; $ix++) {
         $datasets[$ix] =~ s/<dir dirname=\"//mg;
         $datasets[$ix] =~ s/\"//mg;
         my $dataset_name = $datasets[$ix];
         $ref_dataset_institution->{$dataset_name} = [$institution,$email,$username];
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
sub clean_up_problem_dir {
   my $pattern = '"[0-9]*"';
   my @files_found = &shcommand_array("find $problem_dir_path -name $pattern");
   if (scalar @files_found == 0 && length($shell_command_error) > 0) {
      &syserror("SYS","find_fails", "", "clean_up_problem_dir", "");
   }
#      
#       Find current time (epoch)
#       as number of seconds since the epoch (1970)
#      
   my $current_epoch_time = mmTtime::ttime(); 
   my $age_seconds = 60*60*24*$days_to_keep_errfiles;
   foreach my $filename (@files_found) {
      if (-r $filename) {
         my @file_stat = stat($filename);
         if (scalar @file_stat == 0) {
            &syserror("SYS","Could not stat $filename", "", "clean_up_problem_dir", "");
         }
#            
#             Get last modification time of file
#             (seconds since the epoch)
#            
         my $modification_time = mmTtime::ttime($file_stat[9]);
         if ($current_epoch_time - $modification_time > $age_seconds) {
            if (unlink($filename) == 0) {
               &syserror("SYS","Unlink file $filename did not succeed", "", "clean_up_problem_dir", "");
            }
         }
      }
   }
}
#
#---------------------------------------------------------------------------------
#
sub clean_up_repository {
   my $current_epoch_time = mmTtime::ttime(); 
   foreach my $dataset (keys %all_ftp_datasets) {
      my $days_to_keep_files = $all_ftp_datasets{$dataset};
      if ($days_to_keep_files > 0) {
         if (!exists($dataset_institution{$dataset})) {
            &syserror("SYS","$dataset not in any userfiler", "", "clean_up_repository", "");
            next;
         }
         my $directory = $opendap_directory . "/" . 
                         $dataset_institution{$dataset}->[0] . "/" . $dataset;
         my @files = glob($directory . "/" . $dataset . "_*");
         foreach my $fname (@files) {
            my @file_stat = stat($fname);
            if (scalar @file_stat == 0) {
               &syserror("SYS","Could not stat $fname", "", "clean_up_repository", "");
               next;
            }
#            
#             Get last modification time of file
#             (seconds since the epoch)
#            
            my $modification_time = mmTtime::ttime($file_stat[9]);
            if ($current_epoch_time - $modification_time > 60*60*24*$days_to_keep_files) {
               my @cdlcontent = &shcommand_array("ncdump -h $fname");
               if (length($shell_command_error) > 0) {
                  &syserror("SYS","Could not ncdump -h $fname", "", "clean_up_repository", "");
                  next;
               }
               my $lnum = 0;
               my $lmax = scalar @cdlcontent;
               while ($lnum < $lmax) {
                  if ($cdlcontent[$lnum] eq 'dimensions:') {
                     last;
                  }
                  $lnum++;
               }
               $lnum++;
               while ($lnum < $lmax) {
                  if ($cdlcontent[$lnum] eq 'variables:') {
                     last;
                  }
                  $cdlcontent[$lnum] =~ s/=\s*\d+\s*;$/= 1 ;/;
                  $lnum++;
               }
               if ($lnum >= $lmax) {
                  &syserror("SYS","Error while changing CDL content from $fname",
                            "", "clean_up_repository", "");
                  next;
               }
               open (CDLFILE,">tmp_file.cdl");
               print CDLFILE join("\n",@cdlcontent);
               close (CDLFILE);
               &shcommand_scalar("ncgen tmp_file.cdl -o $fname");
               if (length($shell_command_error) > 0) {
                  &syserror("SYS","Could not ncgen tmp_file.cdl -o $fname", "", "clean_up_repository", "");
                  next;
               }
            }
         }
      }
   }
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
sub syserror {
   my ($type,$errmsg,$uploadname,$where,$what) = @_;
#
#  Find current time
#
   my @ta = localtime();
   my $year = 1900 + $ta[5];
   my $mon = $ta[4] + 1; # 1-12
   my $mday = $ta[3]; # 1-31
   my $hour = $ta[2]; # 0-23
   my $min = $ta[1]; # 0-59
   my $datestring = sprintf ('%04d-%02d-%02d %02d:%02d',$year,$mon,$mday,$hour,$min);
#
   my $baseupldname = $uploadname;
   if ($uploadname =~ /\/([^\/]+)$/) {
      $baseupldname = $1; # First matching ()-expression
   }
#
   if ($type eq "SYS" || $type eq "SYSUSER") {
#
#     Write message to error log:
#
      open (OUT,">>$path_to_syserrors");
      flock (OUT, LOCK_EX);
      print OUT "-------- $type $datestring IN: $where\n" .
                "         $errmsg\n";
      if ($uploadname ne "") {
         print OUT "         Uploaded file: $uploadname\n";
      }
      if ($what ne "") {
         print OUT "         $what\n";
      }
      if ($shell_command_error ne "") {
         print OUT "         Stderr: $shell_command_error\n";
      }
      close (OUT);
      if ($uploadname ne "") {
#
#        Move upload file to problem file directory:
#
         &move_to_problemdir($uploadname);
      }
   }
   if ($type eq "USER" || $type eq "SYSUSER") {
      push(@user_errors, "$errmsg\nUploadfile: $baseupldname\n$what\n\n");
   }
   $shell_command_error = "";
};
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
sub move_to_problemdir {
   my ($uploadname) = @_;
   my $baseupldname = $uploadname;
   if ($uploadname =~ /\/([^\/]+)$/) {
      $baseupldname = $1; # First matching ()-expression
   }
#
#  Move upload file to problem file directory:
#
   my @file_stat = stat($uploadname);
   if (scalar @file_stat == 0) {
      die "In move_to_problemdir: Could not stat $uploadname\n";
   }
   my $modification_time = mmTtime::ttime($file_stat[9]);
   my @ltime = localtime(mmTtime::ttime());
   my $current_day = $ltime[3]; # 1-31

   my $destname = sprintf('%02d%04d',$current_day,$file_in_error_counter++) . "_" .
                  $baseupldname;
   my $destpath = $problem_dir_path . "/" . $destname;
   if (move($uploadname,$destpath) == 0) {
      die "In move_to_problemdir: $uploadname Move did not succeed. Error code: $!\n";
   }
#
#     Write message to files_with_errors log:
#
   my $datestring = &get_date_and_time_string($modification_time);
   my $path = $problem_dir_path . "/files_with_errors";
   open (OUT,">>$path");
   print OUT "File: $uploadname modified $datestring copied to $destname\n";
   close(OUT);
#
   if (exists($files_to_process{$uploadname})) {
      delete $files_to_process{$uploadname};
   }
};
#
#---------------------------------------------------------------------------------
#
# sub my_time {
#    my $realtime;
#    if (scalar @_ == 0) {
#       $realtime = time;
#    } else {
#       $realtime = $_[0];
#    }
#    my $scaling = [==TEST_IMPORT_SPEEDUP==];
#    if ($scaling <= 1) {
#       return $realtime;
#    } else {
#       my $basistime = [==TEST_IMPORT_BASETIME==];
#       return $basistime + ($realtime - $basistime)*$scaling;
#    }
# };
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
