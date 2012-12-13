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
#use Metamod::Config qw(getProjMap);
use List::Util qw(min max sum);
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

=head2 old_gen_wmc

Generate WMC document from Capabilities based on wmsinfo setup data

DEPRECATED: refactor to use setup2wmc instead.

=cut

sub old_gen_wmc { # DEPRECATED but seems to hang around for some time still

    my ($self, $setup, $wmsurl, $crs) = @_;
    croak "Missing setup document" unless $setup;
    croak "Missing WMS URL" unless $wmsurl;

    my $setupxc = XML::LibXML::XPathContext->new( $setup->documentElement() );
    $setupxc->registerNs('s', "http://www.met.no/schema/metamod/ncWmsSetup");

    my $time = localtime();
    my %bbox = ( time => $time ); # currently only used for debug

    foreach ( $setupxc->findnodes('/*/s:displayArea/@*') ) {
        my ($k, $v) = ($_->localname, $_->getValue);
        $bbox{ $k } = $v; #( $v != 0 ) ? $v : "'$v'";
        #printf STDERR " -- %s = %s\n", $k, $v;
    }

    $bbox{units} = $setupxc->findvalue('/*/s:layer');


    #################################
    # reproject coords in setup
    #
    if ( defined $crs and $crs ne $bbox{crs} ) {

        # stupid proj doesn't like upper case proj names
        my $to   = Geo::Proj4->new( init => lc($crs) )       or die Geo::Proj4->error . " for $crs";
        my $from = Geo::Proj4->new( init => lc($bbox{crs}) ) or die Geo::Proj4->error;
        my @corners = (
            [ $bbox{'left' }, $bbox{'bottom'} ],
            [ $bbox{'left' }, $bbox{'top'   } ],
            [ $bbox{'right'}, $bbox{'bottom'} ],
            [ $bbox{'right'}, $bbox{'top'   } ],
            # this could possibly extended with more points to avoid cropping of the bounding box
        );
        my $pr = $from->transform($to, \@corners);
        #print STDERR Dumper \@corners, $pr;

        my (@x, @y); # x resp y coord for each corner
        foreach (@$pr) {
            push @x, $_->[0];
            push @y, $_->[1];
        }

        #print STDERR 'x = ' . Dumper \@x;
        #print STDERR 'y = ' . Dumper \@y;

        $bbox{ crs    } = $crs;
        $bbox{ left   } = min(@x);
        $bbox{ right  } = max(@x);
        $bbox{ bottom } = min(@y);
        $bbox{ top    } = max(@y);

        #print STDERR Dumper \%bbox;

    }

    ####################################
    # transform data Capabilities to WMC
    #
    #my $getcap_url = $wmsurl || $setup->documentElement->getAttribute('url') or confess("Missing setup or WMS url");
    # reading wmsurl from setup is now deprecated - must be in function call

    my $wmcns = "http://www.opengis.net/context";

    my $results = eval { $self->_gen_wmc($wmsurl, \%bbox) } or die $@;

    my $gcxc = XML::LibXML::XPathContext->new( $results->documentElement() ); # getcapabilities xpath context
    $gcxc->registerNs('v', $wmcns);
    #$gcxc->registerNs('ol', 'http://openlayers.org/context');
    my ($layerlist) = $gcxc->findnodes('/*/v:LayerList');


    ######################
    # sort layers & styles
    #
    my $newlayers = $results->createElementNS($wmcns, 'LayerList');
    my $hidden = 0;
    my $nobaselayer = 1;

    # loop thru layers in setup file
    foreach my $setuplayer ( $setupxc->findnodes('/*/s:layer|/*/s:baselayer') ) {
        my $lname = $setuplayer->getAttribute('name');
        if ($lname eq '*') { # DEPRECATED
            next;
        }

        my $style = lc $setuplayer->getAttribute('style') || '';
        #printf STDERR "*****WMC* setup %s: %s - %s\n", $setuplayer->localname, $lname, $style;

        if ( $setuplayer->getAttribute('url') ) {
            #do later
            next;
        }

        # find matching layer nodes in Capabilities
        foreach my $gclayer ($gcxc->findnodes("v:Layer[v:Name = '$lname']", $layerlist)) {
            # should only loop once
            #printf STDERR "*WMC* getcap: %s\n", $gclayer->serialize;
            foreach my $gcstyle ( $gcxc->findnodes("v:StyleList/v:Style[v:Name = '$style']", $gclayer) ) { # FIXME: wrong namespace
                #printf STDERR "*WMC* stylelist: %s\n", $gcstyle->serialize;
                $gcstyle->setAttribute('current', 1);
                # move preferred style node to top of list - FIXME
                my $pn = $gcstyle->parentNode;
                $pn->insertBefore( $pn->removeChild($gcstyle), $pn->firstChild );
            }

            if ($setuplayer->localname eq 'baselayer') {
                $gclayer->addNewChild( 'http://openlayers.org/context', 'ol:transparent' )->appendTextNode('false');
                $nobaselayer = 0;
            } else { # overlay
                $gclayer->addNewChild( 'http://openlayers.org/context', 'ol:transparent' )->appendTextNode('true');
                $gclayer->addNewChild( 'http://openlayers.org/context', 'ol:opacity' )->appendTextNode('0.6');
            }
            $gclayer->setAttribute('hidden', $hidden++&&1); # sets all layers in wmsinfo visible

            # move priority layer to new list
            $newlayers->appendChild( $layerlist->removeChild($gclayer) );
        }
    }

    # move rest of layers to new list
    foreach ($gcxc->findnodes("v:Layer[not(child::v:Layer)]", $layerlist)) {
        #$_->setAttribute('hidden', 1) if $gcxc->findvalue('v:Name', $_) eq 'diana'; # FIXME

        $_->addNewChild( 'http://openlayers.org/context', 'ol:transparent' )->appendTextNode('true');
        $_->addNewChild( 'http://openlayers.org/context', 'ol:opacity' )->appendTextNode('0.6');

        $newlayers->appendChild( $layerlist->removeChild($_));
    }

    # replace old (empty) layer list with new sorted
    $layerlist->addSibling($newlayers);
    $layerlist->unbindNode;

    #
    # copy background map layers to wmc
    #
    if ( $nobaselayer and (my $mapconf = getProjMap( $bbox{'crs'} )) ) {
        printf STDERR "*** Getting map for %s\n", $bbox{'crs'};

        my $mapurl = getMapURL( $bbox{'crs'} );

        my $mapdoc = $self->_gen_wmc($mapurl, \%bbox);
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


=head2 _gen_wmc

Download Capabilities and transform to WMC

=cut

sub _gen_wmc {
    my ($self, $wmsurl, $params) = @_;
    my $gcquery = '?service=WMS&version=1.3.0&request=GetCapabilities'; # can sometimes return 1.1.1
    my %stylesheets = (
        '1.3.0' => '/root/xsl/gc2wmc.xsl',
        '1.1.1' => '/root/xsl/gc111_2wmc.xsl'
    );

    my $xslt = XML::LibXSLT->new();
    # get capabilities xml
    my $dom = eval {
        getXML($wmsurl . $gcquery ) # use wmscap in Dataset FIXME
    } or die $@;
    #if ($@) {
    #    print STDERR "+++++++++++++ $@\n\n";
    #    die $@;
    #}

    # check if wms 1.1.1 or 1.3.0
    my $version = $dom->documentElement->getAttribute('version');
    #printf STDERR "+++++++++++ WMS ver %s\n", $version;

    my $stylesheet = $xslt->parse_stylesheet_file( $self->c->path_to( $stylesheets{$version} ) );
    # generate wmc from capab
    my $wmcdoc = eval {
        $stylesheet->transform( $dom, XML::LibXSLT::xpath_to_string( %{$params} ) );
    } or die $@;

    return $wmcdoc;

}

=head2 setup2wmc

Generate WMC directly from wmsinfo setup document (can merge several Capabilities docs)

=cut

sub setup2wmc {
    my ($self, $setup, $params) = @_;

    my $xslt = XML::LibXSLT->new();

    my $stylesheet = $xslt->parse_stylesheet_file( $self->c->path_to( '/root/xsl/setup2wmc.xsl' ) );
    my $wmcdoc = eval {
        $stylesheet->transform( $setup, XML::LibXSLT::xpath_to_string( %{$params} ) );
    };
    croak " error: $@" if $@;

    #print STDERR $wmcdoc->serialize;

    return $wmcdoc;

}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
