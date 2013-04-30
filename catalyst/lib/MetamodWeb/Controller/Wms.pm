package MetamodWeb::Controller::Wms;

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

=head1 NAME

MetamodWeb::Controller::Wms - Catalyst controller for WMS functions

=head1 DESCRIPTION

This is the backend for making the WMS client (OpenLayers) work with METAMOD.
Main function is to supply a proxy to bypass JavaScript security restrictions
in reading WMS GetCapabilities from an external server (THREDDS). Secondly it
translates the GetCapabilities document along with METAMOD metadata into
WMC (Web Map Context) format.

=cut

use Moose;
use namespace::autoclean;
use Data::Dumper;
use Try::Tiny;
use List::Util qw(min max sum);
use XML::LibXML;
use MetamodWeb::Utils::XML::Generator;
use MetamodWeb::Utils::XML::WMC;
use Metamod::WMS;
use Geo::Proj4;

BEGIN { extends 'MetamodWeb::BaseController::Base'; }


sub auto :Private {
    my ( $self, $c ) = @_;

    $c->stash( wmc => MetamodWeb::Utils::XML::WMC->new( { c => $c } ));
}

=head1 METHODS

=head2 gc2wmc

This returns a WMC document describing layers and dimensions for the WMS client.
Parameters are one of the following:

=head3 ds_id

Numerical id of the dataset to be projected. This is only applicable to datasets
having a wmsinfo setup in the datbase.

=head3 wmssetup

URL to wmsinfo setup document. Currently deprecated.

=head3 getcap

URL to GetCapabilites document on WMS server (w/o query string).

=cut

sub gc2wmc :Path("/gc2wmc") :Args(0) {
    my ( $self, $c ) = @_;

    my $p = $c->request->params;
    my ($setup, $wms);

    if ( $$p{ds_id} ) {

        # lookup setup doc directly from db
        my $ds_id = ref($$p{ds_id}) eq 'ARRAY' ? $$p{ds_id}[0] : $$p{ds_id};
        #printf STDERR "Fetching setup for dataset %s...\n", $ds_id;

        if( my $ds = $c->model('Metabase')->resultset('Dataset')->find($ds_id) ){
            $setup = $ds->wmsinfo;
            $wms   = $ds->wmsurl;
        }
        $c->detach( 'Root', 'error', [ 400, "Missing wms setup for dataset $ds_id" ] )
            unless defined($setup) && defined($wms);

    } elsif ( $$p{getcap} ) {

        $c->detach( 'Root', 'error', [ 400, "Missing crs param" ] ) unless defined($$p{crs});
        $self->logger->debug("Fetching GetCap at " . $$p{getcap});
        #printf STDERR " * URL = %s\n", $c->request->uri;
        $wms = $$p{getcap};
        $setup = defaultWMC({ crs => $$p{crs} });

    } else {

        $c->detach( 'Root', 'error', [ 400, "Missing parameters in request" ] );

    }

    # TODO - add better handling for timeout errors... FIXME

    my $wmc = eval { $c->stash->{wmc}->old_gen_wmc($setup, $wms, $$p{crs}) }; # TODO rewrite to use setup2wmc instead - FIXME
    if ($@) {
        $self->logger->warn("old_gen_wmc failed: $@");
        $c->detach( 'Root', 'error', [ 502, $@ ] );
    } else {
        my $out = $wmc->toString(1);
        #print STDERR $out;
        # another hack to work around inexplainable duplicate namespace bug
        $out =~ s|( xmlns:xlink="http://www.w3.org/1999/xlink"){2}|$1|g;
        $c->response->content_type('text/xml');
        $c->response->body( $out );
    }

}

=head2 multiwmc

This returns a WMC document containing layers from different datasets.

Parameters:

=head3 layer_nnn

where nnn is the ds_id and value is the WMS Name of the layer. Repeated for each layer

=head3 crs

projection for the map tiles

=head3 left
=head3 top
=head3 right
=head3 bottom

Bounding box coordinates as in the given projection

=cut

sub multiwmc :Path("/multiwmc") :Args(0) {
    my ( $self, $c ) = @_;

    my $mm_config = $c->stash->{ mm_config };
    my $para = $c->request->params;
    #print STDERR Dumper $para;
    my $crs = $$para{'crs'} && delete $$para{'crs'};
    $c->detach( 'Root', 'error', [ 400, "Missing parameter 'crs' in request" ] ) unless defined($crs);

    #my $foo = eval { $c->stash->{wmc}->old_gen_wmc($setup, $wms, $crs) };

    # move processing stuff below to MetamodWeb::Utils::XML::WMC ... FIXME
    my (%wmsurls, %layers, @nodes, @areas);
    my $nsURI = 'http://www.met.no/schema/metamod/ncWmsSetup';

    foreach (keys %$para) {
        next unless my ($base, $ds_id) = /^(base)?layer_(\d+)$/;
        $base ||= '';

        my $url;
        my $layers = ref($$para{$_}) eq 'ARRAY' ? $$para{$_} : [ $$para{$_} ]; # make array if single

        if( my $ds = $c->model('Metabase')->resultset('Dataset')->find( $ds_id ) ){
            $url = $ds->wmsurl;
            # store away bounding box areas
            my ($anode) = $ds->wmsinfo->getElementsByLocalName('displayArea');
            my $area = {};
            map { $$area{$_} = $anode->getAttribute($_); } qw(crs left right bottom top);
            push @areas, $area;
        }

        #print STDERR ">>> ${base}layer $ds_id - $url\n";
        $c->detach( 'Root', 'error', [ 400, "Undefined WMS URL for dataset $ds_id" ] ) unless defined($url);

        # store layernodes away for later
        foreach (@$layers) {
            my $layernode = XML::LibXML::Element->new( "${base}layer" );
            $layernode->setNamespace( $nsURI );
            $layernode->setAttribute( 'url', $url );
            $layernode->setAttribute( 'name', $_ );
            push @nodes, $layernode;
        }
    }

    #print STDERR Dumper \@areas;

    my $setopts = $self->_calculate_bounds(\@areas, $crs);
    $$setopts{time} = $$para{'time'};

    my $setup = defaultWMC($setopts);

    my $root = $setup->documentElement;
    foreach (@nodes) {
        $root->appendChild($_);
    }

    #print STDERR $setup->toString(2);

    my $wmc = eval { $c->stash->{wmc}->setup2wmc($setup) };
    #$wmc->documentElement->appendChild($setup->documentElement); # uh, why? for debug?
    die " error: $@" if $@;
    my $out = $wmc->toString(1);
    # another hack to work around inexplainable duplicate namespace bug
    $out =~ s|( xmlns:xlink="http://www.w3.org/1999/xlink"){2}|$1|g;
    $c->response->content_type('text/xml');
    $c->response->body( $out );

    #print STDERR "-------------------\n$out\n---------------------------\n";

}

sub _calculate_bounds {
    my ($self, $areas, $newcrs) = @_;

    my (@x, @y); # coords of all points

    my $to = Geo::Proj4->new( init => lc($newcrs) ) # stupid proj doesn't like upper case proj names
        or die Geo::Proj4->error . " for $newcrs";
    #my $to = _newProj( $newcrs ); # obsolete

    foreach (@$areas) {
        $self->logger->debug("WMS: Transforming bounds from $_->{'crs'} to $newcrs");
        my $from = Geo::Proj4->new( init => lc($_->{'crs'}) ) or die Geo::Proj4->error;
        #my $from = _newProj( $_->{'crs'} ); # obsolete

        my @corners = ( # end points of bounding box
            [ $_->{'left' }, $_->{'bottom'} ],
            [ $_->{'left' }, $_->{'top'   } ],
            [ $_->{'right'}, $_->{'bottom'} ],
            [ $_->{'right'}, $_->{'top'   } ],
        );

        my @points;
        while (@corners) { # compute mid points between each corner
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

    #print STDERR 'x = ' . Dumper \@x;
    #print STDERR 'y = ' . Dumper \@y;

    #my ($left, $right, $top, $bottom);

    my $setopts = {
        crs    => $newcrs,
        left   => min(@x),
        right  => max(@x),
        bottom => min(@y),
        top    => max(@y),
    };

    #print STDERR "setopts = " . Dumper $setopts;

    return $setopts;

}

# _newProj - some old stuff that were never used
#
#sub _newProj {  # obsolete
#    my $crs = lc(shift) or die;
#    if ($crs eq 'crs:84') {
#        return Geo::Proj4->new( '+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs' )
#            or die Geo::Proj4->error . " for CRS:84";
#    } else {
#        return Geo::Proj4->new( init => $crs )
#            or die Geo::Proj4->error . " for $crs";
#    }
#    #return ($crs eq 'crs:84') ?
#    #    Geo::Proj4->new( '+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs' ) :
#    #    Geo::Proj4->new( init => $crs )
#    #or die Geo::Proj4->error . " for $crs";
#}


=head2 qtips

Helper feature which reads query string and outputs arguments as XML.
Used only for debugging.

=cut

sub qtips :Path("/qtips") :Args(0) {
    my ( $self, $c ) = @_;

    my $dom = new MetamodWeb::Utils::XML::Generator;
    my (@params, %attr);

    $attr{method} = $c->request->method;

    my $p = $c->request->params;
    foreach (sort keys %$p) {
        # Dump $$p{$_};
        if (ref $$p{$_}) {
            #printf STDERR " ++ %s = [%s]\n", $_, join('|', @{$$p{$_}});
            for my $v (@{$$p{$_}}) {
                push @params, $dom->tag($_, $v);
            }
        } else {
            #printf STDERR " -- %s = '%s'\n", $_, $$p{$_};
            push @params, $dom->tag($_, $$p{$_});
        }
    }
    #print STDERR $c->request->query_keywords || '-' . "\n";

    $dom->setDocumentElement(
        $dom->tag('request', \%attr, \@params )
    );

    $c->response->content_type('text/xml');
    $c->response->body( $dom->toString );
}

sub error {
    my ($c, $status, $message) = @_;
    $c->response->status($status);
    $c->response->body( $message );
}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

__PACKAGE__->meta->make_immutable;
