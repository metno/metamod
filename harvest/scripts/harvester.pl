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
use LWP::UserAgent;
use lib qw([==TARGET_DIRECTORY==]/lib);
use quadtreeuse;
use Fcntl qw(LOCK_SH LOCK_UN LOCK_EX);
# use encoding 'utf8';
#
#  OAI-PMH Harvester
#  =================
#
#  Extracts DIF XMLs from OAI-PMH XMLs. The OAI-PMH XMLs are received from
#  several web addresses through GET requests. The list of web addresses to
#  use is configurable and stored in the %hash_harvest_sources hash. Each 
#  entry in this hash has a key equal to an ownertag used in the METAMOD2
#  database. The corresponding value is the URL used in the GET request. 
#
#  At regular time intervals (24 hours), all URLs in the hash is sent a GET
#  request asking for all records from the corresponding source that are
#  changed/new since the previous harvest on the same source. 
#
#  The received OAI-PMH XML have the following structure:
#
#  XML header:                 <?xml ...?>
#  Start of main element:      <OAI-PMH ...
#                              <request ... />
#                              <ListRecords>
#
#  Then, for each record:
#
#                                 <record>
#                                    <header>    OR    <header status="XXX">
#                                       <identifier>oai:YYY:ZZZ</identifier>
#                                       ...
#                                    </header>
#
#  If status="deleted" in the header element, the the <record> element is 
#  closed, and a new <record> element starts. Othervise, a <metadata> element 
#  follows, before the <record> is closed:
#
#                                    <metadata>
#                                       <DIF ...>
#                                          ...
#                                       </DIF>
#                                    </metadata>
#                                 </record>
#
my $continue_oai_harvest = '[==WEBRUN_DIRECTORY==]/CONTINUE_OAI_HARVEST';
my $xmldirectory = '[==WEBRUN_DIRECTORY==]/XML/[==APPLICATION_ID==]/';
my $applicationid = '[==APPLICATION_ID==]';
my $status_file = '[==WEBRUN_DIRECTORY==]/oai_harvest_status';
my $path_to_syserrors = '[==WEBRUN_DIRECTORY==]/syserrors';
my $progress_report = [==TEST_IMPORT_PROGRESS_REPORT==]; # If == 1, prints what's
                                                         # going on to STDOUT
my $xmd_dataset_header = '<?xml version="1.0" encoding="UTF-8" ?>' . "\n" .
                 '<dataset xmlns="http://www.met.no/metamod2/dataset/"' . "\n" .
                 '   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"' . "\n" .
                 '   xsi:schemaLocation="http://www.met.no/schema/metamod2/ matamodDataset.xsd">' . "\n";
my $xmd_dataset_footer = '</dataset>';
#
#  Set up the source URLs from which harvesting should be done, and also
#  the mapping between ownertags and source URLs:
#
my $harvest_sources = '[==OAI_HARVEST_SOURCES==]';
my @arr_harvest_sources = split(/\n/,$harvest_sources);
my %hash_harvest_sources = ();
foreach my $hsource (@arr_harvest_sources) {
   my ($ownertag,$url) = ($hsource =~ /\S+/g);
   $hash_harvest_sources{$ownertag} = $url;
}
#
# Create new user agent
#
my $useragent = LWP::UserAgent->new;
#
# Global variable to receive content from get requests:
#
my $content_from_get = ();
#
#  Evaluate block to catch runtime errors
#  (including "die()")
#
eval {
#   
#     Subroutine call: do_harvest
#   
   &do_harvest();
};
#
#  Check error string returned from eval
#  If not empty, an error has occured
#
if ($@) {
   warn $@;
}
#
#-----------------------------------------------------------------------
#
sub do_harvest {
   my $previous_day = -1;
   while (-e $continue_oai_harvest) {
      my @ltime = localtime(&my_time());
      my $newday = $ltime[3]; # 1-31
      my $current_hour = $ltime[2];
      if ($newday == $previous_day || $current_hour < [==HARVEST_HOUR==]) {
         if ([==TEST_IMPORT_SPEEDUP==] <= 1) {
            sleep(15*60);
         } else {
            sleep(1);
         }
         next;
      }
      $previous_day = $newday;
#      
#       foreach key,value pair in a hash
#      
      while (my ($ownertag,$url) = each(%hash_harvest_sources)) {
#
#       Open file for reading (with shared lock)
#
        if ($progress_report == 1) {
           print "harvesting $ownertag $url\n";
        }
        my $status_content = "";
        if (-r $status_file) {
           open (STATUS,$status_file);
           flock(STATUS, LOCK_SH);
           undef $/;
           $status_content = <STATUS>;
           $/ = "\n"; 
           close (STATUS); # Also unlocks
        }
        my $date_last_upd;
        if ($progress_report == 1) {
           print "Status content:\n\n";
           print $status_content . "\n";
        }
        my $j1 = index($status_content,$url);
        if ($j1 >= 0) {
           $j1 += length($url) + 1;
           $date_last_upd = substr($status_content,$j1,10);
        }
        my $urlsent = $url . '?verb=ListRecords&metadataPrefix=dif';
        if (defined($date_last_upd)) {
           $urlsent .= '&from=' . $date_last_upd;
        }
#         
#          Send GET request 
#          and receive response object in $getrequest:
#         
        if ($progress_report == 1) {
            print "Send GET request: $urlsent\n";
         }
         my $getrequest = $useragent->get($urlsent);
         if ($getrequest->is_success) {
            $content_from_get = $getrequest->content;
         } else {
            &syserror("","GET did not succeed: " . $getrequest->status_line);
            next;
         }
        if ($progress_report == 1) {
            print "GET request returned " . length($content_from_get) . " bytes\n";
         }
#
#        Process DIF records:
#
         &process_DIF_records($ownertag);
#
#        Update the status file:
#
         if (-e $status_file) {
            open (STATUS,"+<$status_file");
            flock (STATUS, LOCK_EX);
            undef $/;
            $status_content = <STATUS>;
            $/ = "\n"; 
         } else {
            open (STATUS,">$status_file");
            $status_content = "";
         }
         my $j2 = index($status_content,$url);
         if ($progress_report == 1) {
            print "j2 = $j2\n";
            print "length of url = " . length($url) . "\n";
         }
         my $new_status_content;
         if ($j2 >= 0) {
            $new_status_content = substr($status_content,0,$j2);
            $new_status_content .= substr($status_content,$j2+length($url)+12);
         } else {
            $new_status_content = $status_content;
         }
         {
            my @utctime = gmtime(&my_time());
            my $year = 1900 + $utctime[5];
            my $mon = $utctime[4]; # 0-11
            my $mday = $utctime[3]; # 1-31
            my $updated = sprintf('%04d-%02d-%02d',$year,$mon+1,$mday);
            $new_status_content .= $url . ' ' . $updated . "\n";
         }
         seek(STATUS,0,0);
         print STATUS $new_status_content;
         close (STATUS);
      }
      sleep(10);
   }
}
#
#-----------------------------------------------------------------------
#
sub process_DIF_records {
   my ($ownertag) = @_;
   if ($progress_report == 1) {
      print "--- Process DIF records:\n";
   }
   my $xml_header;
   if ($content_from_get =~ /^(<\?[^>]*\?>)/) {
      $xml_header = $1; # First matching ()-expression
   }
   else {
      &syserror("CONTENT","No XML header");
      return;
   }
   while (1) {
#   
#     Finished if no more header elements:
#   
      my $j1 = index($content_from_get,'<header');
      if ($j1 < 0) {
         if ($progress_report == 1) {
            print "finished DIF records\n";
         }
         last;
      }
#   
#     Extract header status:
#   
      $content_from_get = substr($content_from_get,$j1+7);
      my $status = "active";
      if ($content_from_get =~ /^\s*status="([^"]+)"/) {
         $status = $1; # First matching ()-expression
      }
#   
#     Extract identifier:
#   
      $j1 = index($content_from_get,'<identifier>');
      if ($j1 < 0) {
         &syserror("CONTENT","No identifier");
         return;
      }
      $content_from_get = substr($content_from_get,$j1+12);
      my $identifier;
      if ($content_from_get =~ /^([^<]+)/) {
         $identifier = &trim($1); # First matching ()-expression
      } else {
         &syserror("CONTENT","Empty identifier");
         return;
      }
      if ($progress_report == 1) {
         print "Identifier: $identifier\n";
      }
      my $base_filename;
      my $dsname;
#   
#     Construct dataset name and filename from identifier:
#   
      if ($identifier =~ /^[^:]*:([^:]+):(.*$)/) {
         my $namespaceid = $1; # First matching ()-expression
         my $localid = $2;
         my $localid_sane = &makesane($localid);
         $base_filename = $xmldirectory . $ownertag . '_' . $localid_sane;
         $dsname = $applicationid . '/' . $ownertag . '_' . $localid;
      }
      else {
         &syserror("","Wrong identifier format: ".$identifier);
         return;
      }
#
#     Update the two XML files with metadata for this dataset (.xmd and .xml):
#
      if ($status eq "deleted") {
#
#        Delete the .xml file and set status = "deleted" in the .xmd file:
#
         if ($progress_report == 1) {
            print "Write new $base_filename.xmd and delete $base_filename.xml\n";
         }
         open (XMD,">$base_filename.xmd");
         flock (XMD, LOCK_EX);
         print XMD $xmd_dataset_header;
         print XMD '   <info status="deleted" ownertag="'.$ownertag.'" name="'.$dsname.'" />'."\n";
         print XMD $xmd_dataset_footer;
         close (XMD);
         unlink($base_filename . '.xml');
      }
      else {
#      
#        Remove from beginning of $content_from_get until the first "<DIF ...>" tag:
#      
         $j1 = index($content_from_get,'<metadata>');
         if ($j1 < 0) {
            &syserror("CONTENT","No metadata element");
         }
         $content_from_get = substr($content_from_get,$j1+10);
         $j1 = index($content_from_get,'<');
         if ($j1 < 0) {
            &syserror("CONTENT","No DIF element");
         }
         $content_from_get = substr($content_from_get,$j1);
#      
#        Extract the tag name ("DIF" or "xxx:DIF"):
#      
         my $maintag;
         if ($content_from_get =~ /^<([a-zA-Z0-9_:-]+)/) {
            $maintag = $1; # First matching ()-expression
         }
         else {
            &syserror("CONTENT","No maintag");
         }
         if ($progress_report == 1) {
            print "maintag: $maintag\n";
         }
#      
#        Extract the whole DIF element:
#      
         $j1 = index($content_from_get,'</'.$maintag.'>');
         if ($j1 < 0) {
            &syserror("CONTENT","No closing $maintag tag");
         }
         my $xmlbody = substr($content_from_get,0,$j1 + length($maintag) + 3);
#      
#        Remove the DIF element from the content variable:
#      
         $content_from_get = substr($content_from_get,$j1 + length($maintag) + 3);
#
#        Read/write existsing .xmd-file (with exclusive lock):
#
         my $xmd_content;
         if ($progress_report == 1) {
            print "Open $base_filename.xmd for update\n";
         }
         if (-e $base_filename . '.xmd') {
            open (XMD,"+<$base_filename.xmd");
            flock (XMD, LOCK_EX);
            undef $/;
            $xmd_content = <XMD>;
            $/ = "\n"; 
         } else {
            open (XMD,">$base_filename.xmd");
            $xmd_content = "";
         }
         my $creationdate;
         if ($xmd_content =~ /creationDate="([^"]+)"/m) {
            $creationdate = $1; # First matching ()-expression
         } else {
            my @utctime = gmtime(&my_time());
            my $year = 1900 + $utctime[5];
            my $mon = $utctime[4]; # 0-11
            my $mday = $utctime[3]; # 1-31
            my $hour = $utctime[2]; # 0-23
            my $minute = $utctime[1]; # 0-59
            $creationdate = sprintf('%04d-%02d-%02dT%02d:%02dZ',$year,$mon,$mday,$hour,$minute);
         }
         print XMD $xmd_dataset_header;
         print XMD ' <info status="active"'."\n".'  ownertag="'.$ownertag.'"'."\n".
                   '  creationDate="'.$creationdate.'"'."\n".'  metadataFormat="DIF"'."\n".
                   '  name="'.$dsname.'" />'."\n";
#
#        Initialize Quadtreeuse object:
#
         my $QT_lat = 90.0;
         my $QT_lon = 0.0;
         my $QT_r = 3667387.2;
         my $QT_depth = 7;
         my $QT_proj = "+proj=stere +lat_0=90 +datum=WGS84";
         my $quadtreeuse_object = quadtreeuse->new($QT_lat,$QT_lon,$QT_r,$QT_depth,$QT_proj);
#      
#        Extract geographical bounding box:
#
         my %bounding_box = ();
         my $bounding_count = 0;
         foreach my $eltname ('Southernmost_Latitude', 'Northernmost_Latitude',
                              'Westernmost_Longitude', 'Easternmost_Longitude') {
            my $rex = '<' . $eltname . '>([^<]+)</' . $eltname . '>';
            if ($xmlbody =~ /$rex/m) {
               $bounding_box{$eltname} = $1;
               $bounding_count++;
            }
         }
         if ($bounding_count == 4) {
            my @latitudes = ($bounding_box{'Southernmost_Latitude'},
                          $bounding_box{'Southernmost_Latitude'},
                          $bounding_box{'Northernmost_Latitude'},
                          $bounding_box{'Northernmost_Latitude'},
                          $bounding_box{'Southernmost_Latitude'});
            my @longitudes = ($bounding_box{'Easternmost_Longitude'},
                           $bounding_box{'Westernmost_Longitude'},
                           $bounding_box{'Westernmost_Longitude'},
                           $bounding_box{'Easternmost_Longitude'},
                           $bounding_box{'Easternmost_Longitude'});
            $quadtreeuse_object->add_lonlats("area",\@longitudes,\@latitudes);
            print XMD " <quadtree>\n";
            foreach my $node ($quadtreeuse_object->get_nodes()) {
               print XMD "  $node\n";
            }
            print XMD " </quadtree>\n";
         }
         print XMD $xmd_dataset_footer;
         close (XMD);
#
#        Finished writing .xmd file
#
#        Write .xml file with content equal to the DIF element:
#
         if ($progress_report == 1) {
            print "Write $base_filename.xml\n";
         }
         {
#
#           The DIF XML may contain real UTF-8 characters. The following
#           "use encoding 'utf8';" statement seems to be a declaration that
#           the perl variables in this script have values already encoded in
#           UTF-8. Accordingly no extra encoding step is used when the variables
#           are written to a file. If this statement is not used, the output
#           files will be encoded in UTF-8 two times, creating nonsence.
#           Note that this statement must be at this lowest scoping level.
#           If used at higher levels, the statement will infuence the length
#           function (returning lengthes in UTF-8 characters and not bytes).
#
            use encoding 'utf8';
            open (DIF,">$base_filename.xml");
            flock (DIF, LOCK_EX);
            print DIF $xml_header . "\n" . $xmlbody;
            close (DIF);
         }
      }
   }
}
#
#-----------------------------------------------------------------------
#
sub makesane {
#   
#     Split argument array into variables
#   
   my ($string) = @_;
   my %convertions = ();
#   
#    foreach value in a list
#   
   foreach my $special ( ';','/','?',':','@','&','=','+','$',',','-','!','~','*','(',')','%') {
#      
#        Create a string using printf-compatible format:
#      
      $convertions{$special} = sprintf('%02x',ord($special));
   }
#   
#     Length of string
#   
   my $length = length($string);
   my $newstring = '';
   for (my $i1=0; $i1 < $length; $i1++) {
#      
#        Extract a substring from a string (first character has offset 0):
#      
      my $ch1 = substr($string,$i1,1);
      if (exists($convertions{$ch1})) {
         $newstring .= '-' . $convertions{$ch1};
      }
      else {
         $newstring .= $ch1;
      }
   }
   return $newstring;
}
#
#-----------------------------------------------------------------------
#
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
#
#-----------------------------------------------------------------------
#
sub trim {
   my ($string) = @_;
   $string =~ s/^\s*//m;
   $string =~ s/\s*$//m;
   return $string;
}
#
#---------------------------------------------------------------------------------
#
sub syserror {
   my ($type,$errmsg) = @_;
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
#
#     Write message to error log:
#
   open (OUT,">>$path_to_syserrors");
   flock (OUT, LOCK_EX);
   print OUT "-------- HARVESTER $datestring:\n" .
             "         $errmsg\n";
   if ($type eq "CONTENT") {
      print OUT "         The first 60 characters of \$content_from_get:\n";
      print OUT substr($content_from_get,0,60);
      print OUT "\n";
   }
};
