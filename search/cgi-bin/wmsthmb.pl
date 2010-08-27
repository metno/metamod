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
my $xslt = XML::LibXSLT->new();
my $setup_url = param('wmssetup') or abandon("Missing parameter 'wmssetup' containg file URL", 400);
my $size = param('size') || 96;

logger->debug(sprintf "\n setup = '%s'", $setup_url || '-');

# read setup document etc.
my ($setup, $sxc) = getSetup($setup_url);
my $wms_url = $sxc->findvalue('/*/@url');

# find area info (dimensions, projection)
my (%area, %layer);
foreach ( $sxc->findnodes('/*/s:displayArea[1]/@*') ) {
    $area{$_->nodeName} = $_->getValue;
}
# find metadata of first layer (name, style)
foreach ( $sxc->findnodes('/*/s:layer[1]/@*') ) {
    $layer{$_->nodeName} = $_->getValue;
}

# build WMS params for maps
my $wmsparams = "SERVICE=WMS&REQUEST=GetMap&VERSION=1.1.1&FORMAT=image%2Fpng"
    . "&SRS=$area{crs}&BBOX=$area{left},$area{bottom},$area{right},$area{top}&WIDTH=$size&HEIGHT=$size"
    . "&EXCEPTIONS=application%2Fvnd.ogc.se_inimage";

# these map url's should really be configured somewhere else
my $coast_url = "http://wms.met.no/maps/world.map?";
if ($area{crs} eq "EPSG:32661") {
    $coast_url = "http://wms.met.no/maps/northpole.map?";
} elsif ($area{crs} eq "EPSG:32761") {
    $coast_url = "http://wms.met.no/maps/southpole.map?";
}

#print STDERR Dumper($wms_url, \%area, \%layer);

#############
# output HTML
#
my $body = <<EOT;
<html>
    <head>
        <style type="text/css">
            body { margin:0; padding:0; }
        </style>
    </head>
    <body>
        <div style="position: absolute; z-index:100"><img src="$wms_url?$wmsparams&LAYERS=$layer{name}&STYLES=$layer{style}"/></div>
        <div style="position: absolute; z-index:5000"><img src="$coast_url?$wmsparams&TRANSPARENT=true&LAYERS=borders&STYLES="/></div>
    </body>
</html>
EOT

outputXML('text/html', $body);

=end

=head1 TITLE

wmsthmb.pl

=head1 SYNOPSIS

 http://hostname/sch/gc2wmc?wmssetup=<url>

where <url> is an encoded URL to the WMS data file (without query string)

=head1 PARAMETERS

  wmssetup= link to setup file
  size= thumbnail size in pixels (square) [optional]

=head1 DESCRIPTION

Generate HTML for WMS thumbnail iframes

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
