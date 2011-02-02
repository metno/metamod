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

use Try::Tiny;
use XML::LibXML;
use MetamodWeb::Utils::XML::Generator;
use MetamodWeb::Utils::XML::WMC;
use Metamod::WMS;

BEGIN { extends 'Catalyst::Controller'; }


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
        } else {
            $c->detach( 'Root', 'default' );
        }

    #} elsif ( $$p{wmssetup} ) {
    #    # fetch setup doc via HTTP... DEPRECATED (until told otherwise)
    #    printf STDERR "Fetching %s...\n", $$p{wmssetup};
    #
    #    try { # not really tested... doesn't work unless running preforking catalyst
    #        $setup = getXML( $c->request->params->{wmssetup} );
    #    } catch {
    #        error($c, 502, $_);
    #        return;
    #    }

    } elsif ( $$p{getcap} ) {
        # fetch GetCapabilites directly (for files w/o setup docs)
        printf STDERR "Fetching GetCap at %s...\n", $$p{getcap};
        printf STDERR " * URL = %s\n", $c->request->uri;
        $wms = $$p{getcap};
        $setup = defaultWMC();
        #printf STDERR "Default WMC = \n%s\n", $setup->toString;
    }

    my $wmc = eval { $c->stash->{wmc}->setup2wmc($setup, $wms) };
    if ($@) {
        printf STDERR "setup2wmc failed: %s\n", $@;
        error($c, 502, $@);
    } else {
        my $out = $wmc->toString;
        # another hack to work around inexplainable duplicate namespace bug
        $out =~ s|( xmlns:xlink="http://www.w3.org/1999/xlink"){2}|$1|g;
        $c->response->content_type('text/xml');
        $c->response->body( $out );
    }

}

=head2 qtips

Helper feature which reads query string and outputs arguments as XML.
Used only for debugging.

=cut

sub qtips :Path("/qtips") :Args(0) {
    my ( $self, $c ) = @_;

    my $dom = new MetamodWeb::Utils::XML::Generator;
    my @params;

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
    print STDERR $c->request->query_keywords || '-' . "\n";

    $dom->setDocumentElement(
        $dom->tag('request', \@params )
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
