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
use warnings;
use File::Spec;
# small routine to get lib-directories relative to the installed file
sub getTargetDir {
    my ($finalDir) = @_;
    my ($vol, $dir, $file) = File::Spec->splitpath(__FILE__);
    $dir = $dir ? File::Spec->catdir($dir, "..") : File::Spec->updir();
    $dir = File::Spec->catdir($dir, $finalDir); 
    return File::Spec->catpath($vol, $dir, "");
}

use lib ('../../common/lib', getTargetDir('lib'), getTargetDir('scripts'));

use File::Copy;
use File::Path;
use File::Spec;
use Fcntl qw(LOCK_SH LOCK_UN LOCK_EX);
use Data::Dumper;
use Mail::Mailer;
use mmTtime;
use Metamod::Utils qw(findFiles getFiletype remove_cr_from_file);
use Uploadutils qw(notify_web_system
                   get_dataset_institution
                   shcommand_scalar
                   get_basenames
                   get_date_and_time_string
                   string_found_in_file
                   current_time
                   syserror
                   $config
                   $progress_report
                   $webrun_directory
                   $work_directory
                   $uerr_directory
                   $upload_ownertag
                   $application_id
                   $xml_directory
                   $target_directory
                   $local_url
                   $shell_command_error
                   @user_errors);
$| = 1;
#
#  upload_indexer.pl
#  -----------------
#
#  Simplified version of upload_monitor.pl. The data provider is responsible
#  for uploading files directly to the data repository. This script will extract
#  metadata from files in the data repository and create/update XML/XMD files
#  (using digest_nc.pl), and send error reports to the data provider if 
#  neccessary.
#
#  The script is started from the Apache/PHP web server in the following way:
#
#  upload_indexer.pl --dataset=XX --dirkey=YY file1 file2 file3 ...
#
#  The arguments to this command have the following interpretation:
#
#  XX  - is the dataset name. The data provider must have created the dataset
#        in the "File Upload" web dialogue before this script is used.
#
#  YY  - Directory key for the dataset.  The data provider must have created
#        a directory key for the dataset when the dataset was created.
#
#  file1 file2 file3 ...
#      - Files (residing in the directory given by the $location value - see 
#        below) to be included in the dataset.
#
#  All files must be individual netCDF-files. They may be compressed (by gzip), but
#  CDL or tar archives are not accepted. File extentions must be '.nc' or '.nc.gz'.
#  
#  The dataset value is used to fetch information about the dataset from the
#  %dataset_institution hash. This hash contains the directory key, location and
#  catalog URL (eventually also the WMS URL) for the dataset.
#
#  The location and catalog URL are assigned to variables $location and
#  $catalogurl. The $location value represents the full path to the (locally
#  accessible) directory where the dataset files are found.
#
#  The $catalogurl represents an URL used to access the THREDDS server. It is
#  composed as follows:
#
#  http://some.thredds.server/path/catalog.html?dataset=urlpath
#
#  Using this URL, it is possible to construct two other URL's that are those 
#  actually used to access the THREDDS server:
#
#  - URL to access the dataset:
#    http://some.thredds.server/path/catalog.html
#    I.e, the '?dataset=urlpath' is discarded.
#
#  - URL to access each file: 
#    http://some.thredds.server/path/catalog.html?dataset=urlpath/fileX
#    I.e, a slash and the file name is appended to the $catalogurl value.
#    (fileX represents any of the file1 file2 file3 ... command line arguments).
#
#  Error handling:
#  
#  Various errors may arise during this file processing operation. The errors are
#  divided into four different categories:
#
#  1. Errors arising from external system environment. Such errors will usually not
#     occur. They will only arise if system resources are exhausted, or if anything
#     happens to the file system (like permission changes on important files and
#     directories). If any such error arise, the script will die (with return code 1)
#     and an abortion error message will be recorded in the system error log.
#  
#  2. User errors that makes furher prosessing of a file impossible. The file may
#     not exist, or the file format may not be netCDF.
#
#  3. Other user errors. These are mainly caused by non-complience with the 
#     requirements found in the conf_digest_nc.xml file.
#
#  Errors of type 2 and 3 are conveyed to the user through the nc_usererrors.out file.
#  A summary of this file is constructed in the form of a self-explaining HTML file
#  (using the print_usererrors.pl script).
#
my $path_to_etc = $target_directory . '/etc';
my $usererrors_path = "nc_usererrors.out";
my %dataset_institution;     # Updated in sub get_dataset_institution
my $file_in_error_counter;
my $dataset_name = "";
my $dirkey = "";
my $dirpath = "";
my @files_arr = ();
my @temporary_files_to_remove = ();
#
#  Open OUT for progress reporting, and redirect STDERR to OUT:
#
my $stdout_file = $webrun_directory . "/upload_indexer.out";
my $date_and_time = &get_date_and_time_string();
open(OUT,'>>',$stdout_file);
open(STDERR,'>>&OUT');
print OUT "---------- $date_and_time: Starting upload_indexer.pl with PID= $$\n";
#
eval {
   &do_indexing();
};
if ($@) {
   my $errmessage = $@;
   &unlink_temporary_files();
   print OUT "---------- PID= $$ aborted: $errmessage\n";
   &syserror("SYS", "upload_indexer.pl ABORTED: " . $errmessage, "", "", "");
   &user_report();
   close(OUT);
   my $jpos = index($errmessage,"!");
   if ($jpos >= 0) {
      $errmessage = substr($errmessage,0,$jpos);
   }
   print $errmessage;
   exit 1;
} else {
   &unlink_temporary_files();
   &user_report();
   print OUT "---------- PID= $$ stops\n";
   close(OUT);
   print "OK, files registered";
   exit 0;
}
sub do_indexing {
#
#  Loop through all command line arguments
#
   foreach my $arg (@ARGV) {
      if (substr($arg,0,2) eq '--') {
         if ($arg =~ /^--(\w+)=(.*)$/) {
            my $key = $1;
            my $value = $2;
            if ($key eq 'dataset') {
               $dataset_name = $value;
            } elsif ($key eq 'dirkey') {
               $dirkey = $value;
            } else {
               die("Internal system error!$0 : Unknown command line option: $arg");
            }
         } else {
            die("Internal system error!$0 : Command line option syntax error: $arg");
         }
      } else {
         push (@files_arr,$arg);
      }
   }
#
#  Make sure static directories exists:
#
   foreach my $directory ($work_directory,$uerr_directory,$xml_directory) {
      mkpath($directory);
   }
#
#  Change to work directory
#
   unless (chdir $work_directory) {
      die "Internal system error!Could not cd to $work_directory: $!\n";
   }
#
#  Remove user error file from previous run:
#
   if (-e $usererrors_path) {
      if (unlink($usererrors_path) == 0) {
         print OUT "Unlink file $usererrors_path did not succeed\n";
      }
   }
#
#  Initialize hash that contain the institution code for each dataset.
#  The hash will be filled with info from the directory $webrun_directory/u1.
#
   %dataset_institution = ();
   &get_dataset_institution(\%dataset_institution);
#   
#  Process files:
#   
   &process_files();
}

sub process_files {
   my $errors = 0;
   if ($progress_report == 1) {
      print OUT "-------- Command invocation:\n";
      print OUT $0 . " " . join(" ",@ARGV) . "\n";
   }
   if (! exists($dataset_institution{$dataset_name})) {
      &syserror("SYS","dataset_not_initialized", "", "process_files", "Dataset: $dataset_name");
      @files_arr = ();
      die "Dataset $dataset_name not found!";
   }
   my $ref_datasetinfo = $dataset_institution{$dataset_name};
   if (exists($ref_datasetinfo->{'key'}) && $ref_datasetinfo->{'key'} ne $dirkey) {
      &syserror("SYSUSER","wrong_directory_key", "", "process_files", "Dataset: $dataset_name");
      @files_arr = ();
      die "Wrong directory key (dirkey)!";
   }
   if (! exists($ref_datasetinfo->{'location'})) {
      &syserror("SYSUSER","dataset_no_access_information", "", "process_files", "Dataset: $dataset_name");
      @files_arr = ();
      die "No access information found for dataset $dataset_name!";
   }
   if ($config->get('WMS_XML') ne "" && ! exists($ref_datasetinfo->{'wmsurl'})) {
      &syserror("SYSUSER","dataset_no_wmsurl", "", "process_files", "Dataset: $dataset_name");
      @files_arr = ();
      die "No URL to WMS found for dataset $dataset_name!";
   }
   if ($errors == 0) {
      my $dirpath = $ref_datasetinfo->{'location'};
      my $catalogurl = $ref_datasetinfo->{'catalog'};
      my $wmsurl;
      if ($config->get('WMS_XML') ne "") {
         $wmsurl = $ref_datasetinfo->{'wmsurl'};
      }
#
      my @digest_input = ();
      my $filecount = scalar @files_arr;
      for (my $ix=0; $ix < $filecount; $ix++) {
         my $filename = $files_arr[$ix];
         my $filepath = $filename;
         if (substr($filepath,0,1) ne '/') {
            $filepath = $dirpath . '/' . $filename;
            $files_arr[$ix] = $filepath;
         }
         $errors = 0;
         if (! -e $filepath) {
            &syserror("SYSUSER","file_not_in_repository", "", "process_files", "File: $filepath\n Dataset: $dataset_name");
            $files_arr[$ix] = "";
            die "File $filepath not found!";
         } elsif (! -r $filepath) {
            &syserror("SYSUSER","file_not_readable", "", "process_files", "File: $filepath\nDataset: $dataset_name");
            $files_arr[$ix] = "";
            die "No read access to file $filepath!";
         } elsif (-d $filepath) {
            &syserror("SYSUSER","file_is_a_directory", "", "process_files", "File: $filepath\nDataset: $dataset_name");
            $files_arr[$ix] = "";
            die "$filepath is a directory!";
         }
#      
#     Get type of file and act accordingly:
#      
         my $filetype = getFiletype($filepath);
         if ($progress_report == 1) {
            print OUT "     Processing $filepath Filtype: $filetype\n";
         }
#
         my $newpath; # Set if the file is compressed, to the new path of the uncompressed file.
         if ($filetype =~ /^gzip/) { # gzip or gzip-compressed
            my (undef, undef, $baseupldname) = File::Spec->splitpath($filepath);
#      
#     Copy file to the work directory and uncompress:
#      
            $newpath = File::Spec->catfile($work_directory, $baseupldname);
            if (copy($filepath, $newpath) == 0) {
               die "Internal system error!Copy to workdir did not succeed. File: $filepath Error code: $!\n";
            }
            my $result = &shcommand_scalar("gunzip $newpath");
            if (!defined($result)) {
               &syserror("SYSUSER","gunzip_problem_with_uploaded_file", $filepath, "process_files", "");
               push (@temporary_files_to_remove,$newpath);
               die "Error when uncompressing file $filepath !";
            }
            my $extension;
            if ($newpath =~ /\.([^.]+)$/) {
               $extension = $1; # First matching ()-expression
            }
            if (defined($extension) && ($extension eq "gz" || $extension eq "GZ")) {
               $newpath = substr($newpath,0,length($newpath)-3);
            }
            push (@temporary_files_to_remove,$newpath);
            $filetype = getFiletype($newpath);
         }
         if ($filetype ne 'nc3') { # Not netCDF 3 file
            &syserror("SYSUSER","file_is_not_netcdf3", "", "process_files", "File: $filepath\nDataset: $dataset_name");
            die "File $filepath is not a netCDF file!";
         }
         if ($errors == 0) {
            if (defined($newpath)) {
               push (@digest_input,$newpath);
            } else {
               push (@digest_input,$filepath);
            }
         }
      }
      if (scalar @digest_input == 0) {
         if ($progress_report == 1) {
            print OUT "     No files\n";
         }
      }
      open (DIGEST,">digest_input");
      my $threddscatalog = $catalogurl;
      if ($catalogurl =~ /^([^?]*)\?/) {
         $threddscatalog = $1; # First matching ()-expression
      }
      if (defined($wmsurl)) {
         print DIGEST $threddscatalog . ' ' . $wmsurl . "\n";
      } else {
         print DIGEST $threddscatalog . "\n";
      }
      foreach my $fname (@digest_input) {
         print DIGEST $fname . "\n";
      }
      close (DIGEST);
#
#  Run the digest_nc.pl script and process user errors if found:
#
      my $path_to_digest_nc = $target_directory . '/scripts/digest_nc.pl';
      my $xmlpath = File::Spec->catfile($webrun_directory,
                                     'XML',
                                     $application_id,
                                     $dataset_name . '.xml');
#   
#  Run the digest_nc.pl script:
#   
      my $command = "$path_to_digest_nc $path_to_etc digest_input $upload_ownertag $xmlpath";
      if ($progress_report == 1) {
         print OUT "RUN:    $command\n";
      }
      my $result = &shcommand_scalar($command);
      if (defined($result)) {
         open (DIGOUTPUT,">digest_out");
         print DIGOUTPUT $result . "\n";
         close (DIGOUTPUT);
      }
#
      if (length($shell_command_error) > 0) {
         &syserror("SYS","digest_nc_fails", "", "process_files", "");
         die "Not able to parse the files (digest_nc fails)!";
      }
#
#     Run digest_nc again for each file with output to dataset/file.xml
#     this creates the level 2 (children) xml-files
#
      my $ix2 = 0;
      foreach my $filepath (@digest_input) {
         my $origpath = $files_arr[$ix2];
         my (undef, undef, $basename) = File::Spec->splitpath($origpath);
         my $localpath = $basename;
         if (index($origpath,$dirpath) == 0) {
            $localpath = substr($origpath,length($dirpath));
            if (substr($localpath,0,1) eq '/') {
               $localpath = substr($localpath,1);
            }
         }
         my $fileURL;
         if ($threddscatalog eq $catalogurl) {
            $fileURL = $threddscatalog; # User has not provided a complete catalog URL
                                        # (containing ?dataset=...) Use instead same URL
                                        # as for the directory level dataset.
         } else {
            my $new_catalogurl = $catalogurl;
            if ($localpath =~ m:^(.*/)[^/]*$:) {
               my $localdir = $1; # First matching ()-expression
               my $substval = $localdir . 'catalog.html';
               $new_catalogurl =~ s/catalog\.html/$substval/;
            }
            $fileURL = $new_catalogurl . '/' . $localpath;
         }
         open (my $digest, ">digest_input");
         if (defined($wmsurl)) {
            print $digest $fileURL . ' ' . $wmsurl . '/' . $localpath . "\n";
         } else {
            print $digest $fileURL, "\n";
         }
         print $digest $filepath, "\n";
         close $digest;
         my (undef, undef, $pureFile) = File::Spec->splitpath($filepath);
         $pureFile =~ s/\.[^.]*$//; # remove extension
         my $xmlFileDir = substr $xmlpath, 0, length($xmlpath)-4; # remove .xml
         if (! -d $xmlFileDir) {
            if (!mkdir($xmlFileDir)) {
             	syserror("SYS", "mkdir_fails", $filepath, "process_files", "mdkir $xmlFileDir");
               	die "Internal system error!";
            }
         }
         my $xmlFilePath = File::Spec->catfile($xmlFileDir, $pureFile . '.xml');
         my $digestCommand = "$path_to_digest_nc $path_to_etc digest_input $upload_ownertag $xmlFilePath isChild";
         print OUT "RUN:    $digestCommand\n" if $progress_report == 1;
         shcommand_scalar($digestCommand);
         if (length($shell_command_error) > 0) {
          	syserror("SYS", "digest_nc_file_fails", $filepath, "process_files", "");
            die "Not able to parse a file (digest_nc fails on $filepath)!";
         }
         $ix2++;
      }
   }
}

sub unlink_temporary_files {
   foreach my $path (@temporary_files_to_remove) {
      unlink($path);
   }
}

sub user_report {
   if (! exists($dataset_institution{$dataset_name})) {
      return 1;
   }
   my @old_files_arr = @files_arr;
   @files_arr = ();
   foreach my $fname (@old_files_arr) {
      if ($fname ne "") {
         push (@files_arr,$fname);
      }
   }
   open (USERERRORS,">>$usererrors_path");
   foreach my $line (@user_errors) {
      print USERERRORS $line;
   }
   close (USERERRORS);
#
#  Check if errors were found. Eventually send E-mail to user.
#
   my $url_to_errors_html = "";
   my $mailbody;
   my $subject = $config->get('EMAIL_SUBJECT_WHEN_UPLOAD_ERROR');
   my $dont_send_email_to_user = 
         &string_found_in_file($dataset_name,$webrun_directory . '/' . 'datasets_for_silent_upload');
   if (-z $usererrors_path) {
#
#     No user errors:
#
         if ($dont_send_email_to_user) {
            &notify_web_system('Operator reload ', $dataset_name, \@files_arr,"");
         } else {
            &notify_web_system('File accepted ', $dataset_name, \@files_arr, "");
         }
   } else {
#         
#     User errors found (by digest_nc.pl or this script):
#         
      $mailbody = $config->get('EMAIL_BODY_WHEN_UPLOAD_ERROR');
      my @bnames = &get_basenames(\@files_arr);
      my $bnames_string = join(", ",@bnames);
      my $datestring = &current_time();
      my $timecode = substr($datestring,8,2) . substr($datestring,11,2) . 
                     substr($datestring,14,2);
      my $name_html_errfile = $dataset_name . '_' . $timecode . '.html';
      my $path_to_errors_html = File::Spec->catfile($uerr_directory, $name_html_errfile);
      my $errorinfo_path = "errorinfo";
      open (ERRORINFO,">$errorinfo_path");
      print ERRORINFO $path_to_errors_html . "\n";
      print ERRORINFO $bnames_string . "\n";
      print ERRORINFO $datestring . "\n";
      close (ERRORINFO);
      $url_to_errors_html = $local_url . '/upl/uerr/' . $name_html_errfile;
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
         return 1;
      }
      if ($dont_send_email_to_user) {
         &notify_web_system('Operator reload ', $dataset_name, \@files_arr,"");
      } else {
         &notify_web_system('Errors found ', $dataset_name, \@files_arr,
                      $url_to_errors_html);
      }
   }
   if (defined($mailbody)) {
#
#     Send mail to owner of the dataset:
#
      my $recipient = $dataset_institution{$dataset_name}->{'email'};
      my $username = $dataset_institution{$dataset_name}->{'name'} . " ($recipient)";
      if ((!$config->get('TEST_EMAIL_RECIPIENT')) || $dont_send_email_to_user) {
         $recipient = $config->get('OPERATOR_EMAIL');
      }
      if ($config->get('TEST_EMAIL_RECIPIENT') ne '0') {
         my $external_url = $url_to_errors_html;
         if (substr($external_url,0,7) ne 'http://') {
            $external_url = $config->get('BASE_PART_OF_EXTERNAL_URL') . $url_to_errors_html;
         }
         $mailbody =~ s/\[OWNER\]/$username/mg;
         $mailbody =~ s/\[DATASET\]/$dataset_name/mg;
         $mailbody =~ s/\[URL\]/$external_url/mg;
         $mailbody .= "\n";
         $mailbody .= $config->get('EMAIL_SIGNATURE');
         my $sender = $config->get('FROM_ADDRESS');
         my $mailer = Mail::Mailer->new;
         my %headers = ( To => $recipient,
                         Subject => $subject,
                         From => $sender,
                       );
         $mailer->open(\%headers);
         print $mailer $mailbody;
         $mailer->close;
      }
   }
};
