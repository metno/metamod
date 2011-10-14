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

    my $sxc = XML::LibXML::XPathContext->new( $setup->documentElement() );
    $sxc->registerNs('s', "http://www.met.no/schema/metamod/ncWmsSetup");

    my $time = localtime();
    my %bbox = ( time => $time );
    foreach ( $sxc->findnodes('/*/s:displayArea/@*') ) {
        my ($k, $v) = ($_->localname, $_->getValue);
        $bbox{ $k } = $v; #( $v != 0 ) ? $v : "'$v'";
        #printf STDERR " -- %s = %s\n", $k, $v;
    }

    #################################
    # transform Capabilities to WMC
    #
    my $xslt = XML::LibXSLT->new();
    my $wmcns = "http://www.opengis.net/context";
    my $getcap = $wmsurl || $setup->documentElement->getAttribute('url') or die("Missing setup or WMS url");
    #printf STDERR "XML: %s\n", $getcap;
    $getcap .= '?service=WMS&version=1.3.0&request=GetCapabilities';
    my $stylesheet = $xslt->parse_stylesheet_file($xslfile);
    my $results = eval { $stylesheet->transform( getXML($getcap), XML::LibXSLT::xpath_to_string(%bbox) ); };
    croak " error: $@" if $@;
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
        my $style = lc $_->getAttribute('style') || '';
        #printf STDERR "*WMC* setup: %s - %s\n", $lname, $style;
        # find matching layer nodes in Capabilities
        foreach my $gclayer ($xc->findnodes("v:Layer[v:Name = '$lname']", $layerlist)) {
            #printf STDERR "*WMC* getcap: %s\n", $layer->serialize;
            foreach my $gcstyle ( $xc->findnodes("v:StyleList/v:Style[v:Name = '$style']", $gclayer) ) { # FIXME: wrong namespace
                #printf STDERR "*WMC* stylelist: %s\n", $gcstyle->serialize;
                $gcstyle->setAttribute('current', 1);
                # move preferred style node to top of list
                my $pn = $gcstyle->parentNode;
                $pn->insertBefore( $pn->removeChild($gcstyle), $pn->firstChild );
            }
            # move priority layer to new list
            $newlayers->appendChild( $layerlist->removeChild($gclayer) );
        }
    }

    # move rest of layers to new list
    foreach ($xc->findnodes("v:Layer", $layerlist)) {
        $newlayers->appendChild( $layerlist->removeChild($_));
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
