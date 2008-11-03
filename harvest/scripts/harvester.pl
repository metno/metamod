#!/usr/bin/perl -w
use strict;
use LWP::UserAgent;
use Fcntl qw(LOCK_SH LOCK_UN LOCK_EX);
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
#  If not empty, an error ha occured
#
if ($@) {
   warn $@;
}
#
#-----------------------------------------------------------------------
#
sub do_harvest {
   while (-e $continue_oai_harvest) {
#      
#       foreach key,value pair in a hash
#      
      while (my ($ownertag,$url) = each(%hash_harvest_sources)) {
#
#       Open file for reading (with shared lock)
#
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
        my $rex = $url . ' ([0-9-]+)';
        if ($status_content =~ /$rex/m) {
           $date_last_upd = $1; # First matching ()-expression
        }
        my $urlsent = $url . '?verb=ListRecords&metadataPrefix=dif';
        if (defined($date_last_upd)) {
           $urlsent .= '&from=' . $date_last_upd;
        }
#         
#          Send GET request 
#          and receive response object in $getrequest:
#         
         my $getrequest = $useragent->get($urlsent);
         my $content;
         if ($getrequest->is_success) {
            $content = $getrequest->content;
         } else {
            die "GET did not succeed: " . $getrequest->status_line . "\n";
         }
#         
#           Check if expression matches RE:
#         
         my $xml_header;
         if ($content =~ /^(<\?[^>]*\?>)/) {
            $xml_header = $1; # First matching ()-expression
         }
         else {
            die("No XML header");
         }
         while (1) {
#            
#              Check if expression matches RE:
#            
            if ($content !~ /^.*?<\w*:?header/) {
               last;
            }
#            
#              Substitute all occurences of a match:
#            
            $content =~ s/^.*?<\w*:?header *//mg;
#            
#              Check if expression matches RE:
#            
            my $status = "active";
            if ($content =~ /^status="([^"]+)"/) {
               $status = $1; # First matching ()-expression
            }
#            
#              Substitute all occurences of a match:
#            
            $content =~ s/^.*?<\w*:?identifier>//mg;
#            
#              Check if expression matches RE:
#            
            my $identifier;
            if ($content =~ /^([^<]+)/) {
               $identifier = $1; # First matching ()-expression
            }
            else {
               die("No identifier");
            }
            my $base_filename;
            my $dsname;
#            
#              Check if expression matches RE:
#            
            if ($identifier =~ /^[^:]*:([^:]+):(.*$)/) {
               my $namespaceid = $1; # First matching ()-expression
               my $localid = $2;
#               
#                 Function call: makesane
#               
               my $localid_sane = &makesane($localid);
               $base_filename = $xmldirectory . $ownertag . '_' . $localid_sane;
               $dsname = $applicationid . '/' . $ownertag . '_' . $localid;
            }
            else {
               die("Wrong identifier format");
            }
            if ($status eq "deleted") {
#
#              Open file for writing (with exclusive lock)
#
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
#                 Remove from beginning of $content until the first "<DIF ...>" tag:
#               
               $content =~ s/^.*?<\w*:?metadata>[^<]*</</mg;
#               
#                 Extract the tag name ("DIF" or "xxx:DIF"):
#               
               my $maintag;
               if ($content =~ /^<([a-zA-Z0-9_:-]+)/) {
                  $maintag = $1; # First matching ()-expression
               }
               else {
                  die("No maintag");
               }
#               
#                 Extract the whole DIF element:
#               
               my $xmlbody;
               my $rex = '^(<' . $maintag .'.*?<\/' . $maintag . '>)';
               if ($content =~ /$rex/) {
                  $xmlbody = $1; # First matching ()-expression
               }
               else {
                  die("No xmlbody");
               }
#               
#                 Extract geographical bounding box:
#
               my @bounding_box = ();
               foreach my $eltname ('Southernmost_Latitude', 'Northernmost_Latitude',
                                    'Westernmost_Longitude', 'Easternmost_Longitude') {
                  my $rex = '<' . $eltname . '>([^<]+)</' . $eltname . '>';
                  if ($xmlbody =~ /$rex/) {
                     push (@bounding_box,$1);
                  } else {
                     die("No $eltname");
                  }
               }
               my @utctime = gmtime;
#               
#                 Substitute all occurences of a match:
#               
               $content =~ s/$rex//mg;
            }
         }
      }
   }
   return <--EXPR1-->;
}
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
      $convertions{$special} = sprintf('%02x',$special);
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
