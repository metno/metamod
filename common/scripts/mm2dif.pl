#! /usr/bin/perl -w
# small helper-script to convert data input from stdin to DIF

=begin licence

----------------------------------------------------------------------------
METAMOD - Web portal for metadata search and upload

Copyright (C) 2008 met.no

Contact information:
Norwegian Meteorological Institute
Box 43 Blindern
0313 OSLO
NORWAY
email: Heiko.Klein@met.no

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
----------------------------------------------------------------------------

=end licence

=cut

use strict;
use warnings;
use FindBin qw($Bin);

use XML::LibXML;
use XML::LibXSLT;
use DateTime;

my $now = DateTime->today->ymd;

my $parser = XML::LibXML->new();
my $xslt = XML::LibXSLT->new();

my $gcmdterms = "$Bin/../../quest/htdocs/qst/config/gcmd-science-keywords.txt";
die "Cannot find gcmd-science-keywords.txt" unless -r $gcmdterms;

my $mm2Doc = shift or die "Missing input file name parameter";
my $source = $parser->parse_file($mm2Doc);

my $style_doc = $parser->parse_file("$Bin/../schema/mm2dif.xsl");
my $stylesheet = $xslt->parse_stylesheet($style_doc) or die "Cannot find mm2dif.xsl";
my $results = $stylesheet->transform($source, XML::LibXSLT::xpath_to_string(
    DS_name => $mm2Doc, # faking it for now
    DS_creationdate => $now,
    DS_datestamp => $now
));

# post-transform processing
my $xc = XML::LibXML::XPathContext->new( $results->documentElement() );
$xc->registerNs('dif', "http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/");
$xc->registerNs('topic', "mailto:geira\@met.no?Subject=WTF");

# split GCWF strings into topics, terms &c
foreach ($xc->findnodes('/*/dif:Parameters/dif:Detailed_Variable')) {
    my $dvar = $_->textContent;
    next unless $dvar =~ /^(.+) > HIDDEN$/;
    my $cfstring = $1;
    system('grep', '-xq', $cfstring, $gcmdterms) >= 0 or die "grep failed: $?";
    #printf STDERR " %s - $cfstring\n", $?;
    next unless $? == 0; # file contains CF string
    $_->removeChildNodes();
    $_->appendText($cfstring);
    my @gcwf = split(' > ', $dvar);
    #printf STDERR "%s - %s\n", ref $_, join('|', @gcwf);
    foreach my $node (qw(Topic Term Variable_Level_1)) {
        foreach ($_->parentNode->getChildrenByTagName("$node")) {
            $_->appendText(uc shift @gcwf);
        }
    }
}

# look for empty elements with default values
foreach ($xc->findnodes('//*[@topic:default]')) {
    $_->appendTextNode( $_->getAttribute('topic:default') ) unless $_->textContent;
    $_->removeAttribute('topic:default');
}

print $results->toString(1);
  
