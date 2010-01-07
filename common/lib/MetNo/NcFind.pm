package MetNo::NcFind;
# 
#---------------------------------------------------------------------------- 
#  METAMOD - Web portal for metadata search and upload 
# 
#  Copyright (C) 2008 met.no 
# 
#  Contact information: 
#  Norwegian Meteorological Institute 
#  Box 43 Blindern 
#  0313 OSLO 
#  NORWAY 
#  email: egil.storen@met.no 
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
#
use strict;
use warnings;

$MetNo::NcFind::VERSION = 0.04;


use Fcntl qw(:DEFAULT);
use Encode qw();
use PDL::NetCDF;
use PDL::Lite qw();
use UNIVERSAL qw();

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


sub new {
    my ($this, $ncfile) = @_;
    my $class = ref($this) || $this;
    my $self = {};

    die __PACKAGE__."::new requires ncFile as argument" unless $ncfile;    
    if (UNIVERSAL::isa($ncfile, 'PDL::NetCDF')) {
    	$self->{NCOBJ} = $ncfile;
    } else {
        # Open netCDF-file for reading
        $self->{NCOBJ} = PDL::NetCDF->new ($ncfile, {MODE => O_RDONLY, REVERSE_DIMS => 1});
    }
    unless (defined $self->{NCOBJ}) {
    	return undef;
    }
    return bless($self,$class);
}

sub globatt_names {
    my ($self) = @_;
    my $ncref = $self->{NCOBJ};
    return _decode(@{$ncref->getattributenames()});
}

sub globatt_value {
    my ($self, $globattname) = @_;

    my $ncref = $self->{NCOBJ};
    my $result = $ncref->getatt ($globattname);
    if (ref($result)) {
        return _decode($result->sclr);
    } else {
        return _decode($result);
    }
}

sub variables {
    my ($self) = @_;
    my $ncref = $self->{NCOBJ};
    # Return all variable names 
    return _decode(@{$ncref->getvariablenames()});
}

sub att_names {
    my ($self, $varname) = @_;

    my $ncref = $self->{NCOBJ};
    return _decode(@{$ncref->getattributenames($varname)});
}

sub att_value {
    my ($self, $varname, $attname) = @_;

    my $ncref = $self->{NCOBJ};
    my $result = $ncref->getatt($attname, $varname);
    if (ref($result)) {
        return _decode($result->sclr);
    } else {
        return _decode($result);
    }
}

sub dimensions {
    my ($self, $varname) = @_;

    my $ncref = $self->{NCOBJ};
    # Return the dimension names from a variable
    return _decode(@{$ncref->getdimensionnames($varname)});
}

sub get_bordervalues {
    my ($self, $varname) = @_;

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

sub get_values {
    my ($self, $varname) = @_;

    my $ncref = $self->{NCOBJ};    
    # Get the values of a  netCDF variable as PDL object
    # Resulting PDL object: $pdl1. NetCDF object: $ncref,
    # variable name: $varname.
    my $pdl1  = $ncref->get ($varname);

    # Return the values as an array:
    return $pdl1->list;
}

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
        $valid_min_lon = $ncref->getatt ("valid_min", $lon_name);
    }
    if (grep($_ eq "valid_max", @$attlist_lon) > 0) {
        $valid_max_lon = $ncref->getatt ("valid_max", $lon_name);
    }
    my $valid_min_lat = -90.0;
    my $valid_max_lat = 90.0;
    my $attlist_lat = $ncref->getattributenames($lat_name);
    if (grep($_ eq "valid_min", @$attlist_lat) > 0) {
        $valid_min_lat = $ncref->getatt ("valid_min", $lat_name);
    }
    if (grep($_ eq "valid_max", @$attlist_lat) > 0) {
        $valid_max_lat = $ncref->getatt ("valid_max", $lat_name);
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

1;
__END__
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

=head1 DESCRIPTION

This module gives read-only access to nc-files. It hides all datatype and
encoding issues. In contrast to the netcdf-user manual (since 3.6.3), netcdf-files
are assumed to be in iso8859, only if that conversion fails, utf-8 is assumed.

=head2 METHODS

=over 8

=item new(filename|PDL::NetCDF object)

open the ncfile and generate a new object
throws exception on errors

=item globalatt_names()

get a list of all global attributes

=item globatt_value($attName)

get the value of the global attribute named $attName

=item variables()

get a list of all variables

=item att_value($varName, $attName)

get the value of the attribute named $attName belonging to $varName

=item findVariablesByAttributeValue($attName, $pattern)

get a list of variables containing a attribute that matches $pattern. $pattern
should be a compiled regex, i.e. qr//;

=item dimensions($varName)

get a list of dimension-names belonging to variable $varName

=item get_bordervalues($varName)

get a list of all values on the border of the variable-array. It will
repeat the corner values.

=item get_values($varName)

get a one-dimensional list of all values of $varName

=item get_lonlats('longitude', 'latitude')

get lists of longitude and latitude values as array-reference of the variables
longitude and latitude. Clean the data for eventually occuring invalid values (outside -180/180, -90/90 
respectively). Both lists are guaranteed to be equal-sized. Returns [],[] if names are not found.

=back

=head1 AUTHOR

Egil Støren, E<lt>egils\@met.noE<gt>

=head2 CONTRIBUTORS

Heiko Klein, E<lt>heiko.klein\@met.noE<gt>

=head1 SEE ALSO

L<PDL::NetCDF>

=cut