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
use XML::LibXML;
use MetamodWeb::Utils::XML::Generator;
use MetamodWeb::Utils::XML::WMC;
use Metamod::WMS;

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
        #printf STDERR "Fetching setup for dataset %s...\n", $$p{ds_id}[0];

        if( my $ds = $c->model('Metabase')->resultset('Dataset')->find( $$p{ds_id} ) ){
            $setup = $ds->wmsinfo;
        }
        $c->detach( 'Root', 'default' ) unless defined($setup);

    } elsif ( $$p{getcap} ) {
        # fetch GetCapabilites directly (for files w/o setup docs)
        $self->logger->debug("Fetching GetCap at " . $$p{getcap});
        #printf STDERR " * URL = %s\n", $c->request->uri;
        $wms = $$p{getcap};
        $setup = defaultWMC();
    }

    my $wmc = eval { $c->stash->{wmc}->old_gen_wmc($setup, $wms) };
    if ($@) {
        $self->logger->warn("old_gen_wmc failed: $@");
        error($c, 502, $@);
    } else {
        my $out = $wmc->toString;
        # another hack to work around inexplainable duplicate namespace bug
        $out =~ s|( xmlns:xlink="http://www.w3.org/1999/xlink"){2}|$1|g;
        $c->response->content_type('text/xml');
        $c->response->body( $out );
    }

}


sub multiwmc :Path("/multiwmc") :Args(0) {
    my ( $self, $c ) = @_;

    my $mm_config = $c->stash->{ mm_config };
    #my $bgurl = $mm_config->get('WMS_BACKGROUND_MAPSERVER');
    #my bgmaps = (
    #    '' => $bgurl . $mm_config->get('WMS_NORTHPOLE_MAP'),
    #    '' => $bgurl . $mm_config->get('WMS_SOUTHPOLE_MAP'),
    #    '' => $bgurl . $mm_config->get('WMS_WORLD_MAP'),
    #);

    my $para = $c->request->params;
    my (%wmsurls, %layers);

    my $setup = defaultWMC($para);
    my $root = $setup->documentElement;
    my $nsURI = 'http://www.met.no/schema/metamod/ncWmsSetup';

    foreach (keys %$para) {
        next unless my ($ds_id) = /^layer_(\d+)$/;

        my $url;
        my $layers = ref($$para{$_}) eq 'ARRAY' ? $$para{$_} : [ $$para{$_} ];
        if( my $ds = $c->model('Metabase')->resultset('Dataset')->find( $ds_id ) ){
            $url = $ds->wmsinfo->findvalue('/*/@url');
        }
        $c->detach( 'Root', 'default' ) unless defined($url);
        #print STDERR ">>> $ds_id - $url\n";

        foreach (@$layers) {
            my $layernode = $root->addNewChild( $nsURI, 'layer');
            $layernode->setAttribute( 'url', $url );
            $layernode->setAttribute( 'name', $_);
        }
    }

    my $wmc = eval { $c->stash->{wmc}->setup2wmc($setup) };
    $wmc->documentElement->appendChild($setup->documentElement);
    die " error: $@" if $@;
    my $out = $wmc->toString(1);
    # another hack to work around inexplainable duplicate namespace bug
    $out =~ s|( xmlns:xlink="http://www.w3.org/1999/xlink"){2}|$1|g;
    $c->response->content_type('text/xml');
    $c->response->body( $out );

}

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
    $c->response->body( "Server Error: " . $message );
}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

__PACKAGE__->meta->make_immutable;
