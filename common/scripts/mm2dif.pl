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
use XML::LibXML;
use XML::LibXSLT;
use DateTime;

use FindBin qw($Bin);
use lib "$FindBin::Bin/../lib";

my $parser = XML::LibXML->new();
my $xslt = XML::LibXSLT->new();

my $mm2file = shift or die "Missing input file name parameter";
my $source = $parser->parse_file($mm2file);
my $name = getname($mm2file) || $mm2file;

my $style_doc = $parser->parse_file("$Bin/../schema/mm2dif.xsl");
my $stylesheet = $xslt->parse_stylesheet($style_doc) or die "Cannot find mm2dif.xsl";
my $now = DateTime->today->ymd;
my $results = $stylesheet->transform($source, XML::LibXSLT::xpath_to_string(
    DS_name => $name,
    DS_creationdate => $now,
    DS_datestamp => $now
));

my $xc = XML::LibXML::XPathContext->new( $results->documentElement() );
$xc->registerNs('topic', "mailto:geira\@met.no?Subject=WTF");

# look for empty elements with default values
foreach ($xc->findnodes('//*[@topic:default]')) {
    $_->appendTextNode( $_->getAttribute('topic:default') ) unless $_->textContent;
    $_->removeAttribute('topic:default');
}

print $results->toString(1);


# END
#####

sub getname {
    # lookup dataset name from xmd file (if exists)
    my $mm2file = shift or die;
    my ($xmdfile) = "$1.xms" if $mm2file =~ /(.+)\.(\w+)$/;
    return unless -r $xmdfile;
    my $xmd = $parser->parse_file($xmdfile);
    return $xmd->findvalue('/*/*[local-name() = "info"]/@name');
}

