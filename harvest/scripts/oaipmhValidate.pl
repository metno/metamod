#!/usr/bin/perl -w
#
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
#  email: heiko.klein@met.no 
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
use LWP::UserAgent;
use XML::LibXML;
use XML::LibXML::XPathContext;
use File::Spec;
use Getopt::Std;

# default values
our $harvestSource = 'http://dokipy.met.no/r1/pmh/oai2.php?verb=ListRecords&metadataPrefix=dif';
#our $difSchemaURI = getTargetDir('../common/schema/extended_dif_v9.7.1.xsd');
our $difSchemaURI = getTargetDir('../common/schema/ipy_dif_v9.7.1.xsd');
our $oaiSchemaURI = getTargetDir('../common/schema/OAI-PMH.xsd');
our $oaiNS = 'http://www.openarchives.org/OAI/2.0/';
our $debug = 0;

sub printUsage {
	my ($msg, $error) = @_;
	my $prg = $0;
	$prg =~ s:.*/::;
	print <<EOT;
usage: $prg -i inputURL [-m metadataSchema] [-o oaiPmhSchema] [-h] [-d]
 default: metadataSchema: $difSchemaURI
          oaiPmhSchema:   $oaiSchemaURI
          
 -d debug
 -h this help
 
example: $prg -i '$harvestSource'

EOT
	print $msg, "\n" if $msg;
	exit($error);
}

our %opts;
getopts('hdi:m:o:', \%opts) or printUsage("Error parsing command-line", 2);
if ($opts{h}) {printUsage();}
$debug++ if $opts{d};
if ($opts{i}) {
	$harvestSource = $opts{i};
} else {
	printUsage("-i 'inputURL' missing, e.g. $harvestSource", 2);
}
$difSchemaURI = $opts{m} if $opts{m};
$oaiSchemaURI = $opts{o} if $opts{o};

my $oaiSchema = XML::LibXML::Schema->new( location => $oaiSchemaURI );
my $difSchema = XML::LibXML::Schema->new( location => $difSchemaURI );


my $errors = 0;
my $parser = XML::LibXML->new();
my $doc = $parser->parse_string(fetchSource($harvestSource), $harvestSource);
print STDERR "well-formed xml in $harvestSource\n";

$oaiSchema->validate($doc);
print STDERR "valid oai-pmh document in $harvestSource\n" if $debug;

my $xpath = XML::LibXML::XPathContext->new();
$xpath->registerNs('oai', $oaiNS);

my $records = $xpath->findnodes("/oai:OAI-PMH/oai:ListRecords/oai:record", $doc);
my $recordNo = $records->size;
while (defined (my $record = $records->shift)) {
	my $identifier = eval { $xpath->findnodes("oai:header/oai:identifier", $record)->item(0)->textContent; };
    print STDERR "working on record $identifier\n" if $debug;
          #optional status
    my @statusNodes = $xpath->findnodes('oai:header/@status', $record);
    my $status = "active";
    if (@statusNodes > 0) {
        $status  = $statusNodes[0]->getValue;
    }
    if ($status ne "active") {
    	print STDERR "$identifier has status $status, not analyzing\n" if $debug;
    	$recordNo--;
    } else {
        my @difNodes = map {$_->nodeType == XML_ELEMENT_NODE ? $_ : ();} 
            $xpath->findnodes("oai:metadata", $record)->item(0)->childNodes;
        if (@difNodes != 1) {
        	print STDERR "found ".scalar @difNodes. " for $identifier in $harvestSource, should be exactly 1 active\n";
        	$errors++;
        }
        my $difDoc = new XML::LibXML::Document($doc->version, $doc->encoding);
        $difDoc->setDocumentElement($difNodes[0]);
        eval {$difSchema->validate($difDoc)};
        if ($@) {
        	$errors++;
        	print STDERR "validation-error in $identifier from $harvestSource: $@\n";
        } else {
        	print STDERR "$identifier validates\n" if $debug;
        }
    }
}
if ($errors) {
	die "found $errors validation errors in $recordNo records\n";
} else {
    print STDERR "sucessfully finished without errors, testing $recordNo records" if $debug;
    exit(0);
}

# small routine to get lib-directories relative to the installed file
sub getTargetDir {
    my ($finalDir) = @_;
    my ($vol, $dir, $file) = File::Spec->splitpath(__FILE__);
    $dir = $dir ? File::Spec->catdir($dir, "..") : File::Spec->updir();
    $dir = File::Spec->catdir($dir, $finalDir); 
    return File::Spec->catpath($vol, $dir, "");
}

sub fetchSource {
    my ($source) = @_;
    my $ua = new LWP::UserAgent;
    my $response = $ua->get($source);
    my $content;
    if ($response->is_success) {
        $content = $response->decoded_content;
        print STDERR "content successfully read from $source\n" if $debug;
    } else {
        die "cannot read $source: ".$response->status_line;
    }
    return $content;
}

