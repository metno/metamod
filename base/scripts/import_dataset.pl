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
# use strict;
use XML::Simple qw(:strict);
use Data::Dumper;
use DBI;
#
#  Import datasets from XML files into the database.
#
#  With no command line arguments, this program will enter a loop
#  while monitoring a number of directories (@importdirs) where XML files are
#  found. As new XML files are created or updated in these directories,
#  they are imported into the database. The loop will continue as long as
#  the file [==WEBRUN_DIRECTORY==]/CONTINUE_XML_IMPORT exists.
#
#  With one command line argument, the program will import the XML file
#  given by this argument.
#
my $progress_report = [==TEST_IMPORT_PROGRESS_REPORT==]; # If == 1, prints what
                                                         # happens to stdout
my $sleeping_seconds = 14;
if ([==TEST_IMPORT_SPEEDUP==] > 1) {
   $sleeping_seconds = 1;
}
my $importdirs_string = '[==IMPORTDIRS==]';
my @importdirs = split(/\n/,$importdirs_string);
my $path_to_import_updated = '[==WEBRUN_DIRECTORY==]/import_updated';
my $path_to_import_updated_new = '[==WEBRUN_DIRECTORY==]/import_updated.new';
my $path_to_logfile = '[==LOGFILE==]';
my $continue_xml_import = '[==WEBRUN_DIRECTORY==]/CONTINUE_XML_IMPORT';
#
#  Check number of command line arguments
#
if (scalar @ARGV > 1) {
   die "\nUsage:\n\n   Import single XML file:     $0 filename\n" .
                   "   Infinite monitoring loop:   $0\n\n";
}
my $inputfile;
if (scalar @ARGV == 1) {
   $inputfile = $ARGV[0];
}
#
#  Connect to PostgreSQL database:
#
my $dbname = "[==DATABASE_NAME==]";
my $user = "admin";
local $dbh = DBI->connect("dbi:Pg:dbname=" . $dbname . " [==PG_CONNECTSTRING_PERL==]", $user, "");
#
#  Use full transaction mode. The changes has to be committed or rolled back:
#
$dbh->{AutoCommit} = 0;
$dbh->{RaiseError} = 1;
#
#  Set up a conversion table (hash) for 
#  converting characters >159 to HTML entities:
#
   my %html_conversions = ();
   for (my $jnum=160; $jnum < 256; $jnum++) {
      $html_conversions{chr($jnum)} = '&#' . $jnum . ';';
   }
#
if (defined($inputfile)) {
#
#  Evaluate block to catch runtime errors
#  (including "die()")
#
   eval {
      &update_database($inputfile);
   };
#
#  Check error string returned from eval
#  If not empty, an error has occured
#
   if ($@) {
      warn $@;
      $dbh->rollback or die $dbh->errstr;
      &write_to_log("$inputfile (single file) database error: $@");
   } else {
      $dbh->commit or die $dbh->errstr;
      &write_to_log("$inputfile successfully imported (single file)");
   }
} else {
   &process_xml_loop();
}

# ------------------------------------------------------------------
sub process_xml_loop {
#   
#  Infinite loop that checks for new or modified XML files as long as
#  the file $continue_xml_import exists.
#   
   &write_to_log("Check for new datasets");
   while (-e $continue_xml_import) {
#      
#        Find current time
#      
      my @timearr = localtime(&my_time());
      my $hour = $timearr[2]; # 0-23
      my $min = $timearr[1]; # 0-59
#
      if ($min < 50) {
#
#       At least 10 minutes are remaining of the current clock hour. 
#       It will be safe to start an import batch. It will finish within this
#       clock hour.
#
#       The file $path_to_import_updated was last modified in the previous 
#       turn of this loop. All XML files that are modified later are candidates
#       for import in the current turn of the loop.
#       Get the modification time corresponding to the previous turn of the loop:
#      
         my @status = stat($path_to_import_updated);
         if (scalar @status == 0) {
            die "Could not stat $path_to_import_updated\n";
         }
         my $last_updated = $status[9]; # Seconds since the epoch
#
#        Remember the current time by touching the file
#        $path_to_import_updated_new (it will be created if it does not
#        exist).
#        Later, if a new batch of XML files are imported, transfer this
#        modification time to $path_to_import_updated.
#
         `touch $path_to_import_updated_new`;
#
         my @files_to_consume = ();
#         
         foreach my $xmldir (@importdirs) {
            my $xmldir1 = $xmldir;
            $xmldir1 =~ s/^ *//g;
            $xmldir1 =~ s/ *$//g;
            if (-d $xmldir1) {
               my @newfiles = glob("$xmldir1/*");
               foreach my $file (@newfiles) {
#                  
#                   Check if the file is modified after the 
#                   modification time of $path_to_import_updated.
#                  
                  my @status = stat($file);
                  if (scalar @status == 0) {
                     die "Could not stat $file\n";
                  }
                  my $modified = $status[9];
                  if ($modified > $last_updated) {
                     if ($progress_report == 1) {
                        print "      $file -accepted\n";
                     }
                     push (@files_to_consume,$file);
                  }
               }
            }
         }
         if (scalar @files_to_consume > 0) {
            my %xml_directories = ();
            foreach my $xmlfile (@files_to_consume) {
               if ($xmlfile =~ /^(.+)\/[^\/]*$/) {
                  $xml_directories{$1} = 1;
               }
            }
#         
#           Touch the $path_to_import_updated file to prepare for the next
#           turn of the loop:
#         
            `touch --reference=$path_to_import_updated_new $path_to_import_updated`;
#
            foreach my $xmlfile (@files_to_consume) {
               eval {
                  &update_database($xmlfile);
               };
               if (defined($@) && $@) {
                  $dbh->rollback or die $dbh->errstr;
                  my $stm = $dbh->{"Statement"};
                  &write_to_log("$xmlfile database error: $@\n   Statement: $stm");
               } else {
                  $dbh->commit or die $dbh->errstr;
                  &write_to_log("$xmlfile successfully imported");
               }
            }
         }
      }
      sleep($sleeping_seconds);
   }
#   
#     Subroutine call: write_to_log
#   
   &write_to_log("Check for new datasets stopped");
}
# ------------------------------------------------------------------
sub write_to_log {
#   
#     Split argument array into variables
#   
   my ($message) = @_;
#   
#     Open file for writing
#   
   open (LOG,">>$path_to_logfile");
#   
#     Find current time
#   
   my @timearr = localtime;
   my $year = 1900 + $timearr[5];
   my $mon = $timearr[4] + 1; # 1-12
   my $mday = $timearr[3]; # 1-31
   my $hour = $timearr[2]; # 0-23
   my $min = $timearr[1]; # 0-59
#   
#     Create a string using printf-compatible format:
#   
   my $datetime = sprintf('%04d-%02d-%02d %02d:%02d',$year, $mon, $mday, $hour, $min);
   print LOG "$datetime\n   $message\n";
   close (LOG);
}
# ------------------------------------------------------------------
sub update_database {
#
#  Convert input XML file to a hash (using XML::Simple):
#
   my $inputfile = $_[0];
   unless (-r $inputfile) {die "Can not read from file: $inputfile\n";}
   open (XMLINPUT,$inputfile);
   flock(XMLINPUT, LOCK_SH);
   undef $/;
   my $xmlcontent = <XMLINPUT>;
   $/ = "\n"; 
   close (XMLINPUT); # also unlocks
   my $xmlref = XMLin($xmlcontent, KeyAttr => [], ForceArray => 1, SuppressEmpty => '');
   my $ownertag = $xmlref->{'ownertag'};
#   print Dumper($xmlref);
#   return;
#
#  Create hash with existing references in the database:
#
   my %references = ();
   my $stm;
   $stm = $dbh->prepare("SELECT DS_name,DS_id FROM DataSet WHERE DS_parent = 0 AND DS_ownertag = '$ownertag'");
   $stm->execute();
   while ( my @row = $stm->fetchrow_array ) {
      $references{$row[0]} = [$row[1]];
   }
#
#  Create hash mapping the correspondence between MetadataType name 
#  and SearchCategory
#
   my %searchcategories = (
      variable => 3,
      area => 2,
      activity_type => 1,
      institution => 7,
      datacollection_period => 8,
      operational_status => 10,
   );
#
#  Create the datestamp for the current date:
#
   my @timearr = localtime(&my_time());
   my $datestamp = sprintf('%04d-%02d-%02d',1900+$timearr[5],1+$timearr[4],$timearr[3]);
#
#  Create hash with all existing basic keys in the database.
#  The keys in this hash have the form: 'SC_id:BK_name' and
#  the values are the corresponding 'BK_id's.
#
   my %basickeys = ();
   $stm = $dbh->prepare("SELECT BK_id,SC_id,BK_name FROM BasicKey");
   $stm->execute();
   while ( my @row = $stm->fetchrow_array ) {
      my $key = $row[1] . ':' . $row[2];
      $basickeys{$key} = $row[0];
   }
#
#  Create hash with existing metadata in the database that may be shared between
#  datasets. The keys in this hash have the form: 'MT_name:MD_content' and
#  the values are the corresponding 'MD_id's.
#
   my %metadata = ();
   $stm = $dbh->prepare("SELECT Metadata.MT_name,MD_content,MD_id FROM Metadata, MetadataType " .
                        "WHERE Metadata.MT_name = MetadataType.MT_name AND " .
                        "MetadataType.MT_share = TRUE");
   $stm->execute();
   while ( my @row = $stm->fetchrow_array ) {
      my $key = $row[0] . ':' . $row[1];
      $metadata{$key} = $row[2];
   }
#
#  Create hash with all MetadataTypes that prescribes sharing of common metadata
#  values between datasets.
#
   my %shared_metadatatypes = ();
   $stm = $dbh->prepare("SELECT MT_name FROM MetadataType WHERE MT_share = TRUE");
   $stm->execute();
   while ( my @row = $stm->fetchrow_array ) {
      $shared_metadatatypes{$row[0]} = 1;
   }
#
#  Create hash with the rest of the MetadataTypes (i.e. no sharing).
#
   my %rest_metadatatypes = ();
   $stm = $dbh->prepare("SELECT MT_name FROM MetadataType WHERE MT_share = FALSE");
   $stm->execute();
   while ( my @row = $stm->fetchrow_array ) {
      $rest_metadatatypes{$row[0]} = 1;
   }
#
#  Prepare SQL statements for repeated use.
#  Use "?" as placeholders in the SQL statements:
#
   my $sql_getkey_DS = $dbh->prepare("SELECT nextval('DataSet_DS_id_seq')");
   my $sql_getkey_GA = $dbh->prepare("SELECT nextval('GeographicalArea_GA_id_seq')");
   my $sql_delete_DS = $dbh->prepare("DELETE FROM DataSet WHERE DS_id = ? OR DS_parent = ?");
   my $sql_delete_GA = $dbh->prepare(
      "DELETE FROM GeographicalArea WHERE GA_id IN " .
      "(SELECT GA_id FROM GA_Describes_DS AS g, DataSet AS d WHERE " .
      "g.DS_id = d.DS_id AND (d.DS_id = ? OR d.DS_parent = ?))");
   my $sql_insert_DS = $dbh->prepare(
      "INSERT INTO DataSet (DS_id, DS_name, DS_parent, DS_status, DS_datestamp, DS_ownertag)" .
      " VALUES (?, ?, ?, ?, ?, ?)");
   my $sql_insert_GA = $dbh->prepare("INSERT INTO GeographicalArea (GA_id) VALUES (?)");
   my $sql_insert_BKDS = $dbh->prepare(
      "INSERT INTO BK_Describes_DS (BK_id, DS_id) VALUES (?, ?)");
   my $sql_insert_NI = $dbh->prepare(
      "INSERT INTO NumberItem (SC_id, NI_from, NI_to, DS_id) VALUES (?, ?, ?, ?)");
#
   my $sql_getkey_MD = $dbh->prepare("SELECT nextval('Metadata_MD_id_seq')");
   my $sql_insert_MD = $dbh->prepare(
      "INSERT INTO Metadata (MD_id, MT_name, MD_content) VALUES (?, ?, ?)");
   my $sql_insert_DSMD = $dbh->prepare(
      "INSERT INTO DS_Has_MD (DS_id, MD_id) VALUES (?, ?)");
   my $sql_insert_GAGD = $dbh->prepare(
      "INSERT INTO GA_Contains_GD (GA_id, GD_id) VALUES (?, ?)");
   my $sql_insert_GADS = $dbh->prepare(
      "INSERT INTO GA_Describes_DS (GA_id, DS_id) VALUES (?, ?)");
#
# Loop through all datasets rooted in the hash reference $xmlref.
#
   my $datasetref;
   if (exists($xmlref->{'dataset'})) {
      $datasetref = $xmlref->{'dataset'};
   } else {
      $datasetref = [$xmlref];
   }
   foreach my $ref1 (@$datasetref) {
      my $drpath;
      my $period_from;
      my $period_to;
      my $quadtreenodes = "";
      my @metaarray = ();
      my @searcharray = ();
      if (exists($ref1->{'drpath'})) {
         $drpath = $ref1->{'drpath'}->[0];
      } else {
         die "Dataset with no drpath";
      }
      foreach my $name (keys %$ref1) {
         my $ref2 = $ref1->{$name};
         if ($name ne "ownertag" and ref($ref2) ne "ARRAY") {
            die '$ref2 is not a reference to ARRAY:' . " $ref2\n";
         }
         if ($name eq 'abstract') {
            my $mref = [$name,$ref2->[0]];
            push(@metaarray,$mref);
         } elsif ($name eq 'quadtree_nodes') {
            $quadtreenodes = $ref2->[0];
         } elsif ($name eq 'datacollection_period') {
            $period_from = $ref2->[0]->{'from'};
            $period_to = $ref2->[0]->{'to'};
         } elsif ($name eq 'datacollection_period_from') {
            $period_from = $ref2->[0];
            if ($period_from =~ /(\d\d\d\d-\d\d-\d\d)/) {
               $period_from = $1; # Remove HH:MM UTC originating from questionnaire data.
            } else {
               undef $period_from;
            }
         } elsif ($name eq 'datacollection_period_to') {
            $period_to = $ref2->[0];
            if ($period_to =~ /(\d\d\d\d-\d\d-\d\d)/) {
               $period_to = $1; # Remove HH:MM UTC originating from questionnaire data.
            } else {
               undef $period_to;
            }
         } elsif ($name eq 'topic') {
            foreach my $topic (@$ref2) {
               my $variable = $topic . ' > HIDDEN';
               my $mref = ['variable',$variable];
               push(@metaarray,$mref);
            }
         } elsif ($name eq 'area') {
            foreach my $str1 (@$ref2) {
               my $area = $str1;
               $area =~ s/^.*>\s*//; # Remove upper components of hierarchical name originating from
                                     # questionnaire data.
               my $mref = ['area',$area];
               push(@metaarray,$mref);
            }
         } elsif ($name ne 'ownertag') {
            foreach my $str1 (@$ref2) {
               my $mref = [$name,$str1];
               push(@metaarray,$mref);
            }
         }
      }
      if (defined($period_from) && defined($period_to)) {
         my $period = $period_from . ' to ' . $period_to;
         my $mref = ['datacollection_period',$period];
         push(@metaarray,$mref);
      }
      my $dsid;
      my $drid;
      if (exists($references{$drpath})) {
         my $ref3 = $references{$drpath};
         $dsid = $ref3->[0];
#
#  Delete existing dataset and corresponding GeographicalArea (if found).
#  This will cascade to BK_Describes_DS, GA_Describes_DS, GD_Ispartof_GA
#  and also DS_Has_MD:
#
         $sql_delete_GA->execute($dsid,$dsid);
         $sql_delete_DS->execute($dsid,$dsid);
      } else {
         $sql_getkey_DS->execute();
         my @result = $sql_getkey_DS->fetchrow_array;
         $dsid = $result[0];
      }
      $sql_insert_DS->execute($dsid,$drpath,0,1,$datestamp,$ownertag);
#
#  Insert metadata:
#  Metadata with metadata type name not in the database are ignored.
#
      foreach my $mref (@metaarray) {
         my $mtname = $mref->[0];
         my $mdcontent = &convert_to_htmlentities($mref->[1],\%html_conversions);
         my $mdid;
         if (exists($shared_metadatatypes{$mtname})) {
            my $mdkey = $mtname . ':' . $mdcontent;
            if ($progress_report >= 1) {
               print "mdkey: " . $mdkey . "\n";
            }
            if (exists($metadata{$mdkey})) {
               $mdid = $metadata{$mdkey};
            } else {
               $sql_getkey_MD->execute();
               my @result = $sql_getkey_MD->fetchrow_array;
               $mdid = $result[0];
               $sql_insert_MD->execute($mdid,$mtname,$mdcontent);
               $metadata{$mdkey} = $mdid;
            }
            $sql_insert_DSMD->execute($dsid,$mdid);
         } elsif (exists($rest_metadatatypes{$mtname})) {
            $sql_getkey_MD->execute();
            my @result = $sql_getkey_MD->fetchrow_array;
            $mdid = $result[0];
            $sql_insert_MD->execute($mdid,$mtname,$mdcontent);
            $sql_insert_DSMD->execute($dsid,$mdid);
         }
#
#  Insert searchdata:
#
         if (exists($searchcategories{$mtname})) {
            my $skey = $searchcategories{$mtname} . ':' . $mdcontent;
            if ($progress_report == 1) {
               print "Insert searchdata. Try: $skey\n";
            }
            if (exists($basickeys{$skey})) {
               my $bkid = $basickeys{$skey};
               $sql_insert_BKDS->execute($bkid,$dsid);
               if ($progress_report == 1) {
                  print " -OK: $bkid,$dsid\n";
               }
            } elsif ($mtname eq 'datacollection_period') {
               my $scid = $searchcategories{$mtname};
               if ($mdcontent =~ /(\d{4,4})-(\d{2,2})-(\d{2,2}) to (\d{4,4})-(\d{2,2})-(\d{2,2})/) {
                  my $from = $1 . $2 . $3;
                  my $to = $4 . $5 . $6;
                  $sql_insert_NI->execute($scid,$from,$to,$dsid);
               }
            }
         }
      }
#
#   Insert quadtree nodes:
#
      if (length($quadtreenodes) > 0) {
         $sql_getkey_GA->execute();
         my @result = $sql_getkey_GA->fetchrow_array;
         my $gaid = $result[0];
         $sql_insert_GA->execute($gaid);
         my @nodearr = split(/\s+/,$quadtreenodes);
         foreach my $node (@nodearr) {
            if (length($node) > 0) {
               $sql_insert_GAGD->execute($gaid,$node);
            }
         }
         $sql_insert_GADS->execute($gaid,$dsid);
      }
   }
}
sub my_time {
   my $realtime;
   if (scalar @_ == 0) {
      $realtime = time;
   } else {
      $realtime = $_[0];
   }
   my $scaling = [==TEST_IMPORT_SPEEDUP==];
   if ($scaling <= 1) {
      return $realtime;
   } else {
      my $basistime = [==TEST_IMPORT_BASETIME==];
      return $basistime + ($realtime - $basistime)*$scaling;
   }
};
sub convert_to_htmlentities {
   my ($str,$conversions) = @_;
   my @contarr = split(//,$str);
   my $result = "";
   foreach my $ch1 (@contarr) {
      if (exists($conversions->{$ch1})) {
         $result .= $conversions->{$ch1};
      } else {
         $result .= $ch1;
      }
   }
   return $result;
};
