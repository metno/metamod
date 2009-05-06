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
use Fcntl qw(LOCK_SH LOCK_UN LOCK_EX);
use lib qw([==TARGET_DIRECTORY==]/lib);
use quadtreeuse;
use mmTtime;
use XML::LibXML;
use Metamod::Dataset;
use Metamod::ForeignDataset;
use Metamod::DatasetTransformer::DIF;
use Metamod::Config;
my $config = Metamod::Config->new();
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
my $continue_oai_harvest = $config->get('WEBRUN_DIRECTORY').'/CONTINUE_OAI_HARVEST';
my $xmldirectory = $config->get('WEBRUN_DIRECTORY').'/XML/'.$config->get('APPLICATION_ID').'/';
my $applicationid = $config->get('APPLICATION_ID');
my $status_file = $config->get('WEBRUN_DIRECTORY').'/oai_harvest_status';
my $path_to_syserrors = $config->get('WEBRUN_DIRECTORY').'syserrors';
my $progress_report = $config->get('TEST_IMPORT_PROGRESS_REPORT'); # If == 1, prints what's
                                                         # going on to STDOUT
if ($progress_report == 1) {
#
#  Make sure test output is flushed:
#
   my $old_fh = select(STDOUT);
   $| = 1;
   select($old_fh);
}
#
#  Set up the source URLs from which harvesting should be done, and also
#  the mapping between ownertags and source URLs:
#
my $harvest_sources = $config->get('OAI_HARVEST_SOURCES');
my $harvest_schema;
{
   my $harvest_validation_schema = $config->get('OAI_HARVEST_VALIDATION_SCHEMA');
   $harvest_schema = XML::LibXML::Schema->new( location => $harvest_validation_schema )
      if $harvest_validation_schema;
}

if (@ARGV == 2) {
   # run for input file rather than source-harvesting
   my ($ownertag, $file) = @ARGV;
   open my $f, $file or die "Cannot read $file: $!\n";
   local $/ = undef;
   my $content_from_get = <$f>;
   close $f;
   process_DIF_records($ownertag, $content_from_get);
   exit(0); # do not continue
} elsif (@ARGV > 0) {
   print STDERR "usage: harvester.pl\ntest-usage: harvester.pl OWNERTAG FILE\n";
   exit(1);
}


my @arr_harvest_sources = split(/\n/,$harvest_sources);
my %hash_harvest_sources = ();
my %hash_set_specifications = ();
foreach my $hsource (@arr_harvest_sources) {
   next if $hsource =~ /^\s*$/; # possible empty line
   my ($ownertag,$url,$setspec) = ($hsource =~ /\S+/g);
   $hash_harvest_sources{$ownertag} = $url;
   $hash_set_specifications{$ownertag} = $setspec;
}
#
# Create new user agent
#
my $useragent = LWP::UserAgent->new;
$useragent->timeout(60*15);
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
      my @ltime = localtime(mmTtime::ttime());
      my $newday = $ltime[3]; # 1-31
      my $current_hour = $ltime[2];
      if ($newday == $previous_day || $current_hour < $config->get('HARVEST_HOUR')) {
         if ($config->get('TEST_IMPORT_SPEEDUP') <= 1) {
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
         if (exists($hash_set_specifications{$ownertag}) && 
             defined($hash_set_specifications{$ownertag})) {
            $urlsent .= '&set=' . $hash_set_specifications{$ownertag};
         }
#         
#          Send GET request 
#          and receive response object in $getrequest:
#         
         if ($progress_report == 1) {
            print "Send GET request: $urlsent\n";
         }
         my $getrequest = $useragent->get($urlsent);
         my $content_from_get;
         if ($getrequest->is_success) {
            $content_from_get = $getrequest->decoded_content;
         } else {
            &syserror("","GET did not succeed: " . $getrequest->status_line, $content_from_get);
            next;
         }
         if ($progress_report == 1) {
            print "GET request returned " . length($content_from_get) . " bytes\n";
         }
#
#        Process DIF records:
#
         &process_DIF_records($ownertag, $content_from_get);
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
            my @utctime = gmtime(mmTtime::ttime());
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
   my ($ownertag, $content_from_get) = @_;
   if ($progress_report == 1) {
      print "--- Process DIF records:\n";
   }
   my $parser = new XML::LibXML();
   my $oaiDoc;
   eval {
      $oaiDoc = $parser->parse_string($content_from_get);
      print "successfully parsed content\n" if ($progress_report == 1);
      if ($harvest_schema) {
         print "validating ..." if ($progress_report == 1);
         $harvest_schema->validate($oaiDoc);
         print "successfully validated content\n" if ($progress_report == 1);
      }
   }; if ($@) {
      print STDERR "error in parsing: $@\n";
      &syserror("CONTENT", "error with content: $@", $content_from_get);
      return;
   }
   my $xpath = XML::LibXML::XPathContext->new();
   $xpath->registerNs('oai', 'http://www.openarchives.org/OAI/2.0/');
   
   my @records = $xpath->findnodes("/oai:OAI-PMH/oai:ListRecords/oai:record", $oaiDoc);
   print "found ", scalar @records, " records\n" if $progress_report;
   my $i;
   foreach my $record (@records) {
      $i++;
      my $identifier = eval { trim($xpath->findnodes("oai:header/oai:identifier", $record)->item(0)->textContent); };
      if ($@ or (!$identifier)) {
         &syserror("CONTENT","No identifier in record $i: $@", $record->toString);
         return;
      }
      print "Identifier: $identifier\n" if $progress_report;
      my $datestamp;
      eval { $datestamp = $xpath->findnodes("oai:header/oai:datestamp", $record)->item(0)->textContent };
      if ($@) {
         &syserror("CONTENT","No datestamp: $@", $record->toString);
         return;
      }
      #optional status
      my @statusNodes = $xpath->findnodes('oai:header/@status', $record);
      my $status = "active";
      if (@statusNodes > 0) {
         $status  = $statusNodes[0]->getValue;
      }
      
#   
#     Construct dataset name and filename from identifier:
#   
      my $base_filename;
      my $dsname;
      if ($identifier =~ /^[^:]*:([^:]+):(.*$)/) {
         my $namespaceid = $1; # First matching ()-expression
         my $localid = $2;
         my $localid_sane = &makesane($localid);
         $base_filename = $xmldirectory . $ownertag . '_' . $localid_sane;
         $dsname = $applicationid . '/' . $ownertag . '_' . $localid;
      } else {
         &syserror("","Wrong identifier format: ".$identifier, $record->toString);
         return;
      }

#
#     parse metadata
#
      my $fds; # Metamod::ForeignDataset
      if ($status eq "deleted") {
         my $nullDoc = new XML::LibXML::Document($oaiDoc->version, $oaiDoc->encoding);
         $fds = Metamod::Dataset->new();
      } else {
         eval {
            # get the dif-node, this is the first (and only) element-node of metadata
            my @difNodes = map {$_->nodeType == XML_ELEMENT_NODE ? $_ : ();} 
               $xpath->findnodes("oai:metadata", $record)->item(0)->childNodes;
            my $difDoc = new XML::LibXML::Document($oaiDoc->version, $oaiDoc->encoding);
            $difDoc->setDocumentElement($difNodes[0]);
            my $datasetTransformer = new Metamod::DatasetTransformer::DIF("", $difDoc->toString);
            my ($dsDoc, $mmDoc) = $datasetTransformer->transform;
            # only storing the dataset information from the transformed document
            # storing metadata in original dif format
            $fds = Metamod::ForeignDataset->newFromDoc($difDoc, $dsDoc);
         }; if ($@) {
            &syserror("CONTENT","No DIF element in record $i: $@", $record->toString);
            return;
         }
      }
      # set DIF-external elements
      $fds->setInfo({status => $status, ownertag => $ownertag, name => $dsname, datestamp => $datestamp});
      print "Write $base_filename.xm[ld]\n" if ($progress_report == 1);
      $fds->writeToFile($base_filename);
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
# sub my_time {
#   my $realtime;
#   if (scalar @_ == 0) {
#      $realtime = time;
#   } else {
#      $realtime = $_[0];
#   }
#   my $scaling = $config->get('TEST_IMPORT_SPEEDUP');
#   if ($scaling <= 1) {
#      return $realtime;
#   } else {
#      my $basistime = $config->get('TEST_IMPORT_BASETIME');
#      return $basistime + ($realtime - $basistime)*$scaling;
#   }
# };
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
   my ($type,$errmsg, $content_from_get) = @_;
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
   if ($type eq "CONTENT" && defined $content_from_get) {
      print OUT "         The first 200 characters of \$content_from_get:\n";
      print OUT substr($content_from_get,0,200);
      print OUT "\n";
   }
};
