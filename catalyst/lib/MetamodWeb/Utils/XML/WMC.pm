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
use Data::Dumper;

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

    my $setupxc = XML::LibXML::XPathContext->new( $setup->documentElement() );
    $setupxc->registerNs('s', "http://www.met.no/schema/metamod/ncWmsSetup");

    my $time = localtime();
    my %bbox = ( time => $time ); # currently only used for debug

    foreach ( $setupxc->findnodes('/*/s:displayArea/@*') ) {
        my ($k, $v) = ($_->localname, $_->getValue);
        $bbox{ $k } = $v; #( $v != 0 ) ? $v : "'$v'";
        #printf STDERR " -- %s = %s\n", $k, $v;
    }

    %bbox = ( # wmsdiana test hack - FIXME
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


    #################################
    # transform data Capabilities to WMC
    #
    my $getcap_url = $wmsurl || $setup->documentElement->getAttribute('url') or die("Missing setup or WMS url");
    my $wmcns = "http://www.opengis.net/context";

    my $results = $self->gc2wmc($getcap_url, \%bbox);

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
    foreach my $setuplayer ( $setupxc->findnodes('/*/s:layer|/*/s:baselayer') ) {
        my $lname = $setuplayer->getAttribute('name');
        if ($lname eq '*') {
            $defaultlayer = $setuplayer;
            next;
        }

        my $style = lc $setuplayer->getAttribute('style') || '';
        printf STDERR "*****WMC* setup %s: %s - %s\n", $setuplayer->localname, $lname, $style;

        if ( $setuplayer->getAttribute('url') ) {
            #do later
            next;
        }

        # find matching layer nodes in Capabilities
        foreach my $gclayer ($gcxc->findnodes("v:Layer[v:Name = '$lname']", $layerlist)) {
            # should only loop once
            printf STDERR "*WMC* getcap: %s\n", $gclayer->serialize;
            foreach my $gcstyle ( $gcxc->findnodes("v:StyleList/v:Style[v:Name = '$style']", $gclayer) ) { # FIXME: wrong namespace
                printf STDERR "*WMC* stylelist: %s\n", $gcstyle->serialize;
                $gcstyle->setAttribute('current', 1);
                # move preferred style node to top of list - FIXME
                my $pn = $gcstyle->parentNode;
                $pn->insertBefore( $pn->removeChild($gcstyle), $pn->firstChild );
            }

            if ($setuplayer->localname eq 'baselayer') {
                $gclayer->addNewChild( 'http://openlayers.org/context', 'ol:transparent' )->appendTextNode('false');
            } else { # overlay
                $gclayer->addNewChild( 'http://openlayers.org/context', 'ol:transparent' )->appendTextNode('true');
                $gclayer->addNewChild( 'http://openlayers.org/context', 'ol:opacity' )->appendTextNode('0.6');
            }
            $gclayer->setAttribute('hidden', 0);

            # move priority layer to new list
            $newlayers->appendChild( $layerlist->removeChild($gclayer) );
        }
    }

    # move rest of layers to new list
    foreach ($gcxc->findnodes("v:Layer[not(child::v:Layer)]", $layerlist)) {
        #$_->setAttribute('hidden', 1) if $gcxc->findvalue('v:Name', $_) eq 'diana'; # FIXME

        #if (defined $defaultlayer && $defaultlayer->getAttribute('transparent') eq 'true') { # removed transp attr
            $_->addNewChild( 'http://openlayers.org/context', 'ol:transparent' )->appendTextNode('true');
            $_->addNewChild( 'http://openlayers.org/context', 'ol:opacity' )->appendTextNode('0.6');
        #} else {
        #    # default is currently baselayer... FIXME (must get background map into wmc first)
        #    $_->addNewChild( 'http://openlayers.org/context', 'ol:transparent' )->appendTextNode('false');
        #}

        $newlayers->appendChild( $layerlist->removeChild($_));
    }

    # replace old (empty) layer list with new sorted
    $layerlist->addSibling($newlayers);
    $layerlist->unbindNode;

    #
    # copy background map layers to wmc
    #
    my %coastlinemaps = ( # TODO: read from master_config... FIXME
        "EPSG:4326"  => "http://wms.met.no/maps/world.map",
        "EPSG:32661" => "http://wms.met.no/maps/northpole.map",
        "EPSG:32761" => "http://wms.met.no/maps/southpole.map",
    );

    if (my $mapurl = $coastlinemaps{ $bbox{'crs'}||'' }) {
        #printf STDERR "*** Getting map for %s\n", $bbox{'crs'};

        my $mapdoc = $self->gc2wmc($mapurl, \%bbox);
        my $mapxc = XML::LibXML::XPathContext->new( $mapdoc ); # getcapabilities xpath context
        $mapxc->registerNs('v', $wmcns);
        $mapxc->registerNs('ol', 'http://openlayers.org/context');

        # copy layer node from map wmc to output wmc
        foreach ( $mapxc->findnodes("/*/v:LayerList/v:Layer") ) { # find map layers
            #printf STDERR "\n*** copying map layer %s\n", $mapxc->findvalue('v:Name', $_);
            # after lots of experimatation, this seems to be the only method that works
            my $mpl = $_->cloneNode(1);
            $results->importNode($mpl);
            $newlayers->appendChild($mpl);
            # add transparency element
            my $isoverlay = $mapxc->findvalue('v:Name', $mpl) eq 'borders' ? 'true' : 'false';
            $mpl->addNewChild( 'http://openlayers.org/context', 'ol:transparent' )->appendTextNode($isoverlay);
        }

        #print STDERR $results->toString(1);

    }

    # TODO: remove non-universal SRS elements

    return $results;

}


#################################
# transform Capabilities to WMC
#
sub gc2wmc {
    my ($self, $wmsurl, $params) = @_;
    my $gcquery = '?service=WMS&version=1.3.0&request=GetCapabilities'; # can sometimes return 1.1.1
    my %stylesheets = (
        '1.3.0' => '/root/xsl/gc2wmc.xsl',
        '1.1.1' => '/root/xsl/gc111_2wmc.xsl'
    );

    my $xslt = XML::LibXSLT->new();
    # get capabilities xml
    my $dom = eval { getXML($wmsurl . $gcquery ) };
    croak " error: $@" if $@;

    # check if wms 1.1.1 or 1.3.0
    my $version = $dom->documentElement->getAttribute('version');
    #printf STDERR "+++++++++++ WMS ver %s\n", $version;

    my $stylesheet = $xslt->parse_stylesheet_file( $self->c->path_to( $stylesheets{$version} ) );
    # generate wmc from capab
    my $wmcdoc = eval {
        $stylesheet->transform( $dom, XML::LibXSLT::xpath_to_string( %{$params} ) );
    };
    croak " error: $@" if $@;

    return $wmcdoc;

}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
