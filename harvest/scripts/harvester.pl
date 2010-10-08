#!/usr/bin/perl -w

=begin LICENSE

Copyright (C) YYYY The Norwegian Meteorological Institute.  All Rights Reserved.

B<METAMOD> - Web portal for metadata search and upload

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

=end LICENSE

=cut

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

use lib ('../../common/lib', getTargetDir('lib'));

use POSIX;
use Getopt::Long;
use DBI;
use LWP::UserAgent;
use URI::Escape qw(uri_escape);
use Fcntl qw(LOCK_SH LOCK_UN LOCK_EX SEEK_SET);
use quadtreeuse;
use mmTtime;
use XML::LibXML;
use Metamod::Dataset;
use Metamod::ForeignDataset;
use Metamod::DatasetTransformer::DIF;
use Metamod::Utils qw();
use Metamod::Config qw(:init_logger);
my $config = Metamod::Config->new();
use Log::Log4perl qw( get_logger );
my $log = get_logger('metamod.harvester');
# use encoding 'utf8';

my $xmldirectory = $config->get('WEBRUN_DIRECTORY').'/XML/'.$config->get('APPLICATION_ID').'/';
my $applicationid = $config->get('APPLICATION_ID');
my $status_file = $config->get('WEBRUN_DIRECTORY').'/oai_harvest_status';

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

# Parse cmd line params
#
my ($pid, $errlog, $ownertag);
GetOptions ('pid|p=s' => \$pid,     # name of pid file - if given, run as daemon
            'log|l=s' => \$errlog,  # optional, redirect STDERR and STDOUT here
            'owner=s' => \$ownertag, # archive files under this owner
);

#
if ($pid) {
    eval { Metamod::Utils::daemonize($errlog, $pid); };
    $log->fatal($@) if $@;
} elsif (@ARGV) {
    # run for input file/url rather than source-harvesting
    foreach (@ARGV) {
        $log->info("Fetching document '$_'...");
        my $token;
        eval {
            $token = process_DIF_records($ownertag,
                /^http:/ ? getContentFromUrl($_) : getContentFromFile($_)
            );
        };
        if ($@) {
            $log->error($@);
            printf STDERR $@;
            exit(1);
        }
        if ($token) {
            print STDERR "resumptionTag found, please provide file with resumptionToken=". uri_escape($token);
        }
    }
    exit(0);
} else {
    usage();
}


# please explain why we're counting TERM signals
our $SIG_TERM = 0;
sub sigterm {++$SIG_TERM;}
$SIG{TERM} = \&sigterm;

my @arr_harvest_sources = split(/\n/,$harvest_sources);
my %hash_harvest_sources = ();
my %hash_set_specifications = ();
foreach my $hsource (@arr_harvest_sources) {
    next if $hsource =~ /^\s*$/; # possible empty line
    my ($ownertag,$url,$setspec) = ($hsource =~ /\S+/g);
    $hash_harvest_sources{$ownertag} = $url;
    $hash_set_specifications{$ownertag} = $setspec;
}

eval {
    &do_harvest();
};
if ($@) {
    $log->error($@);
}


#-----------------------------------------------------------------------
#
sub do_harvest {
    my $previous_day = -1;
    while (! $SIG_TERM ) {
        my @ltime = localtime(mmTtime::ttime());
        my $newday = $ltime[3]; # 1-31
        my $current_hour = $ltime[2];
        if ($newday == $previous_day || $current_hour < $config->get('HARVEST_HOUR')) {
            my $acc = $config->get('TEST_IMPORT_SPEEDUP');
            if (defined($acc) && $acc > 1) {
                sleep(1);
            } else {
                sleep(15*60);
            }
            next;
        }
        $previous_day = $newday;

        my $dbh = $config->getDBH();

        # foreach key,value pair in a hash
        while (my ($ownertag,$url) = each(%hash_harvest_sources)) {

            # Open file for reading (with shared lock)
            $log->debug("harvesting $ownertag $url");

            my $date_last_upd = getlaststatus($dbh, $applicationid, $url);

            my $urlsent = $url . '?verb=ListRecords&metadataPrefix=dif';
            if (defined($date_last_upd)) {
                $urlsent .= '&from=' . substr( $date_last_upd, 0, 10 ); # use only date from timestamp
            }
            if (exists($hash_set_specifications{$ownertag}) &&
                 defined($hash_set_specifications{$ownertag})) {
                $urlsent .= '&set=' . $hash_set_specifications{$ownertag};
            }
            my $content_from_get = eval { getContentFromUrl($urlsent); };
            #next unless $content_from_get;
            if ($@) {
                $log->error("GET error: $@ for GET $urlsent");
                next; # probably network or server error, let's wait and see
            }

            # Process DIF records:
            eval {
                my $resumptionToken = process_DIF_records($ownertag, $content_from_get);
                while ($resumptionToken) {
                    # continue reading records
                    my $resumptionUrl = $url . '?verb=ListRecord&resumptionToken='. uri_escape($resumptionToken);
                    my $content_from_get = getContentFromUrl($resumptionUrl);
                    last unless $content_from_get;
                    $resumptionToken = process_DIF_records($ownertag, $content_from_get);
                }
            };

            if ($@) { # OAI-PMH reports an error
                $log->error("DIF processing error: $@");
            } else { # all ok, update status in db to current timestamp
                eval { updatestatus($dbh, $applicationid, $url, $date_last_upd); };
                $log->error("Could not update status in DB: $@") if ($@);
            }

        }
        $dbh->disconnect;
        sleep(10);
    }
}

#
#-----------------------------------------------------------------------
# read/update status timestamps in db

sub getlaststatus {
    # return timestamp of last update or undef if not found
    my ($dbh, $app, $source) = @_;

    my $stm = $dbh->prepare("SELECT HS_time FROM HarvestStatus WHERE HS_application = ? AND HS_url = ?" );
    $stm->execute($app, $source) or die($dbh->errstr);
    my ($lastharvest) = $stm->fetchrow_array;
    $log->debug("Last update for $app: $source was " . ($lastharvest || 'never'));
    return $lastharvest;
}

sub updatestatus {
   my ($dbh, $app, $source, $exists) = @_;

   $log->debug("Logging status for $app: $source to database");
   my $stm = $dbh->prepare(
      $exists
      ? "UPDATE HarvestStatus SET HS_time = now() WHERE HS_application = ? AND HS_url = ?"
      : "INSERT INTO HarvestStatus (HS_application, HS_url, HS_time) VALUES ( ?, ?, now() )"
   );
   $stm->execute($app, $source) or die($dbh->errstr);
   $dbh->commit or die($dbh->errstr);
}

#
#-----------------------------------------------------------------------
#
sub process_DIF_records {
    # parse DIF XML and extract records
    # returns a string if ResumptionToken, undef if none, dies on error
    my ($ownertag, $content_from_get) = @_;
    $log->debug("--- Process DIF records:");
    my $parser = new XML::LibXML();
    my $oaiDoc;
    eval {
        $oaiDoc = $parser->parse_string($content_from_get);
        $log->debug("Successfully parsed XML\n");
        if ($harvest_schema) {
            # $log->debug("validating ...");
            $harvest_schema->validate($oaiDoc);
            $log->debug("Successfully validated XML");
        }
    };

    die "XML parser error: $@" if $@;

    #if ($@) {
    #    $log->error("XML parser error: $@\n");
    #    #$log->debug( "Error with content: $@" . substr($content_from_get, 0, 250) );
    #    return;
    #}

    my $xpath = XML::LibXML::XPathContext->new();
    $xpath->registerNs('oai', 'http://www.openarchives.org/OAI/2.0/');

    if ( my ($error) = $xpath->findnodes("/*/oai:error", $oaiDoc) ) {
        my $code = $error->getAttribute('code');
        if ($code eq 'noRecordsMatch') { # no new records, which is normal
            $log->debug($error->textContent);
            return;
        }
        die "Harvest source error: " . $error->textContent;
    }

    my @records = $xpath->findnodes("/oai:OAI-PMH/oai:ListRecords/oai:record", $oaiDoc);
    $log->debug("Found ", scalar @records, " DIF records\n");
    my $i;
    foreach my $record (@records) {
        $i++;
        my $identifier = eval { trim($xpath->findnodes("oai:header/oai:identifier", $record)->item(0)->textContent); };
        if ($@ or (!$identifier)) {
            $log->error("No identifier in record $i: $@\n" . $record->toString);
            return;
        }
        $log->debug("Identifier: $identifier");
        my $datestamp;
        eval { $datestamp = $xpath->findnodes("oai:header/oai:datestamp", $record)->item(0)->textContent };
        if ($@) {
            $log->error("No datestamp: $@\n" . $record->toString);
            return;
        }
        #optional status
        my @statusNodes = $xpath->findnodes('oai:header/@status', $record);
        my $status = "active";
        if (@statusNodes > 0) {
            $status  = $statusNodes[0]->getValue;
        }

        #
        # Construct dataset name and filename from identifier:
        #
        my $base_filename;
        my $dsname;
        if ($identifier =~ /^[^:]*:([^:]+):(.*$)/) {
            my $namespaceid = $1; # First matching ()-expression
            my $localid = $2;
            my $localid_sane = &makesane($localid);
            $base_filename = $xmldirectory . $ownertag . '_' . $localid_sane;
            $dsname = $applicationid . '/' . $ownertag . '_' . $localid_sane;
        } else {
            $log->error("Wrong identifier format: $identifier\n" . $record->toString);
            return;
        }

        #
        # parse metadata
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
                $log->error("CONTENT: No DIF element in record $i: $@ " . $record->toString);
                return;
            }
        }
        # set DIF-external elements
        eval {
          $fds->setInfo({status => $status, ownertag => $ownertag, name => $dsname, datestamp => $datestamp});
        }; if ($@) {
            $log->error("CONTENT: problems setting info in record $i: $@ " . $record->toString);
            return;
        }
        $log->info("Writing $base_filename.xm[ld]");
        $fds->writeToFile($base_filename);
    }

    # check for resumptionToken
    my $resumptionToken;
    foreach my $resumptionNode ($xpath->findnodes("//oai:resumptionToken", $oaiDoc)) {
         # should be max one
         $resumptionToken = $resumptionNode->textContent;
         $log->debug("found resumptionNode with token: $resumptionToken");
    }
    return $resumptionToken;
}

#
#-----------------------------------------------------------------------
# eat a local file
#
sub getContentFromFile {
    my ($file) = @ARGV;
    open my $f, $file or die "Cannot read $file: $!\n";
    local $/ = undef;
    my $content = <$f>;
    close $f;
    return $content;
}

#
#-----------------------------------------------------------------------
# get the decoded content from an url
#
sub getContentFromUrl {
    my $urlsent = shift or die "Missing URL in getContentFromUrl()";
    # Send GET request
    # and receive response object in $getrequest:
    $log->info("Send GET request: $urlsent");
    my $useragent = LWP::UserAgent->new;
    $useragent->timeout(60*15);
    my $getrequest = $useragent->get($urlsent);
    my $content_from_get;
    if ($getrequest->is_success) {
        $content_from_get = $getrequest->decoded_content || '';
    } else {
        my $stat = $getrequest->status_line || '';
        $log->error("GET did not succeed: " . $stat . $content_from_get);
        die $stat;
    }
    $log->debug("GET request returned " . length($content_from_get) . " bytes");
    return $content_from_get;
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


sub trim {
    my ($string) = @_;
    $string =~ s/^\s*//m;
    $string =~ s/\s*$//m;
    return $string;
}

sub usage {
    print STDERR <<EOT;
command line usage: harvester.pl [--owner OWNERTAG] [--log LOGFILE] FILE|URL
daemon usage:       harvester.pl --pid PIDFILE [--log LOGFILE]
EOT
    exit(1);
}



=head1 NAME

B<OAI-PMH Harvester> - Downloads OAI-PMH XMLs and extracts DIF XMLs

=head1 VERSION

[% VERSION %], last modified $Date: 2008-10-06 11:28:08 $

=head1 DESCRIPTION

The OAI-PMH XMLs are received from several web addresses through GET requests.
The list of web addresses to use is configurable and stored in the
%hash_harvest_sources hash. Each entry in this hash has a key equal to an
ownertag used in the METAMOD2 database. The corresponding value is the URL used
in the GET request.

At regular time intervals (24 hours), all URLs in the hash is sent a GET
request asking for all records from the corresponding source that are
changed/new since the previous harvest on the same source.

The received OAI-PMH XML have the following structure:

XML header:                       <?xml ...?>
Start of main element:            <OAI-PMH ...
                                    <request ... />
                                    <ListRecords>

Then, for each record:

                                        <record>
                                            <header>    OR    <header status="XXX">
                                                <identifier>oai:YYY:ZZZ</identifier>
                                                ...
                                            </header>

If status="deleted" in the header element, the the <record> element is
closed, and a new <record> element starts. Othervise, a <metadata> element
follows, before the <record> is closed:

                                            <metadata>
                                                <DIF ...>
                                                    ...
                                                </DIF>
                                            </metadata>
                                        </record>

=head1 LICENSE

Copyright (C) 2008 The Norwegian Meteorological Institute.  All Rights Reserved.

=cut
