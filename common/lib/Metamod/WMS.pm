=begin LICENCE

----------------------------------------------------------------------------
  METAMOD - Web portal for metadata search and upload

  Copyright (C) 2010 met.no

  Contact information:
  Norwegian Meteorological Institute
  Box 43 Blindern
  0313 OSLO
  NORWAY
  email: geir.aalberg@met.no

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

=end LICENCE

=cut

=head1 NAME

Metamod::WMS - WMS helper methods

=head1 SYNOPSIS

  use Metamod::WMS;

=head1 DESCRIPTION

.....

=cut

package Metamod::WMS;
use base qw(Exporter);
use strict;
use warnings;

use CGI;
use Carp;
use LWP::UserAgent;
use XML::LibXML;
use Log::Log4perl qw(get_logger);
use Metamod::Config;
use Data::Dumper;
use Hash::Util qw{ lock_hash  unlock_hash };

our @EXPORT = qw(logger param abandon getXML getMapURL getSetup outputXML defaultWMC getProjName getProjString bgmapURLs);

####################
# init
#

my $q = CGI->new;
my $parser = XML::LibXML->new( load_ext_dtd => 0 );
my $logger = get_logger('metamod.search');
my $config = Metamod::Config->instance();

my $bbox = $config->split('WMS_BOUNDING_BOXES');
my $coastlinemaps = $config->split('WMS_MAPS');
my $proj = $config->split('WMS_PROJECTIONS');
#print STDERR Dumper \$proj;

#sub new {
#    bless [$q, $parser, $config, $logger], shift;
#}

sub logger {
    return $logger;
}

sub param {
    return $q->param(shift);
}

=head2 abandon()

Report error as HTML and die

=cut

sub abandon { # deprecated - use catalyst controllers instead
    my $text = shift || 'Something went wrong';
    my $status = shift || 500;
    print $q->header('text/html', $status); # doesn't work under catalyst which already has sent headers ...
    print <<EOT;
<html>
<head>
    <title>WMC generator error</title>
</head>
<body>
    <h1>WMC generator error</h1>
    <p>$text</p>
</body>
</html>
EOT
    $logger->logcarp($text);
    croak $text;
}

=head2 getXML()

Fetch XML document from URL and parse as libxml DOM object

=cut

sub getXML {
    my $url = shift or die "Missing URL";
    $logger->debug('GET ' . $url);
    my $ua = LWP::UserAgent->new;
    $ua->timeout(100);
    #$ua->env_proxy;

    my $response = $ua->get($url);

    if ($response->is_success) {
        #print STDERR $response->content;
        my $dom;
        #eval { $dom = $parser->parse_string($response->content) } or abandon($@, 502);
        eval { $dom = $parser->parse_string($response->content) } or croak($@);
        return $dom;
    }
    else {
        #abandon($response->status_line . ': ' . $url, 502);
        $logger->info("getXML failed for for $url: " . $response->status_line);
        die("getXML failed for for $url: " . $response->status_line);
    }
}

=head2 getSetup()

read setup file (or dummy if not given)

=cut

sub getSetup {
    my $setup_url = shift;
    my $setup = $setup_url ? getXML($setup_url) : defaultWMC();
    my $sxc = XML::LibXML::XPathContext->new( $setup->documentElement() );
    $sxc->registerNs('s', "http://www.met.no/schema/metamod/ncWmsSetup");
    return ($setup, $sxc);
}

=head2 outputXML()

output data to webservice

=cut

sub outputXML { # move this stuff to a Catalyst controller
    my ($ctype, $content) = @_;
    print $q->header($ctype);
    print $content;
}

=head2 getMapURL(crs)

Lookup WMS URL to background map for given CRS code

TODO: read from master_config (not working... FIXME)

=cut

sub getMapURL {
    my $crs = shift or croak "Missing parameter 'crs'";

    my %mapconfig = (
        "EPSG:4326"  => "WMS_WORLD_MAP",
        "EPSG:32661" => "WMS_NORTHPOLE_MAP",
        "EPSG:32761" => "WMS_SOUTHPOLE_MAP",
    );

    #my $config = Metamod::Config->instance();
    my $mapurl = $$coastlinemaps{ $crs } ||
        $config->get('WMS_BACKGROUND_MAPSERVER') . $config->get( $mapconfig{$crs} );

    #my $coastlinemaps = $config->split('WMS_MAPS');
#    ( # TODO: read from master_config... FIXME
#        "EPSG:4326"  => "http://wms.met.no/maps/world.map",
#        "EPSG:32661" => "http://wms.met.no/maps/northpole.map",
#        "EPSG:32761" => "http://wms.met.no/maps/southpole.map",
#        'EPSG:3995'  => "http://dev-vm070/backgroundmaps/northpole.map", # FIXME update with production servers
#        'EPSG:3031'  => "http://dev-vm070/backgroundmaps/southpole.map",
#    );
    return $mapurl;
}

=head2 defaultWMC()

Dummy WMCsetup document - used when using GetCapabilities instead of setup file

=cut

sub defaultWMC {
    my $p = shift; # probably should require CRS param

    #my %bbox = $config->split('WMS_BOUNDING_BOXES');
#    ( # WESN
#        'EPSG:4326'  => [ '-180', '180', '-90', '90' ],
#        'EPSG:32661' => [ '-3000000', '7000000', '-3000000', '7000000' ],
#        #'EPSG:32761' => [ "-1.99038e+08", "1.66053e+08", "-9.12659e+07", "1.97215e+08" ],
#        'EPSG:32761' => [ "-3000000", "7000000", "-3000000", "7000000" ],
#        'EPSG:3995'  => [ '-5000000', '5000000', '-5000000', '5000000' ],
#        'EPSG:3031'  => [ "-5000000", "5000000", "-5000000", "5000000" ],
#    );

    my $layername = 'world'; # that's how it's called on wms.met.no... FIXME

    my $crs    = $$p{crs}    || 'EPSG:32661';
    my $left   = $$p{left}   || $$bbox{$crs}->[0];
    my $right  = $$p{right}  || $$bbox{$crs}->[1];
    my $bottom = $$p{bottom} || $$bbox{$crs}->[2];
    my $top    = $$p{top}    || $$bbox{$crs}->[3];
    # TODO some validation?

    my $bgurl = getMapURL($crs); # 'http://wms.met.no/maps/world.map';
    my $baselayer = $bgurl ? qq|<w:baselayer url="$bgurl" name="$layername" />| : ''; #

    print STDERR "*** $crs *** $bgurl ***\n" . Dumper $$bbox{$crs};

    my $default_wmc = <<EOT;
<?xml version="1.0"?>
<w:ncWmsSetup
    xmlns:w="http://www.met.no/schema/metamod/ncWmsSetup"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.met.no/schema/metamod/ncWmsSetup ncWmsSetup.xsd ">
    <w:displayArea crs="$crs" left="$left" right="$right" bottom="$bottom" top="$top"/>
    $baselayer
</w:ncWmsSetup>
EOT

    #print STDERR $default_wmc;

    return $parser->parse_string($default_wmc) or die "Error in parsing default WMC";
}

#my %projections = (
#    # in future, use WMS_PROJECTIONS in master_config instead of this hardcoded list
#    # currently not possible to access master_config at compile time
#
#    # supported since 2.5.0
#    'EPSG:32661' => ['WGS 84 / UPS North', 'WMS_NORTHPOLE_MAP'],
#    'EPSG:32761' => ['WGS 84 / UPS South', 'WMS_SOUTHPOLE_MAP'],
#    'EPSG:4326'  => ['WGS 84', 'WMS_WORLD_MAP'],
#
#    'EPSG:3995' => ['WGS 84 / Arctic Polar Stereographic', 'WMS_NORTHPOLE_MAP'],
#    'EPSG:3031' => ['WGS 84 / Antarctic Polar Stereographic', 'WMS_SOUTHPOLE_MAP'],
#
#    # (hopefully) supported in 2.12.2
#    'EPSG:3408'  => ['NSIDC EASE-Grid North'],
#    'EPSG:3409'  => ['NSIDC EASE-Grid South'],
#    'EPSG:3410'  => ['NSIDC EASE-Grid Global'],
#    'EPSG:3411'  => ['NSIDC Sea Ice Polar Stereographic North'],
#    'EPSG:3412'  => ['NSIDC Sea Ice Polar Stereographic South'],
#    'EPSG:3413'  => ['WGS 84 / NSIDC Sea Ice Polar Stereographic North'],
#    'EPSG:3995'  => ['WGS 84 / Arctic Polar Stereographic'],
#    'EPSG:32633' => ['WGS 84 / UTM zone 33N'],
#
#);

# we don't want templates to mess up the list by adding junk which will persist to next request
#lock_hash(%projections); # breaks in TT when projs.key is used as hash key instead of method

=head2 getProjName()

Look up a descriptive name for a given EPSG code

=cut

sub getProjName {
    my $code = shift or die;
    #return $projections{$code}->[0];
    return $$proj{$code};
}

=head2 getProjMap()

Look up a WMS url for any background map configured for a given EPSG code

B<DISABLED> - use getMapURL() instead

=cut

#sub getProjMap {
#    my $code = shift or die;
#    return $projections{$code}->[1];
#}

=head2 projList()

Return the list of defined projections (used in templates to generate menus)

=cut

sub projList {
    #print STDERR Dumper \%projections;
    use Clone qw(clone); # TT seems to mess up data structure, so best copy it
    #return clone \%projections;
    return clone $proj;
}

=head2 bgmapURLs

Return the list of defined WMS background map URLs

=cut

sub bgmapURLs {
    use Clone qw(clone); # TT seems to mess up data structure, so best copy it
    return clone $coastlinemaps;
}

1;
