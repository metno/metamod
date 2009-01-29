package ncfind;
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
require 0.01;
use strict;
use Fcntl;
use Encode;
$ncfind::VERSION = 0.02;
#   
#    Use PDL module with netCDF interface
#   
   use PDL;
   use PDL::Char;
   use PDL::NetCDF;


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
#   
#     Constructor function: ncfind
#   
   sub new {
      my $this = shift;
      my $class = ref($this) || $this;
      my $self = {};
      bless($self,$class);
#      
#       Open netCDF-file for reading
#      
      my $ncfile = shift;
      $self->{NCOBJ} = PDL::NetCDF->new ($ncfile, {MODE => O_RDONLY, REVERSE_DIMS => 1});
      return $self;
   }
#   
#     Method: globatt_names
#   
   sub globatt_names {
      my $self = shift;
      my $ncref = $self->{NCOBJ};
      return _decode(@{$ncref->getattributenames()});
   }
#   
#     Method: globatt_value
#   
   sub globatt_value {
      my $self = shift;
      my $globattname = shift;
      my $ncref = $self->{NCOBJ};
      my $result = $ncref->getatt ($globattname);
      if (ref($result)) {
         return _decode(sclr $result);
      } else {
         return _decode($result);
      }
   }
#   
#     Method: variables
#   
   sub variables {
      my $self = shift;
      my $ncref = $self->{NCOBJ};
#      
#       Return all variable names 
#      
      return _decode(@{$ncref->getvariablenames()});
   }
#   
#     Method: att_names
#   
   sub att_names {
      my $self = shift;
      my $varname = shift;
      my $ncref = $self->{NCOBJ};
      return _decode(@{$ncref->getattributenames($varname)});
   }
#   
#     Method: att_value
#   
   sub att_value {
      my $self = shift;
      my $varname = shift;
      my $attname = shift;
      my $ncref = $self->{NCOBJ};
      my $result = $ncref->getatt ($attname, $varname);
      if (ref($result)) {
         return _decode(sclr $result);
      } else {
         return _decode($result);
      }
   }
#   
#     Method: dimensions
#   
   sub dimensions {
      my $self = shift;
      my $varname = shift;
      my $ncref = $self->{NCOBJ};
#      
#       Return the dimension names from a variable
#      
      return _decode(@{$ncref->getdimensionnames($varname)});
   }
#   
#     Method: get_bordervalues
#   
   sub get_bordervalues {
      my $self = shift;
      my $varname = shift;
      my $ncref = $self->{NCOBJ};
#      
#       Get the values of a  netCDF variable as PDL object
#       Resulting PDL object: $pdl1. NetCDF object: $ncref,
#       variable name: $varname. 
#      
      my $pdl1  = $ncref->get ($varname);
#      
#       Create four 1D slices as edges of a 2D pdl
#      
      my $upperrow = $pdl1->slice(":,(0)");
      my $rightcol = $pdl1->slice("(-1),:");
      my $bottomrow_reversed = $pdl1->slice("-1:0,(-1)");
      my $leftcol_reversed = $pdl1->slice("(0),-1:0");
#      
#       Return the values as an array:
#      
      return (list($upperrow),list($rightcol), list($bottomrow_reversed), list($leftcol_reversed));
   }
#   
#     Method: get_values
#   
   sub get_values {
      my $self = shift;
      my $varname = shift;
      my $ncref = $self->{NCOBJ};
#      
#       Get the values of a  netCDF variable as PDL object
#       Resulting PDL object: $pdl1. NetCDF object: $ncref,
#       variable name: $varname. 
#      
      my $pdl1  = $ncref->get ($varname);
#      
#       Return the values as an array:
#      
      return (list $pdl1);
   }

   sub get_lonlats {
      my $self = shift;
      my $lon_name = shift;
      my $lat_name = shift;
      my $ncref = $self->{NCOBJ};
      my $valid_min_lon = -180.0;
      my $valid_max_lon = 180.0;
      my $attlist_lon = $ncref->getattributenames($lon_name);
      if (grep($_ eq "valid_min", @$attlist_lon) > 0) {
         my $valid_min_lon = $ncref->getatt ("valid_min", $lon_name);
      }
      if (grep($_ eq "valid_max", @$attlist_lon) > 0) {
         my $valid_max_lon = $ncref->getatt ("valid_max", $lon_name);
      }
      my $valid_min_lat = -90.0;
      my $valid_max_lat = 90.0;
      my $attlist_lat = $ncref->getattributenames($lat_name);
      if (grep($_ eq "valid_min", @$attlist_lat) > 0) {
         my $valid_min_lat = $ncref->getatt ("valid_min", $lat_name);
      }
      if (grep($_ eq "valid_max", @$attlist_lat) > 0) {
         my $valid_max_lat = $ncref->getatt ("valid_max", $lat_name);
      }
      my $pdl_lon  = $ncref->get ($lon_name);
      my $pdl_lat  = $ncref->get ($lat_name);
      my @lon = list $pdl_lon;
      my @lat = list $pdl_lat;
      my @rlon = ();
      my @rlat = ();
      while (@lon != 0) {
         my $plon = shift(@lon);
         my $plat = shift(@lat);
         if (defined($plon) && defined($plat) && $plon <= $valid_max_lon && 
             $plat <= $valid_max_lat &&
             $plon >= $valid_min_lon && $plat >= $valid_min_lat) {
            push(@rlon, $plon);
            push(@rlat, $plat);
         }
      }
      return (\@rlon,\@rlat);
   }
1;
