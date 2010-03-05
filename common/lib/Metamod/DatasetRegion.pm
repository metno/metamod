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
package Metamod::DatasetRegion;

our $VERSION = do { my @r = (q$LastChangedRevision$ =~ /\d+/g); sprintf "0.%d", @r };

our $DEBUG = 0;

use strict;
use warnings;
use Carp qw(croak);
use Hash::Util;
use XML::LibXML;
use XML::LibXML::XPathContext;
use Metamod::LonLatPoint;
use Metamod::LonLatPolygon;

use constant NAMESPACE_DSR => 'http://www.met.no/schema/metamod/datasetRegion';
use constant MAX_POINTS => 200_000;
use constant MAX_STRING => MAX_POINTS * 10;

my $Parser = new XML::LibXML();
my $Xpc = XML::LibXML::XPathContext->new();
$Xpc->registerNs('d', __PACKAGE__->NAMESPACE_DSR);

sub new {
    my ($class, $xmlStr) = @_;
    my $self = {
        polygons => [],
        points => [],
        boundingBox => {},
        valid => 1,
    };
    bless $self, $class;
    Hash::Util::lock_keys(%$self);
    $self->addXML($xmlStr);
    return $self;
}

sub getBoundingBox {
    return %{ $_[0]->{boundingBox} };
}

sub overlapsBoundingBox {
    my ($self, $bbRef) = @_;
    unless (ref($bbRef) eq 'HASH') {
        croak('need hash reference for withinBoundingBox(\%bbRef)');
    }
    unless (defined $bbRef->{south} and defined $bbRef->{north}
            and defined $bbRef->{east} and defined $bbRef->{west}) {
        croak("need south east north west elements for bounding-box in reference to withinBoundingBox, got ".keys %$bbRef);
    }

    my %boundingBox = $self->getBoundingBox; 
    if (exists $boundingBox{north} and $boundingBox{north} < $bbRef->{south}) {
        return 0;
    }
    if (exists $boundingBox{south} and $boundingBox{south} > $bbRef->{north}) {
        return 0;
    }
    if (exists $boundingBox{east} and $boundingBox{east} < $bbRef->{west}) {
        return 0;
    }
    if (exists $boundingBox{west} and $boundingBox{west} > $bbRef->{east}) {
        return 0;
    }
    
    return 1;
}

sub valid {
    return $_[0]->{valid};
}

sub setInvalid {
    my ($self) = @_;
    $self->{valid} = 0;
    $self->{points} = [];
    $self->{polygons} = [];
}

sub getPoints {
    return @{ $_[0]->{points} };
}

sub getPolygons {
    return @{ $_[0]->{polygons} };
}

sub extendBoundingBox {
    my ($self, $bb) = @_;
    if ($bb and scalar keys %$bb > 0) {
        if ((!exists $bb->{north}) or abs($bb->{north}) > 90) {
            croak "extendBoundingBox requires boundingBox{north} to be within -90 to 90, got: ".$bb->{north};
        }
        if ((!exists $bb->{south}) or abs($bb->{south}) > 90) {
            croak "extendBoundingBox requires boundingBox{south} to be within -90 to 90, got: ".$bb->{south};
        }
        if ((!exists $bb->{east}) or abs($bb->{east}) > 180) {
            croak "extendBoundingBox requires boundingBox{east} to be within -180 to 180, got: ".$bb->{east};
        }
        if ((!exists $bb->{west}) or abs($bb->{west}) > 180) {
            croak "extendBoundingBox requires boundingBox{west} to be within -180 to 180, got: ".$bb->{west};
        }
        if (!$self->{boundingBox} or (scalar keys %{ $self->{boundingBox} } == 0)) {
            my %bb = %$bb; # real copy
            Hash::Util::lock_keys(%bb);
            $self->{boundingBox} = \%bb;
        } else {
            foreach my $dir (qw(north east)) {
                # largest value
                if ($self->{boundingBox}{$dir} < $bb->{$dir}) {
                    $self->{boundingBox}{$dir} = $bb->{$dir};
                }   
            }
            foreach my $dir (qw(south west)) {
                # smallest value
                if ($self->{boundingBox}{$dir} > $bb->{$dir}) {
                    $self->{boundingBox}{$dir} = $bb->{$dir};
                }   
            }
        }
    }
}

sub addPoint {
    my ($self, $point, $latVal) = @_;
    return unless $self->valid;
    if (defined $point) {
        if (!ref $point) {
            if (defined $latVal) {
                # $point is $lonVal
                push @{ $self->{points} }, new Metamod::LonLatPoint($point, $latVal);
            } else {
                croak ("wrong parameters to addPoint: @_\n");
            }
        } elsif (UNIVERSAL::isa($point,'Metamod::LonLatPoint')) {
            push @{ $self->{points} }, $point;
        } elsif (UNIVERSAL::isa($point,'ARRAY')) {
            push @{ $self->{points} }, new Metamod::LonLatPoint(@$point);
        } else {
            croak shift(@_)."::addPoint(@_) wrong arguments";
        } 
        if (scalar @{ $self->{points} } > MAX_POINTS) {
            $self->setInvalid;
        }
    }
}

# make sure all points are unique 
sub uniquePoints {
    my $self = shift;
    @{ $self->{points} } = Metamod::LonLatPoint::unique(@{ $self->{points} });
}


sub addPolygon {
    my ($self, @polygon) = @_;
    return unless $self->valid;
    my $poly;
    if (UNIVERSAL::isa($polygon[0], 'Metamod::LonLatPolygon')) {
        $poly = $polygon[0];
    } elsif (UNIVERSAL::isa($polygon[0], 'ARRAY')) {
        $poly = new Metamod::LonLatPolygon(@{$polygon[0]});
    } else {
        $poly = new Metamod::LonLatPolygon(@polygon);
    }
    if ($poly) {
        push @{ $self->{polygons} }, $poly;
    }
}

sub addRegion {
    my ($self, $other) = @_;
    return unless $other;
    if (UNIVERSAL::isa($other, __PACKAGE__)) {
        $self->extendBoundingBox($other->{boundingBox});
        if ($other->valid) {
            if ($self->valid) {
                push @{ $self->{points} }, $other->getPoints();
                $self->uniquePoints;
                push @{ $self->{polygons} }, $other->getPolygons();
                $self->uniquePolygons;
            }
        } else {
            $self->setInvalid;
        }
    } else {
        croak "addRegion requires DatasetRegion as argument, got $other\n";
    }
}

# make sure all polygons are unique
sub uniquePolygons {
    my $self = shift;
    @{ $self->{polygons} } =  Metamod::LonLatPolygon::unique(@{ $self->{polygons} });
}

sub addXML {
    my ($self, $xml) = @_;
    return unless $xml;
    my $doc;
    if (UNIVERSAL::isa($xml, 'XML::LibXML::Node')) {
        my @datasetRegions = $Xpc->findnodes('//d:datasetRegion', $xml);
        return unless @datasetRegions;
        $doc = new XML::LibXML::Document('1.0', 'UTF-8');
        $doc->setDocumentElement($datasetRegions[0]->cloneNode(1));
    } else {
        $doc = $Parser->parse_string($xml);
        # TODO: validate?    
    }

    # valid, defaults to true
    my ($valid) = $Xpc->findnodes('/d:datasetRegion/@isValid', $doc);
    if ($valid) {
        my $str = $valid->getValue();
        if (lc($str) eq "false") {
            $self->setInvalid;
        }
    }

    # boundingBox
    my ($bbNode) = $Xpc->findnodes('/d:datasetRegion/d:boundingBox', $doc);
    if ($bbNode) {
        my %bb;
        foreach my $attr ($bbNode->attributes) {
            $bb{$attr->name} = $attr->value;
        }
        $self->extendBoundingBox(\%bb);
    }
    
    # nothing needs to be done with points/polygons if dataset invalid
    return if not $self->valid;
    
    # points
    my ($pointNode) = $Xpc->findnodes('/d:datasetRegion/d:lonLatPoints', $doc);
    if ($pointNode) {
        my $pointTxt = "";
        foreach my $child ($pointNode->childNodes) {
            $pointTxt .= $child->nodeValue if $child->nodeType == XML::LibXML::XML_TEXT_NODE;
        }
        if (length($pointTxt) < MAX_STRING) {
            my @points = split /\s*,\s*/, $pointTxt;
            while (defined (my $p = shift @points)) {
                my ($lon, $lat) = split ' ', $p;
                $self->addPoint([$lon,$lat]);
            }
        } else {
            $self->setInvalid;
        }
    }
    
    # polygons
    foreach my $polyNode ($Xpc->findnodes('/d:datasetRegion/d:lonLatPolygon', $doc)) {
        my $polyTxt = "";
        if (length($polyTxt) < MAX_STRING) {
            foreach my $child ($polyNode->childNodes) {
                $polyTxt = $child->nodeValue if $child->nodeType == XML::LibXML::XML_TEXT_NODE;
            }
            my @polygon = split /\s*,\s*/, $polyTxt;
            @polygon = map {[split ' ', $_]} @polygon;
            $self->addPolygon(\@polygon);
        } else {
            $self->setInvalid;
        }
    }
}

sub toNode {
    my $self = shift;
    return $Parser->parse_string($self->toString);
}

sub toString {
    my $self = shift;
    my $valid = $self->valid ? "true" : "false";
    my $xml = <<"EOT";
<?xml version="1.0" encoding="utf-8" ?>
<datasetRegion isValid="$valid"
   xmlns="http://www.met.no/schema/metamod/datasetRegion"
   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
   xsi:schemaLocation="http://www.met.no/schema/metamod/datasetRegion https://wiki.met.no/_media/metamod/datasetRegion.xsd">
EOT
    # <boundingBox /> <!-- exactly once, with attr north south east west -->
    if (scalar keys %{$self->{boundingBox}} > 0) {
        my %bb = %{ $self->{boundingBox} };
        $xml .= sprintf "  <boundingBox north=\"".Metamod::LonLatPoint::NUMBER_FORMAT."\" south=\"".Metamod::LonLatPoint::NUMBER_FORMAT."\" east=\"".Metamod::LonLatPoint::NUMBER_FORMAT."\" west=\"".Metamod::LonLatPoint::NUMBER_FORMAT."\" />\n", @bb{qw(north south east west)};
    } else {
        $xml .= '  <boundingBox />'."\n";
    }
    #<lonLatPoints /> <!-- exaclty once text -->
    if ($self->valid and scalar @{ $self->{points} }) {
        $xml .= '  <lonLatPoints>'."\n";
        $xml .= '  '.join(',', @{$self->{points}});
        $xml .= "\n".'  </lonLatPoints>'."\n";
    } else {
        $xml .= '  <lonLatPoints />'."\n";
    }
    # <lonLatPolygon> occurance 0..n
    if ($self->valid) {
        foreach my $pol (@{ $self->{polygons} }) {
            $xml .= "  <lonLatPolygon>\n";
            $xml .= "  $pol";
            $xml .= "\n  </lonLatPolygon>\n";
        }
    }
    $xml .= '</datasetRegion>'."\n";
    return $xml;    
}

sub equals {
    my ($self, $other) = @_;
    my %sbb = $self->getBoundingBox;
    my %obb = $other->getBoundingBox;
    while (my ($dir, $v) = each %sbb) {
        if (abs($v - $obb{$dir}) > Metamod::LonLatPoint::FLOAT_ACCURACY) {
            return 0;
        }        
    }
    my @sPoints = sort map {"$_"} Metamod::LonLatPoint::unique($self->getPoints);
    my @oPoints = sort map {"$_"} Metamod::LonLatPoint::unique($other->getPoints);
    if (@sPoints != @oPoints) {
        return 0;
    }
    while (@sPoints) {
        if (shift @sPoints ne shift @oPoints) {
            return 0;
        }
    }
    
    my %sPolygons = map {("$_" => 1)} $self->getPolygons;
    my %oPolygons = map {("$_" => 1)} $other->getPolygons;
    if (scalar keys %sPolygons != scalar keys %oPolygons) {
        return 0;
    }
    foreach my $p (keys %sPolygons) {
        if (!exists $oPolygons{$p}) {
            return 0;
        }
    }
    return 1;
}

1;
__END__

=head1 NAME

Metamod::DatasetRegion - Describe geographical regions of datasets

=head1 SYNOPSIS

 # create the object (with an optional $xmlString)
 my $region = new Metamod::DatasetRegion([$xmlString]);
 
 # retrieve information
 my @polygons = $region->getPolygons(); # ([[lon1,lat1],[lon2,lat2],...,[lon1,lat1]], [[same for polygon2]])
 my @points = $region->getPoints();     # ([lon1,lat1],[lon2,lat2]...)
 my %bb = $region->getBoundingBox();    # $bb{north} $bb{south} $bb{east} $bb{west}
 
 # add information (extending existing information
 $region->addPolygon([[lon1,lat1],[lon2,lat2], ..., [lon1, lat1]]);
 $region->addPoint([lon1,lat1]);
 $region->extendBoundingBox(\%bb);
 $region->addXML();
 
 # remove duplicates in the region
 $region->uniquePoints;
 $region->uniquePolygons;
 
 # convert to xml-representation
 my $xmlStr = $region->toString;

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item new([$xml])

Create a new object, optionally initializing it by a xml-string or a XML::LibXML::Node.

Return: object
Dies on invalid xml

=item valid

A region is assumed to be invalid if the points and polygons are not
reasonable, i.e. to many points to process have been added. In those cases,
only the boundingbox contains useful information. Invalidity propagates to all
other regions, i.e. by addXML or by addRegion. 

Returns 1 (valid) or 0 (invalid)

=item setInvalid

Makes this region invalid. Only the boundingbox will contain useful information.

=item addXml(xml)

add the content of the datasetRegion xml-string or -node (XML::LibXML::Node) to this DatasetRegion

Dies on invalid xml

=item getBoundingBox

Return hash with north south east west (or empty)

=item extendBoundingBox(\%bb)

extend this bounding box to surround the existing and new bounding box

Dies on wrong defined %bb{north east west south}

=item overlapsBoundingBox(\%otherBB)

Check if this regions bounding-box has overlap with the otherBB. Returns true even if
this bounding box is not defined. Only checks on bounding boxes, not on points/polygons.

Dies on wrong defined %bb{north east west south}


=item getPoints

Return list of Metamod::LonLatPoint

=item addPoint([$lon, $lat] | $Metamod::LonLatPoint)

add a longitude/latitude point to the list of points

Dies on wrong defined longitude/latitude

=item uniquePoints

Make sure all points in this region are unique. This should be called after adding points and
before calling toString.

=item getPolygons

Return list of polygons, each as Metamod::LonLatPolygon


=item addPolygon([[$lon,$lat],[$lon,$lat],...,[$lon,$lat]])

adds a polygon to the region and makes sure that adjacent points are not equal (0-length line)
and that start-point == end-point

Dies on wrong defined longitude/latitude.

=item uniquePolygons

Make sure all polygons in this region are unique. This should be called after adding polygons
and before calling toString.

=item addRegion($datasetRegion)

Add another region to this dataset. Adds all points, polygons and extends the boundingBox, as well as running unique(Points/Polygons).

=item toString

Return this region in xml representation

=back

=head1 AUTHOR

Heiko Klein, E<lt>H.Klein@met.noE<gt>

=head1 SEE ALSO

L<Metamod::LonLatPoint>, L<XML::LibXML>

=cut

