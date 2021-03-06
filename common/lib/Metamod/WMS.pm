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
  my $xml = getXML('http://example.com/wms?service=WMS&version=1.3.0&request=GetCapabilities');

=head1 DESCRIPTION

Various helper functions for WMS

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

our @EXPORT = qw(logger param getXML getMaps getMapURL getSetup outputXML defaultWMC getProjName bgmapURLs);

####################
# init
#

# FIXME rewrite as OO

my $q = CGI->new;
my $logger = get_logger('metamod.search');
my $config = Metamod::Config->instance();

my $bbox = $config->split('WMS_BOUNDING_BOXES');
my $coastlinemaps = $config->split('WMS_MAPS');
my $projnames = $config->split('WMS_PROJECTIONS');
#print STDERR Dumper \$projnames;

sub logger { # pollutes global namespace... FIXME
    return $logger;
}

sub param { # pollutes global namespace... FIXME
    return $q->param(shift);
}

=head2 getXML()

Fetch XML document from URL and parse as libxml DOM object. Must be eval'ed

=cut

sub getXML {
    my $url = shift or die "Missing URL";
    croak "getXML: Malformed URL in '$url'" unless $url =~ /^http:/;
    $logger->debug('GET ' . $url);
    my $ua = LWP::UserAgent->new;
    $ua->timeout(100);
    #$ua->env_proxy;

    my $response = $ua->get($url);

    if ($response->is_success) {
        #print STDERR $response->content;
        my $dom;
        eval { $dom = XML::LibXML->load_xml( string => $response->content ) }
            or croak($@);
        return $dom;
    }
    else {
        $logger->warn("getXML failed for for $url: " . $response->status_line);
        croak "getXML failed for for $url: " . $response->status_line;
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

=head2 getMaps

fdas fds fdasfdas

=cut

sub getMaps {

    # openlayers map bbox selector
    my %searchmaps;
    my $wmsprojs = $config->split('WMS_PROJECTIONS');
    foreach (keys %$wmsprojs) {
        my $crs = $_;
        my ($code) = /^EPSG:(\d+)/ or next; # search map needs just EPSG numeric code
        my $name = $wmsprojs->{$crs};
        my $url = getMapURL($crs) or next;
        $searchmaps{$code} = {
            url     => $url,
            name    => "$name ($crs)"|| getProjName($crs) || $crs,
        };
    }
    #print STDERR Dumper \%searchmaps;
    return \%searchmaps;
}

=head2 getMapURL(crs)

Lookup WMS URL to background map for given CRS code

=cut

sub getMapURL {
    my $crs = shift or croak "Missing parameter 'crs'";

    #$logger->debug("Getting map URL for $crs");

    my $mapurl = $$coastlinemaps{ $crs };
    if (! defined $$coastlinemaps{ $crs } ) {
        # fallback to deprecated method if WMS_MAPS is not defined
        my %mapconfig = (
            "EPSG:4326"  => "WMS_WORLD_MAP",
            "EPSG:32661" => "WMS_NORTHPOLE_MAP",
            "EPSG:32761" => "WMS_SOUTHPOLE_MAP",
        );
        return unless defined $mapconfig{$crs}; # some projections will always lack background maps

        my $mapurl = $config->get('WMS_BACKGROUND_MAPSERVER') . $config->get( $mapconfig{$crs} );
    }

    return $mapurl if $mapurl =~ /\?&$/; # ok if ends with ? or &
    return ($mapurl =~ /\?/) ? "$mapurl&" : "$mapurl?"; # else add whatever is needed
}

=head2 defaultWMC()

Dummy WMCsetup document - used when using GetCapabilities instead of setup file

=cut

sub defaultWMC {
    my $p = shift; # probably should require CRS param

    my $layername = 'world'; # that's how it's called on wms.met.no... FIXME

    my $crs    = $$p{crs}    || 'EPSG:32661';
    my $left   = $$p{left}   || $$bbox{$crs}->[0];
    my $right  = $$p{right}  || $$bbox{$crs}->[1];
    my $bottom = $$p{bottom} || $$bbox{$crs}->[2];
    my $top    = $$p{top}    || $$bbox{$crs}->[3];
    # TODO some validation?

    my $bgurl = getMapURL($crs);
    my $baselayer = $bgurl ? qq|<w:baselayer url="$bgurl" name="$layername" />| : ''; #

    $logger->debug("*** defaultWMC CRS = $crs; URL = $bgurl");

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

    eval { return XML::LibXML->load_xml( string => $default_wmc ) }
        or die "Error in parsing default WMC";
}

=head2 getProjName()

Look up a descriptive name for a given EPSG code

=cut

sub getProjName {
    my $code = shift or die;
    #return $projections{$code}->[0];
    return $$projnames{$code};
}

=head2 projList()

Return the list of defined projections (used in templates to generate menus)

=cut

sub projList {
    #print STDERR Dumper \%projections;
    use Clone qw(clone); # TT seems to mess up data structure, so best copy it
    #return clone \%projections;
    return clone $projnames;
}

=head2 bgmapURLs()

Return the list of defined WMS background map URLs

=cut

sub bgmapURLs {
    use Clone qw(clone); # TT seems to mess up data structure, so best copy it
    return clone $coastlinemaps;
}

1;

=head1 AUTHOR

Geir Aalberg, E<lt>geira@met.noE<gt>

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

