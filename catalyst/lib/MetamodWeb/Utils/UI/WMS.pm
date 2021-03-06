package MetamodWeb::Utils::UI::WMS;

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


use Moose;
use namespace::autoclean;
use Metamod::WMS;
use Log::Log4perl qw(get_logger);
use Carp;
use Data::Dumper;
use Try::Tiny;

extends 'MetamodWeb::Utils::UI::Base';

=head1 NAME

MetamodWeb::Utils::XML::WMS - helper methods for WMS handling in UI

=head1 DESCRIPTION

blablabla

=cut

my $logger = get_logger(); # 'metamod.search.wms'

=head1 METHODS

=head2 wmscap($ds)

=over

=item return

Returns the GetCapabilities XML DOM for the dataset if it has any Wmsinfo. Returns undef otherwise.

=back

=cut

sub wmscap {
    my $self = shift;
    my $url = shift or return; # expecting $ds->wmsurl
    #die "Missing ? or & in WMS URL" unless $url =~ /[\?&]$/;

    #print STDERR "Getting WMS Capabilities at $url\n";
    $logger->debug("Getting WMS Capabilities at $url");
    my $capurl = $self->getcap_url($url) or return;
    my $cap = eval { getXML( $capurl ) };
    warn "WMS Capabilities error: $@" if $@;
    $logger->error("WMS Capabilities at $url failed: $@") if $@;
    return $cap;
}


=head2 wmsthumb($ds)

=over

=item return

Returns hash with URLs to WMS thumbnail based on wmsinfo setup.

Make sure to check if wmsinfo exist before calling this method.

=back

=cut

sub wmsthumb {
    my $self = shift;
    my $ds = shift;
    my ($size) = @_;

    # this method needs some serious rework, including
    # - find a better procedure for calculating timestamps
    # - remove hardcoded LAYER borders

    try {
        my $config = Metamod::Config->instance();

        my $setup = $ds->wmsinfo or die "Error: Missing wmsSetup for dataset " . $ds->ds_name;

        #printf STDERR "* Setup (%s) = %s\n", ref $setup, $setup->toString;
        my $sxc = XML::LibXML::XPathContext->new( $setup->documentElement() );
        $sxc->registerNs('s', "http://www.met.no/schema/metamod/ncWmsSetup");

        my (%area, %layer);

        # find base WMS URL from wmsurl (NOT wmsinfo!)
        my $wms_url = $ds->wmsurl or return;
        my ($thumbnail) = $sxc->findnodes('/*/s:thumbnail'); # TODO - support multiple thumbs (map + data) - FIXME

        # use first layer found if not specified
        foreach ( $thumbnail ? $sxc->findnodes('/*/s:thumbnail[1]/@*') : $sxc->findnodes('/*/s:layer[1]/@*') ) {
            $layer{$_->nodeName} = $_->getValue;
        }
        $layer{style} = ''       unless exists $layer{style};
        $layer{url}   = $wms_url unless exists $layer{url};
        $layer{url}  .= '?'      unless $layer{url} =~ /\?/;

        #print STDERR "*******************************\n" . Dumper \%layer;

        # find area info (dimensions, projection)
        foreach ( $sxc->findnodes('/*/s:displayArea[1]/@*') ) {
            $area{$_->nodeName} = $_->getValue;
        }

        # build WMS params for maps
        my @t = gmtime(time); my ($year, $day, $month, $hour) = ($t[5]+1900, $t[3], $t[4]+1, $t[2]+1); # HACK HACK HACK
        my $time = $layer{time}; # || "[yyyy]-[mm]-[dd]T[hh]:00"; # too simplistic to work...
        #$time =~ s|\[yyyy\]|$year|g;
        #$time =~ s|\[mm\]|$month|g;
        #$time =~ s|\[dd\]|$day|g;
        #$time =~ s|\[hh\]|$hour|g;
        #print STDERR Dumper \$time;
        my $wmsparams = "SERVICE=WMS&REQUEST=GetMap&VERSION=1.1.1&FORMAT=image%2Fpng"
            . "&SRS=$area{crs}&BBOX=$area{left},$area{bottom},$area{right},$area{top}&WIDTH=$size&HEIGHT=$size"
            . "&EXCEPTIONS=application%2Fvnd.ogc.se_inimage"
            . ($time ? "&TIME=$time" : '');

        # get map url's according to projection
        my $mapurl = getMapURL( $area{crs} );

        #print STDERR Dumper($wms_url, \%area, \%layer, \$mapurl); #$metadata

        my $out = {
            xysize  => $size,
            datamap => "$layer{url}$wmsparams&LAYERS=$layer{name}&STYLES=$layer{style}",
            outline => $mapurl ? "${mapurl}$wmsparams&TRANSPARENT=true&LAYERS=borders&STYLES=" : undef, # FIXME remove hardcoded LAYERS
            wms_url => $wms_url,
        };

        #print STDERR Dumper($out);

        return $out;

    } catch {
        carp $_; # use logger - FIXME
        return;
    }
}

=head2 sanitize_wmsurl($url)

Make sure $url ends in either '?' or '&' as defined in spec

=cut

sub sanitize_wmsurl {
    my $self = shift;
    my $url = shift or die "Missing parameter";
    die "UGLY HACK URL is not allowed here" if $url =~ /%(THREDDS_|UGLY_HACK)/;
    return $url if $url =~ /\?&$/;              # ok if ends with ? or &
    return ($url =~ /\?/) ? "$url&" : "$url?";  # else add whatever is needed
}

=head2 getcap_url($url)

Construct GetCapabilities URL

=cut

sub getcap_url {
    my $self = shift;
    my $url = shift or confess "Missing parameter";
    $url = try {
        $self->sanitize_wmsurl($url);
    } catch {
        $logger->error($_);
        return;
    };
    my $config = Metamod::Config->instance();
    return $url . $config->get('WMS_GET_CAPABILITIES');
}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
