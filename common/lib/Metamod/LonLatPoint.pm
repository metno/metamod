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
package Metamod::LonLatPoint;

our $VERSION = do { my @r = (q$LastChangedRevision$ =~ /\d+/g); sprintf "0.%d", @r };

our $DEBUG = 0;
use constant DEC_ACCURACY => 2;
use constant FLOAT_ACCURACY => 10**(-1*DEC_ACCURACY);
use constant INT_CONVERSION_FACTOR => 10**(DEC_ACCURACY);
use constant NUMBER_FORMAT => '%.'.DEC_ACCURACY.'f';
use constant LONLAT_FORMAT => NUMBER_FORMAT . ' ' . NUMBER_FORMAT;

use strict;
use warnings;
use Carp qw(croak);

use overload "==" => \&equals,
             "!=" => sub {return !equals(@_)},
             '""' => \&toString;

sub new {
    my ($class, $lon, $lat) = @_;
    unless (defined $lat && defined $lon) {
        croak shift(@_)."::new requires (lon,lat), got(@_)";
    }
    unless (abs($lon) <= 180) {
        croak "longitude needs to be between -180 to 180, got $lon\n";
    } 
    unless (abs($lat) <= 90) {
        croak "latitude needs to be between -90 to 90, got $lon\n";
    }
    my @p = ($lon, $lat);
    return bless \@p, $class;
}

sub equals {
    my ($self, $other) = @_;
    if (defined $other) {
        return ((abs($self->[0]-$other->[0]) < FLOAT_ACCURACY) &&
                (abs($self->[1]-$other->[1]) < FLOAT_ACCURACY));        
    }
    return 0;
}

sub toString {
    return sprintf LONLAT_FORMAT, @{ $_[0] }; 
}

sub getLonLat {
    return @{ $_[0] };
}

sub unique {
    my %uniq;
    return map {$uniq{int($_->[0]*INT_CONVERSION_FACTOR+(($_->[0] > 0) ? .5 : -.5))}{int($_->[1]*INT_CONVERSION_FACTOR+(($_->[0] > 0) ? .5 : -.5))}++ ? () : ($_)} @_;
}

1;
__END__

=head1 NAME

Metamod::LonLatPoint - Container for longitude latitude points

=head1 SYNOPSIS

    my $ll = new Metamod::LonLatPoint($lon, $lat);
    print $ll; # overloaded to print $ll->toString
    
    my $otherLL = new Metamod::LonLatPoint($lon, $lat);
    if ($ll == $otherLL) {
        # points are equal (internally called $ll->equals($otherLL);
    }

    my ($lon, $lat) = $ll->getLonLat;

    my @uniquePoints = Metamod::LonLatPoint::unique($ll, $otherLL, $ll);

=head1 DESCRIPTION

This is a class for convenient storage of longitude/latitude points. It overloads == and ""
for transparent usage of points.

=head2 ACCURACY

All functions and printing use a .001 accuracy.

=head1 METHODS

=over 4

=item new($lon, $lat)

Return: object
Dies on missing $lon, $lot, or $lon/$lat out of range

=item getLonLat()

Return ($lon,$lat)

=item equals($rhs)

Return: true if lon and lat equal within accuracy

=item toString()

Return: "$lon $lat" in the desired accuracy

=back

=head1 FUNCTIONS

=over 4

=item unique(@list)

Create a unique list of LonLatPoints. All list items need to be LonLatPoints.

=back

=head1 AUTHOR

Heiko Klein, E<lt>H.Klein@met.noE<gt>

=head1 SEE ALSO

=cut

