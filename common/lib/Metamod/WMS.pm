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

package Metamod::WMS;
use base qw(Exporter);
use strict;
use warnings;

use CGI;
use LWP::UserAgent;
use XML::LibXML;
use Log::Log4perl qw(get_logger);
use Metamod::Config;
use Data::Dumper;

our @EXPORT = qw(logger param abandon getXML getSetup outputXML defaultWMC);

####################
# init
#

my $q = CGI->new;
my $parser = XML::LibXML->new;
my $logger = get_logger('metamod.search');

#sub new {
#	bless [$q, $parser, $config, $logger], shift;
#}

sub logger {
	return $logger;
}

sub param {
	return $q->param(shift);
}

####################
# report error
#
sub abandon {
    my $text = shift || 'Something went wrong';
    my $status = shift || 500;
    print $q->header('text/html', $status);
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
    $logger->error($text);
    die $text;
}


####################
# webservice client
#
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
        eval { $dom = $parser->parse_string($response->content) } or abandon($@, 502);
        return $dom;
    }
    else {
        abandon($response->status_line . ': ' . $url, 502);
    }
}

####################
# read setup file (or dummy if not given)
#
sub getSetup {
	my $setup_url = shift;
	my $setup = $setup_url ? getXML($setup_url) : defaultWMC();
	my $sxc = XML::LibXML::XPathContext->new( $setup->documentElement() );
	$sxc->registerNs('s', "http://www.met.no/schema/metamod/ncWmsSetup");
	return ($setup, $sxc);
}

####################
# webservice output
#
sub outputXML {
	my ($ctype, $content) = @_;
	print $q->header($ctype);
	print $content;
}

####################
# dummy WMCsetup document
# used when using GetCapabilities instead of setup file
#
sub defaultWMC {
	my $p = shift;

	my $crs    = $$p{crs}    || 'EPSG:32661';
	my $left   = $$p{left}   || '-3000000';
	my $right  = $$p{right}  ||  '7000000';
	my $bottom = $$p{bottom} || '-3000000';
	my $top    = $$p{top}    ||  '7000000';
	# TODO some validation?

	my $bgurl = 'http://wms.met.no/maps/world.map';
	my $baselayer = qq|<w:baselayer url="$bgurl" name="world" />| if $bgurl;

#	print STDERR Dumper $p;
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
	return $parser->parse_string($default_wmc);
}

1;

=head1 NAME

Metamod::WMS - WMS helper methods

=head1 SYNOPSIS

  use Metamod::WMS;


=head1 DESCRIPTION

.....


=cut
