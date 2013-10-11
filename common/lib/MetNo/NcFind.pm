package MetNo::NcFind;

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

use strict;
use warnings;

$MetNo::NcFind::VERSION = do { my @r = (q$LastChangedRevision$ =~ /\d+/g); sprintf "0.%d", @r };
our $DEBUG = 0;

use Fcntl qw(:DEFAULT);
use Encode qw();
use PDL::NetCDF;
use PDL::Char;
use PDL::Lite qw();
use UNIVERSAL qw();

=head1 NAME

MetNo::NcFind - access and search variables and attributes in a Nc-File

=head1 SYNOPSIS

  use MetNo::NcFind;

  my $nc = new MetNo::NcFind('my/file.nc');
  my @globalAttributes = $nc->globatt_names;
  foreach my $globAtt (@globalAttributes) {
    my $globAttValue = $nc->globatt_value($globAtt);
  }
  my @variables = $nc->variables;
  my $attValue = $nc->att_value($varName, $attName);

  my @dimensions = $nc->dimensions($varName);

  my @borderVals = $nc->get_bordervalues($varName);
  my @vals = $nc->get_values($varName);

  my ($longRef, $latRef) = $nc->get_lonlats('longitude', 'latitude');

  my @vars = $nc->findVariablesByAttributeValue('units', qr/degrees?_(north|east)/);
  my @lonLatVars = $nc->findVariablesByDimensions(['lon','lat']);

=head1 DESCRIPTION

This module gives read-only access to nc-files. It hides all datatype and
encoding issues. In contrast to the netcdf-user manual (since 3.6.3), netcdf-files
are assumed to be in iso8859, only if that conversion fails, utf-8 is assumed.

=head1 METHODS

=head2 new(filename|PDL::NetCDF object)

open the ncfile and generate a new object
throws exception on errors

=cut

sub new {
    my ($this, $ncfile) = @_;
    my $class = ref($this) || $this;
    my $self = {};

    die __PACKAGE__."::new requires ncFile as argument" unless $ncfile;
    if (UNIVERSAL::isa($ncfile, 'PDL::NetCDF')) {
        $self->{NCOBJ} = $ncfile;
    } else {
        # Open netCDF-file for reading
        $self->{NCOBJ} = PDL::NetCDF->new ($ncfile, { MODE => O_RDONLY, REVERSE_DIMS => 1, SLOW_CHAR_FETCH => 1 });
    }
    unless (defined $self->{NCOBJ}) {
        return undef;
    }
    return bless($self,$class);
}

=head2 globalatt_names()

get a list of all global attributes

=cut

sub globatt_names {
    my ($self) = @_;
    my $ncref = $self->{NCOBJ};
    return _decode(@{$ncref->getattributenames()});
}

=head2 globatt_value($attName)

get the value of the global attribute named $attName
Returns undef if variable or attribute don't exist.

=cut

sub globatt_value {
    my ($self, $globattname) = @_;

    my $ncref = $self->{NCOBJ};
    my $retVal;
    eval {
        my $result = $ncref->getatt ($globattname);
        if (ref($result)) {
            $retVal =  $result->sclr; # scalar (numeric) value, don't decode
        } else {
            $retVal = _decode($result);
        }
    }; if ($@) {
        # att-name doesn't exists, don't care
    }
    return $retVal;
}

=head2 variables()

get a list of all variables

=cut

sub variables {
    my ($self) = @_;
    my $ncref = $self->{NCOBJ};
    # Return all variable names
    return _decode(@{$ncref->getvariablenames()});
}

=head2 att_names($varName)

get a list of all the attributes for a variable

=cut

sub att_names {
    my ($self, $varname) = @_;

    my $ncref = $self->{NCOBJ};
    return _decode(@{$ncref->getattributenames($varname)});
}

=head2 att_value($varName, $attName)

get the value of the attribute named $attName belonging to $varName.
Returns undef if variable or attribute don't exist.

=cut

sub att_value {
    my ($self, $varname, $attname) = @_;

    my $ncref = $self->{NCOBJ};
    my $result;
    eval {
    	$result = $ncref->getatt($attname, $varname);
    }; if ($@) {
        # don't care
    }
    if (ref($result)) {
        return $result->sclr; # scalar (numeric) value, don't decode
    } else {
        return _decode($result);
    }
}

=head2 dimensions($varName)

get a list of dimension-names belonging to variable $varName. If varName is missing, lists
alls dimensions of the file.

=cut

sub dimensions {
    my ($self, $varname) = @_;

    my $ncref = $self->{NCOBJ};
    # Return the dimension names from a variable
    return _decode(@{$ncref->getdimensionnames($varname)});
}

=head2 dimensionSize($dimName)

get the integer size of the dimension $dimName

=cut

sub dimensionSize {
    my ($self, $dimName) = @_;
    return $self->{NCOBJ}->dimsize($dimName);
}

=head2 get_bordervalues($varName)

get a list of all values on the border of the variable-array. It will
repeat the corner values.

=cut

sub get_bordervalues {
    my ($self, $varname) = @_;

    my @dims = $self->dimensions($varname);
    if (@dims != 2) {
        die "get_bordervalues requires variable to be of dim 2, found $varname(@dims)\n";
    }

    my $ncref = $self->{NCOBJ};
    # Get the values of a  netCDF variable as PDL object
    # Resulting PDL object: $pdl1. NetCDF object: $ncref,
    # variable name: $varname.
    my $pdl1  = $ncref->get ($varname);

    # Create four 1D slices as edges of a 2D pdl
    my $upperrow = $pdl1->slice(":,(0)");
    my $rightcol = $pdl1->slice("(-1),:");
    my $bottomrow_reversed = $pdl1->slice("-1:0,(-1)");
    my $leftcol_reversed = $pdl1->slice("(0),-1:0");

    # Return the values as an array:
    return ($upperrow->list,$rightcol->list, $bottomrow_reversed->list, $leftcol_reversed->list);
}

=head2 get_values($varName)

B<DEPRECATED> get a one-dimensional list of all values of $varName

=cut

sub get_values { # DEPRECATED - use $self->get_struct()
    my ($self, $varname) = @_;

    my $ncref = $self->{NCOBJ};
    # Get the values of a  netCDF variable as PDL object
    # Resulting PDL object: $pdl1. NetCDF object: $ncref,
    # variable name: $varname.
    my $pdl1  = $ncref->get ($varname);

    # Return the values as an array:
    return $pdl1->list; # note list() is deprecated - use $pdl1->unpdl() instead
}

=head2 get_struct($varName)

get a multi-dimensional list of all values of $varName

=cut

sub get_struct {
    my ($self, $varname) = @_;

    my $ncref = $self->{NCOBJ};
    # Get the values of a  netCDF variable as PDL object
    # Resulting PDL object: $pdl1. NetCDF object: $ncref,
    # variable name: $varname.
    my $pdl1  = $ncref->get ($varname);

    # Return the values as an data structure (eg. list of lists):
    #printf STDERR "PDL|$varname [%d]: %s\n%s\n", $pdl1->get_datatype, $pdl1->dims, $pdl1;
    printf STDERR "PDL|$varname [%d]: %s\n", $pdl1->get_datatype, $pdl1;
    if ($pdl1->get_datatype == 0) {
	#printf STDERR "<< %s\n", $ncref->gettext($varname); # not working
	#printf STDERR ">> %s\n", $pdl1;
	my $str = sprintf $pdl1; # $ncref->gettext($varname);
	chomp $str;
	#print STDERR "*** <$str>\n";
	$str =~ s/(^\s*\[ ')|(' \]\s*$)//g; # trim junk at start and end
	my @strings = split "' '", $str;
	#map s/'//g, @strings;
	#return \@strings;
	return \@strings;
    } else {
	return $pdl1->unpdl;
    }
}

=head2 get_lonlats('longitude', 'latitude')

get lists of longitude and latitude values as array-reference of the variables
longitude and latitude. Clean the data for eventually occuring invalid values (outside -180/180, -90/90
respectively). Both lists are guaranteed to be equal-sized. Returns [],[] if names are not found.

=cut

sub get_lonlats {
    my ($self, $lon_name, $lat_name) = @_;

    my $ncref = $self->{NCOBJ};

    my %variables = map {$_ => 1} $self->variables;
    unless (exists $variables{$lon_name} and exists $variables{$lat_name}) {
    	return ([], []);
    }

    # check/set valid ranges
    my $valid_min_lon = -180.0;
    my $valid_max_lon = 180.0;
    my $attlist_lon = $ncref->getattributenames($lon_name);
    if (grep($_ eq "valid_min", @$attlist_lon) > 0) {
        $valid_min_lon = $self->att_value($lon_name, "valid_min");
    }
    if (grep($_ eq "valid_max", @$attlist_lon) > 0) {
        $valid_max_lon = $self->att_value($lon_name, "valid_max");
    }
    my $valid_min_lat = -90.0;
    my $valid_max_lat = 90.0;
    my $attlist_lat = $ncref->getattributenames($lat_name);
    if (grep($_ eq "valid_min", @$attlist_lat) > 0) {
        $valid_min_lat = $self->att_value($lat_name, "valid_min");
    }
    if (grep($_ eq "valid_max", @$attlist_lat) > 0) {
        $valid_max_lat = $self->att_value($lat_name, "valid_max");
    }

    my $pdl_lon  = $ncref->get ($lon_name);
    my $pdl_lat  = $ncref->get ($lat_name);
    my @lon = $pdl_lon->list if defined $pdl_lon;
    my @lat = $pdl_lat->list if defined $pdl_lat;
    my @rlon = ();
    my @rlat = ();
    while (@lon != 0 and @lat != 0) {
        my $plon = shift(@lon);
        my $plat = shift(@lat);
        if (defined($plon) && defined($plat) &&
            $plon <= $valid_max_lon && $plat <= $valid_max_lat &&
            $plon >= $valid_min_lon && $plat >= $valid_min_lat
           ) {
            push(@rlon, $plon);
            push(@rlat, $plat);
        }
    }
    return (\@rlon,\@rlat);
}

=head2 findVariablesByAttributeValue($attName, $pattern)

get a list of variables containing a attribute that matches $pattern. $pattern
should be a compiled regex, i.e. qr//;

=cut

sub findVariablesByAttributeValue {
    my ($self, $attribute, $valueRegex) = @_;
    my @variables = $self->variables;
    my @outVars;
    foreach my $var (@variables) {
        my $val = $self->att_value($var, $attribute);
        if (defined $val and ! ref $val) { # pdl-attributes not supported
            if ($val =~ /$valueRegex/) {
                push @outVars, $var;
            }
        }
    }
    return @outVars;
}

=head2 findVariablesByDimensions(\@dimNameList)

get a list of all variables containing at least the applied dimension-names. Gives all
variables if @dimNameList is empty.

=cut

sub findVariablesByDimensions {
    my ($self, $dimRef) = @_;
    my %dims = map {$_ => 1} @$dimRef;
    my @outVars;
    foreach my $var ($self->variables) {
        my $foundDims = 0;
        foreach my $vDim ($self->dimensions($var)) {
            $foundDims++ if exists $dims{$vDim};
        }
        if ($foundDims == scalar keys %dims) {
            # all requested dims found
            push @outVars, $var;
        }
    }
    return @outVars;
}

=head2 findBoundingBoxByGlobalAttributes($northAtt, $southAtt, $eastAtt, $westAtt)

Find the geographical bounding box by global attributes, i.e. for damocles by
qw(northernmost_latitude southernmost_latitude easternmost_longitude westernmost_longitude)
or for  Unidata Dataset Discovery v1.0 by
qw(geospatial_lat_max geospatial_lat_min geospatial_lon_max geospatial_lon_min)

Return: %boundingBox{north,south,east,west}, empty if not all attributes are found.
Dies on errors, e.g. boundingBox-value out of range.

=cut

sub findBoundingBoxByGlobalAttributes {
    my ($self, $northAtt, $southAtt, $eastAtt, $westAtt) = @_;
    my %boundingBox;
    my %globAtt = map {$_ => 1} $self->globatt_names;
    if ($DEBUG) {
        print STDERR (caller(0))[3], " called\n";
        foreach my $var ($northAtt, $southAtt, $eastAtt, $westAtt) {
            warn "$var not found\n" unless exists $globAtt{$var};
        }
    }
    if (exists $globAtt{$northAtt} &&
        exists $globAtt{$southAtt} &&
        exists $globAtt{$westAtt} &&
        exists $globAtt{$eastAtt})
       {
        # select values in number representation
        $boundingBox{north} = $self->globatt_value($northAtt) + 0;
        $boundingBox{south} = $self->globatt_value($southAtt) + 0;
        $boundingBox{west} = $self->globatt_value($westAtt) + 0;
        $boundingBox{east} = $self->globatt_value($eastAtt) + 0;
        if (abs($boundingBox{north}) > 90 or
            abs($boundingBox{south}) > 90 or
            abs($boundingBox{west}) > 180 or
            abs($boundingBox{east}) > 180)
        {
            my $msg = sprintf "bounding-box out of range: south=%.2f, north=%.2f, east=%.2f, west=%.2f", @boundingBox{qw(south north east west)};
            die $msg;
        }
    }
    return %boundingBox;
}

=head2 extractCFLonLat

Extract lat/lon information as polygons or points from the used latitude/longitude variables
given as CF convention.

Return (errors => \@errors, polygons => \@lonLatPolygons, points => \@lonLatPoints)

=cut

sub extractCFLonLat {
    my ($self) = @_;
    my @lonLatPolygons;
    my @lonLatPoints;
    my @errors;

    my @dimNames = $self->dimensions;
    my $realDims = 0;
    foreach my $dim (@dimNames) {
        if ($self->dimensionSize($dim) > 1) {
            # netcdf-files might be data-deleted by metamod, that is
            # all dimensions are set to 0 (unlimited) or 1
            $realDims++;
        }
    }

    if ($realDims == 0) {
        # no dimensions => no polygons/points, return here
        return (errors => \@errors, polygons => \@lonLatPolygons, points => \@lonLatPoints);
    }

    # find latitude/longitude variables (variables with units degree(s)_(north|south|east|west))
    my %latDims = map {$_ => 1} $self->findVariablesByAttributeValue('units', qr/degrees?_(north|south)/);
    my %lonDims = map {$_ => 1} $self->findVariablesByAttributeValue('units', qr/degrees?_(east|west)/);


    # lat/lon pairs can, according to CF-1.3 belong in differnt ways to a variable
    # a) var(lat,lon), lat(lat), lon(lon) (CF-1.3, 5.1)
    # b) var(x,y), var:coordinates = "lat lon ?", lat(x,y), lon(x,y) (CF-1.3, 5.2, 5.6)
    # c) var(t), var:coordinates = "lat lon ?", lat(t), lon(t) (CF-1.3, 5.3-5.5)
    #
    # a) and b) will be translated to a polygon describing the outline
    # c) will be translated to a list of lat/lon points

    # find variables directly related to each combination of lat/lon (a)
    my @lonLatCombinations;
    foreach my $lat (keys %latDims) {
        foreach my $lon (keys %lonDims) {
            push @lonLatCombinations, [$lon,$lat];
        }
    }
    my @lonLatDimVars;
    my @usedLonLatCombinations;
    my @unUsedLonLatCombinations;
    foreach my $llComb (@lonLatCombinations) {
        my @llDimVars = $self->findVariablesByDimensions($llComb);
        if (@llDimVars) {
            push @lonLatDimVars, @llDimVars;
            push @usedLonLatCombinations, $llComb;
        } else {
            push @unUsedLonLatCombinations, $llComb;
        }
    }
    foreach my $llCom (@usedLonLatCombinations) {
        # build a polygon around all defined outer points
        my @lons = map {(abs($_) <= 180) ? $_ : ()} $self->get_values($llCom->[0]);
        my @lats = map {(abs($_) < 180) ? $_ : ()} $self->get_values($llCom->[1]);
        if (@lons && @lats) {
            my @polygon;
            push @polygon, map{[$_, $lats[0]]} @lons;
            push @polygon, map{[$lons[-1], $_]} @lats;
            push @polygon, map{[$_, $lats[-1]]} reverse @lons;
            push @polygon, map{[$lons[0], $_]} reverse @lats;
            push @lonLatPolygons, \@polygon;
        }
    }

    # get the coordinates values to find lat/lon pairs (b and c)
    my @coordVars = $self->findVariablesByAttributeValue('coordinates', qr/.*/);
    # remove the variables already detected as class a)
    my %lonLatDimVars = map {$_ => 1} @lonLatDimVars;
    @coordVars = map {exists $lonLatDimVars{$_} ? () : $_} @coordVars;

    my @lonLatCoordinates;
    foreach my $coordVar (@coordVars) {
        my @coordinates = split ' ', $self->att_value($coordVar, 'coordinates');
        my %coordinates = map {$_ => 1} @coordinates;
        my @tempUnusedLonLatCombinations = @unUsedLonLatCombinations;
        @unUsedLonLatCombinations = ();
        foreach my $llComb (@tempUnusedLonLatCombinations) {
            if (exists $coordinates{$llComb->[0]} and
                exists $coordinates{$llComb->[1]}) {
                push @lonLatCoordinates, $llComb;
                push @usedLonLatCombinations, $llComb;
            } else {
                push @unUsedLonLatCombinations, $llComb;
            }
        }
    }
    if (@usedLonLatCombinations == 0 and @unUsedLonLatCombinations > 0) {
        # wrong netcdf-file? Forgotten coordinates?
        my $llComb = shift @unUsedLonLatCombinations;
        my $message = sprintf "Couldn't detect Longitude Latitude combination, missing coordinates? Trying (%s,%s)", @$llComb;
        warn $message. "\n" if $DEBUG;
        push @errors, $message;
        push @usedLonLatCombinations, $llComb;
        push @lonLatCoordinates, $llComb;
    }
    foreach my $llCoord (@lonLatCoordinates) {
        # $llCoord is a used lon/lat combination for case b and c
        # use case b if lat and lon are 2d, case c for 1d
        my $lonName = $llCoord->[0];
        my $latName = $llCoord->[1];
        my @latDims = $self->dimensions($latName);
        my @lonDims = $self->dimensions($lonName);
        if (@latDims != @lonDims) {
            my $msg = "number $latName dimensions (@latDims) != $lonName dimensions (@lonDims), skipping ($latName,$lonName)";
            warn $msg if $DEBUG;
            push @errors, $msg;
        } elsif (1 == @latDims) {
            # case c)
            my ($lons, $lats) = $self->get_lonlats($lonName, $latName);
            while (@$lons) {
                push @lonLatPoints, [shift @$lons, shift @$lats];
            }
        } elsif (2 == @latDims) {
            # case b)
            my @lonBorders = $self->get_bordervalues($lonName);
            my @latBorders = $self->get_bordervalues($latName);
            if (scalar @lonBorders == scalar @latBorders) {
                my @polygon = map {[$_, shift @latBorders]} @lonBorders;
                # check for valid values
                @polygon = map {(abs($_->[0]) <= 180 and abs($_->[1]) <= 90) ? $_ : ()} @polygon;
                if (@polygon) {
                    unless ($polygon[0][0] == $polygon[-1][0] and $polygon[0][1] == $polygon[-1][1]) {
                        push @polygon, $polygon[0]; # make sure endpoint == startpoint
                    }
                    push @lonLatPolygons, \@polygon;
                }
            } else {
                my $msg = "$latName dimension ".(scalar @latBorders)." != $lonName dimensions ".(scalar @lonBorders).", skipping";
                warn $msg if $DEBUG;
                push @errors, $msg;
            }
        } else {
            my $msg = "$latName and $lonName are of dimension ".(scalar @latDims). ". Don't know what to do, skipping.";
            warn $msg if $DEBUG;
            push @errors, $msg;
        }
    }

    return (errors => \@errors, polygons => \@lonLatPolygons, points => \@lonLatPoints);
}


##########################################################################################
#
# HELPER FUNCTIONS

#
# try encoding with utf8
# if errors try encoding with iso8859-1
# if still errors, try encoding with utf8 ignoring errors
#
sub _utf8Iso8859_1Decode {
    my $retVal = $_[0];
    eval {$retVal = Encode::decode('utf8', $retVal, Encode::FB_CROAK)};
    if ($@) {
        eval {$retVal = Encode::decode('iso8859-1', $retVal, Encode::FB_CROAK)};
        if ($@) {
            $retVal = Encode::decode('utf8', $retVal);
        }
    }
    return $retVal;
}

#
# Default decoding of data to perl internal format
# with utf-8 flag switched on.
# It is no problem to _decode twice.
# Original in netcdf is assumed to be 'utf8' or 'iso8859-1'.
#
sub _decode {
    return wantarray ? map {_utf8Iso8859_1Decode($_)} @_
                     : _utf8Iso8859_1Decode($_[0]);
}

1;

=head1 AUTHOR

Egil Støren, E<lt>egils\@met.noE<gt>

=head2 CONTRIBUTORS

Heiko Klein, E<lt>heiko.klein\@met.noE<gt>

=head1 SEE ALSO

L<PDL::NetCDF>

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut
