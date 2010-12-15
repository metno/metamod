package MetamodWeb::Controller::Map;

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

use Data::Dump qw( dump );

use Imager;
use Imager::Fill;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

MetamodWeb::Controller::Map - Controller for displaying the maps.

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


sub map :Path('/search/map') :Args(1) {
    my ( $self, $c ) = @_;

    my $filetype = 'png';

    my $ui_utils = $c->stash->{ ui_utils };
    my $x1 = $c->req->params->{ x1 };
    my $x2 = $c->req->params->{ x2 };
    my $y1 = $c->req->params->{ y1 };
    my $y2 = $c->req->params->{ y2 };

    $c->log->debug("Coordinates: ($x1,$y1) ($x2,$y2)");

    my $image_srid = $c->req->args->[0];

    # The user has not set any points so there is no reason to get the additional overhead
    # of using Imager. Read the image bytes and serve them.
    if( !$x1 && !$y1 ){

        open my $IMAGE, '<', $c->path_to("/root/static/images/map_$image_srid.png") or die $!;
        my $image_bytes = do { local $/; <$IMAGE> };

        $c->response->content_type('image/png');
        $c->response->body($image_bytes);
        return;
    }

    my $image = Imager->new();
    $image->read( file => $c->path_to("/root/static/images/map_$image_srid.png") ) or die $image->errstr();

    # have only the first x,y pair so mark it on the map.
    if( $x1 && $y1 && !( $x2 && $y2 ) ){
        my $black = Imager::Color->new( 0, 0, 0 );
        $image->box( color => $black, xmin => $x1, ymin => $y1, xmax => $x1 + 5, ymax => $y1 + 5, filled => 1 );
    } elsif( $x1 && $y1 && $x2 && $y2 ){

        if( $x1 > $x2 ){
            my $tmp = $x1;
            $x1 = $x2;
            $x2 = $tmp;
        }

        if( $y1 > $y2 ){
            my $tmp = $y1;
            $y1 = $y2;
            $y2 = $tmp;
        }

        my $fill_color = Imager::Color->new( 0, 0, 100, 30 );
        my $fill = Imager::Fill->new( solid => $fill_color, combine => 'normal' );
        my $outline_color = Imager::Color->new( 0, 0, 180 );
        $image->box( xmin => $x1, ymin => $y1, xmax => $x2, ymax => $y2, fill => $fill  );
        $image->box( xmin => $x1, ymin => $y1, xmax => $x2, ymax => $y2, color => $outline_color  );
    }



    my $image_bytes;
    $image->write( data => \$image_bytes, type => $filetype );

    $c->response->content_type('image/png');
    $c->response->body($image_bytes);


}

__PACKAGE__->meta->make_immutable;

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
