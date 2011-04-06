#!/usr/bin/perl -w
use strict;
use XML::LibXSLT;
use File::Spec;

# small routine to get lib-directories relative to the installed file
sub getTargetDir {
    my ($finalDir) = @_;
    my ($vol, $dir, $file) = File::Spec->splitpath(__FILE__);
    $dir = $dir ? File::Spec->catdir($dir, "..") : File::Spec->updir();
    $dir = File::Spec->catdir($dir, $finalDir);
    return File::Spec->catpath($vol, $dir, "");
}

use lib ('../common/lib', getTargetDir('lib'));

use Metamod::WMS;

################
# init
#

my $setup_url = param('setup');
my $wmsurl = param('wmsurl');
#logger->debug(sprintf "\n setup = '%s'\n wmsurl = '%s'", $setup_url || '-', $wmsurl || '-');
$setup_url =~ s/\&wmssetup=.+$// if $setup_url; # hack
$wmsurl =~ s/\?.+$// if $wmsurl;                # another hack
# no idea why these hacks are necessary, but OpenLayers keep sending a junk query string

logger->debug(sprintf "\n setup = '%s'\n wmsurl = '%s'", $setup_url || '-', $wmsurl || '-');

# must use either one of params to work
abandon("Missing parameter 'setup' or 'wmsurl'", 400) unless $setup_url || $wmsurl;

#################################
# read setup document
#
my ($setup, $sxc) = getSetup($setup_url);
my $time = localtime();
my %bbox = ( time => $time );
foreach ( $sxc->findnodes('/*/s:displayArea/@*') ) {
    my ($k, $v) = ($_->localname, $_->getValue);
    $bbox{ $k } = $v; #( $v != 0 ) ? $v : "'$v'";
}
#print STDERR Dumper( \%bbox );


#################################
# transform Capabilities to WMC
#
my $xslt = XML::LibXSLT->new();
my $wmcns = "http://www.opengis.net/context";
my $getcap = $wmsurl || $setup->documentElement->getAttribute('url') or abandon("Missing setup or WMS url");
#printf STDERR "XML: %s\n", $getcap;
$getcap .= '?service=WMS&version=1.3.0&request=GetCapabilities';
my $stylesheet = $xslt->parse_stylesheet_file('gc2wmc.xsl');
my $results = $stylesheet->transform( getXML($getcap), XML::LibXSLT::xpath_to_string(%bbox) );
my $xc = XML::LibXML::XPathContext->new( $results->documentElement() );
$xc->registerNs('v', $wmcns);
my ($layerlist) = $xc->findnodes('/*/v:LayerList');


######################
# sort layers & styles
#
my $newlayers = $results->createElementNS($wmcns, 'LayerList');

# loop thru layers in setup file
foreach ( $sxc->findnodes('/*/s:layer') ) {
    my $lname = $_->getAttribute('name');
    my $style = $_->getAttribute('style') || '';
    # find matching layer nodes in Capabilities
    foreach my $layer ($xc->findnodes("v:Layer[v:Name = '$lname']", $layerlist)) {
        foreach ( $xc->findnodes("v:StyleList/v:Style[v:Name = '$style']", $layer) ) { # FIXME: wrong namespace
             $_->setAttribute('current', 1);
            # move preferred style node to top of list
            my $pn = $_->parentNode;
            $pn->insertBefore( $pn->removeChild($_), $pn->firstChild);
        }
        # move priority layer to new list
        $newlayers->appendChild( $layerlist->removeChild($layer) );
    }
}

# move rest of layers to new list
foreach ($xc->findnodes("v:Layer", $layerlist)) {
    $newlayers->appendChild( $layerlist->removeChild($_));
}

# replace old (empty) layer list with new sorted
$layerlist->addSibling($newlayers);
$layerlist->unbindNode;

#############
# output XML
#

my $out = $stylesheet->output_as_bytes($results);
# another hack to work around inexplainable namespace bug
$out =~ s|( xmlns:xlink="http://www.w3.org/1999/xlink"){2}|$1|g;
outputXML('application/xml', $out);

=end

=head1 TITLE

gc2wmc.pl - WMS GetCapabilities to Web Map Context converter/proxy

=head1 SYNOPSIS

 http://hostname/sch/gc2wmc?setup=<url>

where <url> is an encoded URL to the WMS data file (without query string)

=head1 DESCRIPTION

WMS GetCapabilities to Web Map Context converter/proxy. Run as CGI script.

=head1 AUTHOR

Copyright (C) 2009 met.no

  Norwegian Meteorological Institute
  Box 43 Blindern
  0313 OSLO
  NORWAY
  email: geir.aalberg@met.no

=head1 LICENSE

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

=cut
