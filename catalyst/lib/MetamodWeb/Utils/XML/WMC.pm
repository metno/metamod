package MetamodWeb::Utils::XML::WMC;

=begin LICENSE

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

use warnings;

use Moose;
use namespace::autoclean;
use XML::LibXML::XPathContext;
use Metamod::WMS;
use Carp;

has 'c' => (
    is       => 'ro',
    required => 1,
    handles  => {
        meta_db => [ model => 'Metabase' ],
        user_db => [ model => 'Usebase' ],
    }
);


sub setup2wmc {

    my ($self, $setup, $wmsurl) = @_;

    my $xslfile = $self->c->path_to( qw(root xsl gc2wmc.xsl) );

    my $setupxc = XML::LibXML::XPathContext->new( $setup->documentElement() );
    $setupxc->registerNs('s', "http://www.met.no/schema/metamod/ncWmsSetup");

    my $time = localtime();
    my %bbox = ( time => $time ); # currently only used for debug

    foreach ( $setupxc->findnodes('/*/s:displayArea/@*') ) {
        my ($k, $v) = ($_->localname, $_->getValue);
        $bbox{ $k } = $v; #( $v != 0 ) ? $v : "'$v'";
        #printf STDERR " -- %s = %s\n", $k, $v;
    }

    %bbox = ( # Trond HACK
        crs     => 'EPSG:432600',
        #crs     => 'EPSG:4326',
        #crs     => 'EPSG:42000',
        left    => 0,
        bottom  => 30,
        right   => 60,
        top     => 90,
        time    => $time,
        transparent => 'true', # FIXME handle via wmssetup instead
    ) if defined $wmsurl && $wmsurl =~ q|^http://dev-vm202/|;

    $bbox{units} = $setupxc->findvalue('/*/s:layer');

    my %coastlinemaps = ( # read from master_config
        "EPSG:4326"  => "http://wms.met.no/maps/world.map?",
        "EPSG:32661" => "http://wms.met.no/maps/northpole.map?",
        "EPSG:32761" => "http://wms.met.no/maps/southpole.map?",
    );

    $bbox{'map'} = $coastlinemaps{'EPSG:32661'};

    #################################
    # transform Capabilities to WMC
    #
    my $xslt = XML::LibXSLT->new();
    my $wmcns = "http://www.opengis.net/context";
    my $getcap_url = $wmsurl || $setup->documentElement->getAttribute('url') or die("Missing setup or WMS url");
    #printf STDERR "XML: %s\n", $getcap_url;
    # Trond test for HALO...
    #$getcap_url = 'http://dev-vm202/cgi-bin/getcapabilities2.cgi/verportal/verportal2';
    $getcap_url .= '?service=WMS&version=1.3.0&request=GetCapabilities';
    my $stylesheet = $xslt->parse_stylesheet_file($xslfile);
    my $dom = eval { getXML($getcap_url) };
    croak " error: $@" if $@;
    my $results = eval { $stylesheet->transform( $dom, XML::LibXSLT::xpath_to_string(%bbox) ); };
    croak " error: $@" if $@;

    my $gcxc = XML::LibXML::XPathContext->new( $results->documentElement() ); # getcapabilities xpath context
    $gcxc->registerNs('v', $wmcns);
    #$gcxc->registerNs('ol', 'http://openlayers.org/context');
    my ($layerlist) = $gcxc->findnodes('/*/v:LayerList');


    ######################
    # sort layers & styles
    #
    my $newlayers = $results->createElementNS($wmcns, 'LayerList');
    my $defaultlayer;

    # loop thru layers in setup file
    foreach my $setuplayer ( $setupxc->findnodes('/*/s:layer') ) {
        my $lname = $setuplayer->getAttribute('name');
        if ($lname eq '*') {
            $defaultlayer = $setuplayer;
            next;
        }
        my $style = lc $setuplayer->getAttribute('style') || '';
        #printf STDERR "*WMC* setup: %s - %s\n", $lname, $style;
        # find matching layer nodes in Capabilities
        foreach my $gclayer ($gcxc->findnodes("v:Layer[v:Name = '$lname']", $layerlist)) {
            # should only loop once
            #printf STDERR "*WMC* getcap: %s\n", $layer->serialize;
            foreach my $gcstyle ( $gcxc->findnodes("v:StyleList/v:Style[v:Name = '$style']", $gclayer) ) { # FIXME: wrong namespace
                #printf STDERR "*WMC* stylelist: %s\n", $gcstyle->serialize;
                $gcstyle->setAttribute('current', 1);
                # move preferred style node to top of list - FIXME
                my $pn = $gcstyle->parentNode;
                $pn->insertBefore( $pn->removeChild($gcstyle), $pn->firstChild );
            }

            if ($setuplayer->getAttribute('transparent') eq 'true') {
                $gclayer->addNewChild( 'http://openlayers.org/context', 'ol:transparent' )->appendTextNode('true');
                $gclayer->addNewChild( 'http://openlayers.org/context', 'ol:opacity' )->appendTextNode('0.6');
            } else {
                $gclayer->addNewChild( 'http://openlayers.org/context', 'ol:transparent' )->appendTextNode('false');
            }

            # move priority layer to new list
            #$newlayers->appendChild( $layerlist->removeChild($gclayer) );
            $newlayers->insertBefore( $layerlist->removeChild($gclayer), $newlayers->firstChild );
        }
    }

    # move rest of layers to new list
    foreach ($gcxc->findnodes("v:Layer", $layerlist)) {
        $_->setAttribute('hidden', 1) if $gcxc->findvalue('v:Name', $_) eq 'diana';

        if (defined $defaultlayer && $defaultlayer->getAttribute('transparent') eq 'true') {
            $_->addNewChild( 'http://openlayers.org/context', 'ol:transparent' )->appendTextNode('true');
            $_->addNewChild( 'http://openlayers.org/context', 'ol:opacity' )->appendTextNode('0.6');
        } else {
            $_->addNewChild( 'http://openlayers.org/context', 'ol:transparent' )->appendTextNode('false');
        }

        my $lay = $newlayers->insertBefore( $layerlist->removeChild($_), $newlayers->firstChild );
    }

    # replace old (empty) layer list with new sorted
    $layerlist->addSibling($newlayers);
    $layerlist->unbindNode;

    return $results;

}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
