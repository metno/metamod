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
use Log::Log4perl qw(get_logger);
use List::Util qw(min max sum);
use Carp;
use Data::Dumper;

my $logger = get_logger(); # 'metamod.search.wms'

=head1 NAME

MetamodWeb::Utils::XML::WMC - helper methods for WMC generation

=head1 DESCRIPTION

Uses wmsinfo on dataset to fetch WMS Capabilities and build up WMC document with
available layers and styles. Includes background map from central server where available.

=cut

has 'c' => (
    is       => 'ro',
    required => 1,
    handles  => {
        meta_db => [ model => 'Metabase' ],
        user_db => [ model => 'Usebase' ],
    }
);

=head1 METHODS

=head2 old_gen_wmc

Generate WMC document from Capabilities based on wmsinfo setup data

DEPRECATED: refactor to use setup2wmc instead.

=cut

sub old_gen_wmc { # DEPRECATED but seems to hang around for some time still

    my ($self, $setup, $wmsurl, $crs) = @_;
    croak "Missing setup document" unless $setup;
    croak "Missing WMS URL" unless $wmsurl;

    #print STDERR "** SETUP = " . $setup->toString(1) . "\n\n";

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
    _reproject($crs, \%bbox);

    $logger->debug("old_gen_wmc: " . Dumper \%bbox);

    ####################################
    # transform data Capabilities to WMC
    #
    #my $getcap_url = $wmsurl || $setup->documentElement->getAttribute('url') or confess("Missing setup or WMS url");
    # reading wmsurl from setup is now deprecated - must be in function call

    my $wmcns = "http://www.opengis.net/context";

    my $results = eval { $self->_gen_wmc($wmsurl, \%bbox) } or die $@;
    #print STDERR "** WMC before sorting:\n" . $results->toString(1) . "\n\n";

    my $gcxc = XML::LibXML::XPathContext->new( $results->documentElement() ); # getcapabilities xpath context
    $gcxc->registerNs('v', $wmcns);
    #$gcxc->registerNs('ol', 'http://openlayers.org/context');
    my ($layerlist) = $gcxc->findnodes('/*/v:LayerList');

    ######################
    # sort layers & styles
    #
    my $newlayers = $results->createElementNS($wmcns, 'LayerList');
    my $hidden = 0;
    my @baselayers = ();

    # loop thru layers in setup file
    foreach my $setuplayer ( $setupxc->findnodes('/*/s:layer|/*/s:baselayer') ) {
        my $lname = $setuplayer->getAttribute('name');
        if ($lname eq '*') { # DEPRECATED
            next;
        }

        my $style = lc ($setuplayer->getAttribute('style') || '');
        my $layertype = $setuplayer->localname;
        #printf STDERR "***** WMC setup %s: %s (%s)\n", $layertype, $lname, $style||'-';

        if ( $setuplayer->getAttribute('url') ) {
            # implement custom url later (FIXME)
            #next; # why? this means it'll skip sorting and baselayers won't show up
        }

        # find matching layer nodes in Capabilities
        my $matching_layers = $gcxc->findnodes("v:Layer[v:Name = '$lname']", $layerlist);
        #printf STDERR "####### found %d layers named %s\n", scalar @$matching_layers, $lname;
        foreach my $gclayer (@$matching_layers) {
            # should only loop once
            #printf STDERR "**** WMC **** $layertype getcap ************\n%s\n", $gclayer->serialize(1);
            foreach my $gcstyle ( $gcxc->findnodes("v:StyleList/v:Style[v:Name = '$style']", $gclayer) ) { # FIXME: wrong namespace
                #printf STDERR "*WMC* stylelist: %s\n", $gcstyle->serialize;
                $gcstyle->setAttribute('current', 1);
                # move preferred style node to top of list - FIXME
                my $pn = $gcstyle->parentNode;
                $pn->insertBefore( $pn->removeChild($gcstyle), $pn->firstChild );
            }

            if ($layertype eq 'baselayer') {
                $gclayer->addNewChild( 'http://openlayers.org/context', 'ol:transparent' )->appendTextNode('false');
                push @baselayers, $lname;
                $logger->debug("*** $layertype $lname is opaque");
            } else { # overlay
                $gclayer->addNewChild( 'http://openlayers.org/context', 'ol:transparent' )->appendTextNode('true');
                $gclayer->addNewChild( 'http://openlayers.org/context', 'ol:opacity' )->appendTextNode('0.6');
                $logger->debug("*** $layertype $lname is transparent");
            }
            $gclayer->setAttribute('hidden', $hidden++&&1); # sets all layers in wmsinfo visible

            foreach ( $gcxc->findnodes("v:SRS", $gclayer) ) {
                $logger->debug( "*** SRS for $layertype $lname:", $_->textContent);
            }

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
    if (@baselayers) {
        $logger->debug("old_gen_wmc: bundled baselayers: ", join(' ', @baselayers) );
    } elsif ( my $mapurl = getMapURL($bbox{'crs'}) ) {
        $logger->debug("old_gen_wmc: Getting map for " . $bbox{'crs'});

        my $mapdoc = $self->_gen_wmc($mapurl, \%bbox);
        my $mapxc = XML::LibXML::XPathContext->new( $mapdoc ); # getcapabilities xpath context
        $mapxc->registerNs('v', $wmcns);
        $mapxc->registerNs('ol', 'http://openlayers.org/context');

        # copy layer node from map wmc to output wmc
        foreach ( $mapxc->findnodes("/*/v:LayerList/v:Layer") ) { # find map layers

            # copy background map layer node to wmc
            #printf STDERR "\n*** copying map layer %s\n", $mapxc->findvalue('v:Name', $_);
            my $mpl = $_->cloneNode(1);
            $results->importNode($mpl);
            my $lname = $mapxc->findvalue('v:Name', $mpl);
            #next if $lname eq 'borders'; # fake - FIXME
            $newlayers->appendChild($mpl);
            # after lots of experimatation, this seems to be the only method that works

            foreach ( $mapxc->findnodes("v:SRS", $mpl) ) {
                $logger->debug( "*** deleting SRS for layer $lname: ", $_->textContent);
                $_->unbindNode;
            }

            foreach ( sort keys %{bgmapURLs()} ) {
                $logger->debug("*** adding SRS $_ to layer $lname");
                $mpl->appendTextChild( 'SRS' , $_ );
            }

            # set transparency based on layer name (false if baselayer)
            my $isoverlay = $lname eq 'borders' ? 'true' : 'false'; # met.no specific - FIXME
            $mpl->addNewChild( 'http://openlayers.org/context', 'ol:transparent' )->appendTextNode('false'); # $isoverlay

            #printf STDERR $mpl->serialize(1);

        }
    } else {
        $logger->warn("old_gen_wmc: No baselayer for " . $bbox{'crs'});
    }

    #print STDERR "\n\n------ WMC \n" . $results->toString(1);

    # TODO: remove non-universal SRS elements

    return $results;

}

#
# reproject bounding box
#

sub _reproject { # doesn't this do the same as calculate_bounds() ? FIXME

    my ($crs, $bbox) = @_;

    if ( defined $crs and $crs ne $$bbox{crs} ) {

        # stupid proj doesn't like upper case proj names
        my $to   = Geo::Proj4->new( init => lc($crs) )       or die Geo::Proj4->error . " for $crs";
        my $from = Geo::Proj4->new( init => lc($$bbox{crs}) ) or die Geo::Proj4->error;
        my @corners = (
            [ $$bbox{'left' }, $$bbox{'bottom'} ],
            [ $$bbox{'left' }, $$bbox{'top'   } ],
            [ $$bbox{'right'}, $$bbox{'bottom'} ],
            [ $$bbox{'right'}, $$bbox{'top'   } ],
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

        $$bbox{ crs    } = $crs;
        $$bbox{ left   } = min(@x);
        $$bbox{ right  } = max(@x);
        $$bbox{ bottom } = min(@y);
        $$bbox{ top    } = max(@y);

    }

    return $bbox;
}

#
# Download Capabilities and transform to WMC
#
sub _gen_wmc {
    my ($self, $wmsurl, $params) = @_;
    my $gcquery = 'service=WMS&version=1.3.0&request=GetCapabilities'; # can sometimes return 1.1.1
    my %stylesheets = (
        '1.3.0' => '/root/xsl/gc2wmc.xsl',
        '1.1.1' => '/root/xsl/gc111_2wmc.xsl'
    );
    $logger->warn("Rewrite _gen_wmc to sanitize $wmsurl");

    if ($wmsurl !~ /\?&/) {
        $wmsurl .= ($wmsurl =~ /\?/) ? '&' : '?'; # use WMS Utils sanitize_url instead
    }
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
    $logger->debug("WMS Capabilities version $version");

    my $stylesheet = $xslt->parse_stylesheet_file( $self->c->path_to( $stylesheets{$version} ) );
    $params = {} unless defined $params;
    $$params{debug} = 1 if $logger->is_debug();
    #print STDERR "_gen_wmc: ", Dumper $params;
    # generate wmc from capab
    my $wmcdoc = eval {
        $stylesheet->transform( $dom, XML::LibXSLT::xpath_to_string( %{$params} ) );
    } or die $@;

    $logger->debug( 'WMC: ', $wmcdoc->toString(1) );
    return $wmcdoc;

}

=head2 setup2wmc

Generate WMC directly from wmsinfo setup document (can merge several Capabilities docs)

=cut

sub setup2wmc {
    my ($self, $setup, $params) = @_;
    #print STDERR "setup2wmc", $setup->toString(1);

    my $xslt = XML::LibXSLT->new();

    my $stylesheet = $xslt->parse_stylesheet_file( $self->c->path_to( '/root/xsl/setup2wmc.xsl' ) );
    $params = {} unless defined $params;
    $$params{debug} = 1 if $logger->is_debug();
    #print STDERR "setup2wmc: ", Dumper $params;
    my $wmcdoc = eval {
        $stylesheet->transform( $setup, XML::LibXSLT::xpath_to_string( %{$params} ) );
    };
    croak " error: $@" if $@;

    return $wmcdoc;

}

=head2 calculate_bounds

Calculate a common bounding box for a set of layers on a given projection

=cut

sub calculate_bounds {
    my ($self, $areas, $newcrs) = @_;

    my (@x, @y); # coords of all points

    my $to = Geo::Proj4->new( init => lc($newcrs) ) # stupid proj doesn't like upper case proj names
        or die Geo::Proj4->error . " for $newcrs";
    #my $to = _newProj( $newcrs ); # obsolete

    foreach (@$areas) {
        $logger->debug("WMS: Transforming bounds from $_->{'crs'} to $newcrs");
        my $from = Geo::Proj4->new( init => lc($_->{'crs'}) ) or die Geo::Proj4->error;
        #my $from = _newProj( $_->{'crs'} ); # obsolete

        my @corners = ( # end points of bounding box
            [ $_->{'left' }, $_->{'bottom'} ],
            [ $_->{'left' }, $_->{'top'   } ],
            [ $_->{'right'}, $_->{'bottom'} ],
            [ $_->{'right'}, $_->{'top'   } ],
        );

        my @points;
        while (@corners) { # compute mid points between all corners
            my $p = shift @corners;
            push @points, $p;
            foreach (@corners) {
                my $x = ( $p->[0] + $_->[0] ) / 2;
                my $y = ( $p->[1] + $_->[1] ) / 2;
                #print STDERR "++++++ x=$x y=$y +++++++++++++\n";
                push @points, [$x, $y];
            }
        }

        # call proj transformation
        my $pr = $from->transform($to, \@points);
        #print STDERR Dumper \@points, $pr;

        # store all x's and y's so we later can find max and min
        foreach (@$pr) {
            push @x, $_->[0];
            push @y, $_->[1];
        }
    }

    my $setopts = {
        crs    => $newcrs,
        left   => min(@x),
        right  => max(@x),
        bottom => min(@y),
        top    => max(@y),
    };

    return $setopts;

}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
