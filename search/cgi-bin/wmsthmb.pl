#!/usr/bin/perl -w
use strict;
use LWP::UserAgent;
use XML::LibXSLT;
use XML::LibXML;
use CGI;
use Data::Dumper;


################
# init
#
our $parser = XML::LibXML->new();
my $xslt = XML::LibXSLT->new();

my $q = CGI->new;
my $setup_url = $q->param('wmssetup') or giveup( "Missing parameter 'wmssetup' containg file URL", 400);
my $size = $q->param('size') || 96;

#printf STDERR "*** setup = '%s'\n*** url = '%s'\n", $setup_url || '-', $q->param('url') || '-';

####################
# report error
#
sub giveup {
    my $text = shift || 'Something went wrong';
    my $status = shift || 500;
    print $q->header('text/html', $status);
    print <<EOT;
<html>
<head>
    <title>Thumbnail generator error</title>
</head>
<body>
    <h1>Thumbnail generator error</h1>
    <p>$text</p>
</body>
</html>
EOT
    exit;
}


####################
# webservice client
#
sub getXML {
    my $url = shift or die "Missing URL";
    #printf STDERR "GET %s\n", $url;
    my $ua = LWP::UserAgent->new;
    $ua->timeout(100);
    #$ua->env_proxy;

    my $response = $ua->get($url);

    if ($response->is_success) {
        #print STDERR $response->content;
        return $parser->parse_string($response->content);
    }
    else {
        giveup($response->status_line . ': ' . $url, 502);
    }
}


#################################
# read setup document
#
my $setup = getXML($setup_url);
my $sxc = XML::LibXML::XPathContext->new( $setup->documentElement() );
$sxc->registerNs('s', "http://www.met.no/schema/metamod/ncWmsSetup");

my $wms_url = $sxc->findvalue('/*/@url');

my (%area, %layer);
foreach ( $sxc->findnodes('/*/s:displayArea[1]/@*') ) {
    $area{$_->nodeName} = $_->getValue;
}
foreach ( $sxc->findnodes('/*/s:layer[1]/@*') ) {
    $layer{$_->nodeName} = $_->getValue;
}

my $wmsparams = "SERVICE=WMS&REQUEST=GetMap&VERSION=1.1.1&FORMAT=image%2Fpng"
    . "&SRS=$area{crs}&BBOX=$area{left},$area{bottom},$area{right},$area{top}&WIDTH=$size&HEIGHT=$size"
    . "&EXCEPTIONS=application%2Fvnd.ogc.se_inimage";

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
print $q->header('text/html');
print <<EOT;
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


=end

=head1 TITLE

wmsthmb.pl

=head1 PARAMETERS

  wmssetup= link to setup file
  size= thumbnail size in pixels (square)

=head1 DESCRIPTION

Generate HTML for WMS thumbnail iframes

=head1 TODO

  EITHER combine with ec2wmc and rename
  OR separate common funcs in library

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
