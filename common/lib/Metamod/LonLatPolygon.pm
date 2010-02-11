#----------------------------------------------------------------------------
#  METAMOD - Web portal for metadata search and upload
#
#  Copyright (C) 2010 met.no
#
#  Contact information:
#  Norwegian Meteorological Institute
#  Box 43 Blindern
#  0313 OSLO
#  NORWAY
#  email: Heiko.Klein@met.no
#
#  This file is part of METAMOD
#
#  METAMOD is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  METAMOD is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with METAMOD; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#----------------------------------------------------------------------------
package Metamod::LonLatPolygon;

our $VERSION = do { my @r = (q$LastChangedRevision$ =~ /\d+/g); sprintf "0.%d", @r };

our $DEBUG = 0;

use strict;
use warnings;
use Metamod::LonLatPoint;

use overload "==" => \&equals,
             "!=" => sub {return !equals(@_)},
             '""' => \&toString;

sub new {
    my ($class, @points) = @_;
    @points = map {UNIVERSAL::isa($_, 'Metamod::LonLatPoint') ? $_ : Metamod::LonLatPoint->new(@$_)} @points;
    return unless @points;
    unless ($points[0] == $points[-1]) {
        push @points, $points[0];
    }
    # clean polygon for double occurance of same point
    my @cleanPoints = (shift @points);
    foreach my $p (@points) {
        if ($p != $cleanPoints[-1]) {
            push @cleanPoints, $p;
        }
    }
    
    return bless \@cleanPoints, $class;
}

sub getPoints {
    return @{$_[0]};
}

sub toString {
    return join ',', @{$_[0]};
}

sub toWKT {
    my ($self) = @_;
    if (@$self == 1) {
        return "POINT($self)";
    } else {
        return "POLYGON(($self))";
    }
}

sub toProjectablePolygon {
    my ($self) = @_;
    my $class = ref $self;
    my @points = @$self;
    my @outPoints;
    if (@points < 20) {
        # insert 3 extra point between each to point-pair
        # to avoid singularities during reprojection
        my $lastPoint = shift @points; 
        @outPoints = ($lastPoint);
        while (my $point = shift @points) {
            my ($lastLon, $lastLat) = $lastPoint->getLonLat;
            my ($pLon, $pLat) = $point->getLonLat;
            # mid-point
            my $mLon = ($pLon+$lastLon)/2;
            my $mLat = ($pLat+$lastLat)/2;
            # point between mid and left
            my $mlLon = ($pLon+$mLon)/2;
            my $mlLat = ($pLat+$mLat)/2;
            # point between mid and right
            my $mrLon = ($mLon+$lastLon)/2;
            my $mrLat = ($mLat+$lastLat)/2;
            push @outPoints, Metamod::LonLatPoint->new($mlLon,$mlLat);
            push @outPoints, Metamod::LonLatPoint->new($mLon,$mLat);
            push @outPoints, Metamod::LonLatPoint->new($mrLon,$mrLat);
            push @outPoints, $point;
            $lastPoint = $point;
        }
        return $class->new(@outPoints);
    } else {
        return $class->new(@$self);
    }
}

sub equals {
    my ($self, $other) = @_;
    if (UNIVERSAL::isa($other, __PACKAGE__)) {
        return $self->toString eq $other->toString;
    }
    return 1 == 0;
}

sub unique {
    my %uniq;
    return map {$uniq{$_->toString}++ ? () : ($_)} @_;
}

1;
__END__

=head1 NAME

Metamod::LonLatPolygon - container for polygons

=head1 SYNOPSIS

  my $polygon = new Metamod::LonLatPolygon([0,0],[0,1],[1,1],[1,0],[0,0]);
  my @points = $polygon->getPoints;
  print $polygon; # overloaded, see toString
  print $polygon->toString;
  
  my $otherPolygon = new Metamod::LonLatPolygon([0,0],[0,1],[1,1],[1,0],[0,0]);
  if ($polygon == $otherPolygon) { #overloaded, $polygon->equals($otherPolygon)
      # do it
  }
 
  my @uniqPolys = Metamod::LonLatPolygon::unique($polygon, $otherPolygon);
 
  # create a new polygon, save to project (avoid some singularities)
  my $newPoly = $polygon->toProjectablePolygon;
 
=head1 DESCRIPTION

This is a class for convenient storage of polygons. It stores internally all
points as L<Metamod::LonLatPoint>.

=head1 METHODS

=over 4

=item new($p1, $p2, $p3)

initialize the polygon by a list of points, either as L<Metamod::LonLatPoint>
or as arrayref of [lon, lat].

Return: object, or undef if no points
Dies on wrong points, i.e. outside range.

=item getPoints

return list of Metamod::LonLatPoint points

=item toString

return string representation of polygon, i.e. "LLPoint,LLPoint,LLPoint"

=item ""

overloaded, see toString

=item equals

compare if to polygons are obviously equal, i.e. have the same points in the same
order. It doesn't make a geometrical analysis, though.

=item ==

overloaded, see equals

=item !=

overloade, see !equals

=item toProjectablePolygon

return a polygon with some additional points to avoid 0-size polygons in case where
some points match singularities in other projections.

=back

=head1 AUTHOR

Heiko Klein, E<lt>H.Klein@met.noE<gt>

=head1 SEE ALSO

=cut