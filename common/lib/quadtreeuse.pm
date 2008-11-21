package quadtreeuse;
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
use POSIX;
use strict;
use warnings;
use Geo::Proj4;
our $VERSION = 0.01;
#
#  Constructor function: new
#
sub new {
#
#  Usage: quadtreeuse->new($lat,$lon.$r,$depth,$proj);
#
#  where:
#
#  $lat,$lon   = latitude,longitude for the centre of the area
#  $r          = Radius of the area (metres)
#  $depth      = Depth of quadtree
#  $proj       = Projection string accepted by the Geo::Proj4 software
#
   my $this = shift;
   my $class = ref($this) || $this;
   my $self = {};
   $self->{LAT} = shift;
   $self->{LON} = shift;
   $self->{R} = shift;
   $self->{DEPTH} = shift;
   $self->{PROJ} = shift;
   $self->{GRID} = {};
   bless($self,$class);
   $self->{PROJ4} = $self->_get_proj4();
   my $lat = $self->{LAT};
   my $lon = $self->{LON};
   my $r = $self->{R};
   my $proj4 = $self->{PROJ4};
   my $depth = $self->{DEPTH};
   if (defined($lat) and defined($lon) and defined($r) and defined($proj4)) {
	my ($x, $y) = $proj4->forward($lat, $lon);
        $self->{XMIN} = $x-$r;
        $self->{XMAX} = $x+$r;
        $self->{YMIN} = $y-$r;
        $self->{YMAX} = $y+$r;
        $self->{XSTEP} = ($self->{XMAX} - $self->{XMIN}) / (1 << ($self->{DEPTH} - 1));
        $self->{YSTEP} = ($self->{YMAX} - $self->{YMIN}) / (1 << ($self->{DEPTH} - 1));
   } else {
	die "quadtreeuse: Missing object variables in initialisation routine";
   }
   return $self;
}

sub add_lonlats {
#
# Public method.
# Add a set of (longitude,latitude) points to the quadtree.
# Three arguments: 
# 
#   1. String telling how the longitude,latitude values should be
#      interpreted:
#      "line":    The values defines a line. NOTE: This option is not currently
#                 in use, and is poorly tested.
#      "points":  The values defines separate points
#      "area":    The values represents a closed line which defines an area
#   2. Reference to an array of longitude values
#   3. Reference to an array of latitude values
#
# The two array has to contain the same number of elements.
#
   my $self = shift;
   my $coverage = shift;
   my $reflons = shift;
   my $reflats = shift;
   my $pcount = scalar @$reflons;
   my $depth = $self->{DEPTH};
   my $proj4 = $self->{PROJ4};
#
# Variables which will define the smallest rectangle within which
# all input points are found:
#
   my $x_low = $self->{XMAX};
   my $x_high = $self->{XMIN};
   my $y_low = $self->{YMAX};
   my $y_high = $self->{YMIN};
#
# For coverage="area", use a clean grid hash to represent the polygon
# defining the edges of the area. Later, the internals of the polygon will be
# filled, and this filling procedure requires a grid hash containing only the
# polygon. For coverage="line" or "points", the
# nodes can be entered directly into the grid hash owned by self:
#
   my $gridref;
   if ($coverage eq "area") {
      $gridref = {};
   } else {
      $gridref = $self->{GRID};
   }

   if ($coverage eq "line" || $coverage eq "area") {

# Length of each bottom level node rectangle along Y axis:
      my $ystep = $self->{YSTEP};

# Small number used to adjust Y values to avoid exact match with
# grid-line values:
      my $ydelta = 0.01*$ystep;

# The search rectangle is divided into a grid containing bottom level node
# rectangles. These node rectangles can be identifed using indices along
# the X and Y axes. These indices runs from 0. (0,0) is the upper left
# corner of the grid. The following array will contain references to small
# two-element arrays containing indices (ix,iy) in this grid. This array
# is used to accumulate points for coverage "area" and "line".
# Both the original points computed from (lat,lon), plus sequences of points
# between each pair of consecutive original points, are added to this array.
      my @points = ();
#
# The (lat,lon) points may fall outside the search rectangle. Some points
# in the sequence of points between two original (lat,lon) points may fall
# inside the search rectangle, even if one or both of the endpoints are
# outside. The loop below (over all the original (lat,lon) points) has an 
# inner loop for computing the points between consecutive original points.
# For the points in the inner loop, a check is made
# to see if they fall outside the search rectangle. If so, the treatment
# of the points depends on the coverage value. If coverage = "line", the 
# points are discarded. If coverage ="area", the situation is not so simple:
#
# For coverage  ="area", the points defines a polygon that may partly
# extend to areas outside the search rectangle. The area of interest is the
# intersection between the search rectangle and the area inside the polygon.
# This intersection may be found by projecting the points outside the
# search rectangle on to points on the sides of the search rectangle.
# I. e., for a point (x,y) substitute (xmax,y) if x > xmax and y between
# ymin and ymax. Similar substitutions for (x,y) values falling in other
# quadrantlike outer areas. (xmax, xmin, ymax, ymin defines the search 
# rectangle).
#
# This is implemented using an array of indices that holds the points
# on the rectangle sides that are projected as described above. Each
# element in this array represents a number ix*10000 + iy, where (ix,iy)
# is the indices for the point in the search rectangle grid:
      my @borderixiy = ();
#
# Projected points are pushed to this array as they are found. This works OK
# as long the direction in which points are added along the rectangle sides
# do not change. If it changes, points that already have been added must be 
# removed. To achieve this, the following variables representing the 
# two last added points are used:
#
      my $previxiy;
      my $currentixiy;
#
# Loop to compute @points and the $x_low, ... values:
      my $prev;
      for (my $i1=0; $i1 < $pcount; $i1++) {
         my $lon = $reflons->[$i1];
         my $lat = $reflats->[$i1];
         my ($x, $y) = $proj4->forward($lat, $lon);
         if (defined($x) && defined($y)) {
            if ($x < $x_low) {$x_low = $x}
            if ($x > $x_high) {$x_high = $x}
            if ($y < $y_low) {$y_low = $y}
            if ($y > $y_high) {$y_high = $y}
     
            if (! defined($prev)) {
	        $prev = [$x, $y];
	        next;
            }
            my $xprev  = $prev->[0];
            my $yprev  = $prev->[1];
            if (!defined($x) || !defined($xprev) | !defined($y) || !defined($yprev))  {
               die "x y problems";
            }
            if ($x == $xprev && $y == $yprev) {
               next;
            }
            my $ystep1;
            my $ystart;
            my $loopcount;
            if ($y > $yprev) {
               $ystep1 = $ystep;
               $ystart = POSIX::floor(($yprev - $self->{YMIN})/$ystep)*$ystep + $ystep + $self->{YMIN};
               $loopcount = POSIX::floor(($y - $yprev)/$ystep) + 1;
            } else {
               $ystep1 = -$ystep;
               $ystart = POSIX::floor(($yprev - $self->{YMIN})/$ystep)*$ystep + $self->{YMIN};
               $loopcount = POSIX::floor(($yprev - $y)/$ystep) + 1;
            }
            my $yloop = $ystart;
            if ($y != $yprev) {
               my $slope = ($x - $xprev)/($y - $yprev);
   #   
   #    Inner loop for points between original (user provided) points:
   #   
               for (my $i1=0; $i1 < $loopcount; $i1++) {
                  my $xval = $xprev + ($yloop - $yprev)*$slope;
                  if (_outside($xval,$x,$xprev) || _outside($yloop,$y,$yprev)) {
                     next;
                  }
   #   
   #    Check if the new point is outside the search rectangle:
   #   
                  if ($xval >= $self->{XMAX} || $xval <= $self->{XMIN} ||
                      $yloop >= $self->{YMAX} || $yloop <= $self->{YMIN}) {
                     if ($coverage eq "line") {
                        $self->_add_to_points(\@points,undef);
                        next;
                     } else {
   #   
   #    Project the ($xval, $yloop) point onto one of the sides of the search
   #    rectangle:
   #   
                        my $xborder = $xval;
                        my $yborder = $yloop;
                        if ($xborder >= $self->{XMAX}) {
                           $xborder = $self->{XMAX} - 0.01*$self->{XSTEP};
                        } elsif ($xborder <= $self->{XMIN}) {
                           $xborder = $self->{XMIN} + 0.01*$self->{XSTEP};
                        }
                        if ($yborder >= $self->{YMAX}) {
                           $yborder = $self->{YMAX} - 0.01*$self->{YSTEP};
                        } elsif ($yborder <= $self->{YMIN}) {
                           $yborder = $self->{YMIN} + 0.01*$self->{YSTEP};
                        }
   #   
   #    Modify @borderixiy, $previxiy and $currentixiy:
   #   
                        my $newixiy = $self->_get_ixiy($xborder, $yborder);
                        if (!defined($currentixiy)) {
                           $currentixiy = $newixiy;
                        } elsif ($newixiy != $currentixiy) {
                           if (!defined($previxiy)) {
                              $previxiy = $currentixiy;
                              $currentixiy = $newixiy;
                           } elsif ($newixiy == $previxiy) {
                              $currentixiy = $previxiy;
                              if (scalar @borderixiy > 0) {
                                 $previxiy = pop(@borderixiy);
                              } else {
                                 undef $previxiy;
                              }
                           } else {
                              my $tmpix = $currentixiy;
                              $currentixiy = $newixiy;
                              push(@borderixiy,$previxiy);
                              $previxiy = $tmpix;
                           }
                        }
   #                     _report_border(\@borderixiy,$previxiy,$currentixiy);
                     }
                  } else {
                     if ($coverage eq "area") {
   #   
   #    Check if the sequence of points has just returned from an area outside
   #    the search rectangle. If so, move the border indices to the $gridref hash:
   #   
                        if (defined($currentixiy)) {
                           if (defined($previxiy)) {
                              push(@borderixiy,$previxiy);
                              undef $previxiy;
                           }
                           push(@borderixiy,$currentixiy);
                           undef $currentixiy;
                           foreach my $ixiy (@borderixiy) {
                              $self->_add_to_points(\@points,$ixiy);
                           }
                           @borderixiy = ();
                        }
                     }
                     my $ixiy = $self->_get_ixiy($xval,$yloop);
                     $self->_add_to_points(\@points,$ixiy);
                  }
                  $yloop += $ystep1;
               }
            }
            $prev = [$x, $y];
         }
     }
     if (defined($currentixiy)) {
        if (defined($previxiy)) {
           push(@borderixiy,$previxiy);
           undef $previxiy;
        }
        push(@borderixiy,$currentixiy);
        undef $currentixiy;
        foreach my $ixiy (@borderixiy) {
           $self->_add_to_points(\@points,$ixiy);
        }
        @borderixiy = ();
     }
     if (defined($prev)) {
        if ($coverage eq "area") {
           push(@points,$points[0]) if @points;
        }
        $self->_addpoints($gridref,\@points,$ydelta);
     }
  } elsif ($coverage eq "points") {
     for (my $i1=0; $i1 < $pcount; $i1++) {
         my $lon = $reflons->[$i1];
         my $lat = $reflats->[$i1];
         my ($x, $y) = $proj4->forward($lat, $lon);
         my $index = $self->get_index($x, $y);
         $gridref->{$index} = 1;
     }
  }

  if ($coverage eq "area") {
     if ($x_high > $self->{XMAX}) {$x_high = $self->{XMAX}-0.01*$self->{XSTEP};}
     if ($x_low < $self->{XMIN}) {$x_low = $self->{XMIN}+0.01*$self->{XSTEP};}
     if ($y_high > $self->{YMAX}) {$y_high = $self->{YMAX}-0.01*$self->{YSTEP};}
     if ($y_low < $self->{YMIN}) {$y_low = $self->{YMIN}+0.01*$self->{YSTEP};}
     $self->_fill_area($gridref,$x_low,$y_low,$x_high,$y_high);
  }
}

sub add_nodes {
#
# Public method.
# Add a set of quadtree nodes to the quadtree.
#
# One argument: Reference to an array of strings containing the nodes.
#
    my $self = shift;
    my $nodes_ref = shift;
    my $selfgrid = $self->{GRID};
    foreach my $node (@$nodes_ref) {
       my $index = _findindex($node);
       $selfgrid->{$index} = 1;
    }
}

sub get_nodes {
#
# Public method.
# Return the nodes as a sorted array:
#
    my $self = shift;
    _prune($self->{GRID});
    my @result = ();
    for my $key (sort {$a <=> $b} keys %{$self->{GRID}}) {
	my $id = _findid($key);
        push (@result,$id);
    }
    return @result;
}

sub _addpoints {
   my ($self,$gridref,$pointsref,$ydelta) = @_;

   my $prev;
   foreach my $pt (@$pointsref) {

       my ($ix, $iy) = @{$pt};
       if (! defined($ix)) {
          undef $prev;
          next;
       }
       if (! defined($prev)) {
	   $prev = [$ix, $iy];
	   next;
       }
       my ($ixprev, $iyprev) = @{$prev};
       $prev = [$ix, $iy];
       $self->_add_line($gridref, $ixprev, $iyprev, $ix, $iy);
   }
}

sub _outside {
   my ($val,$a1,$a2) = @_;
   if ($a1 > $a2) {
      my $a3 = $a2;
      $a2 = $a1;
      $a1 = $a3;
   }
   if ($val < $a1 || $val > $a2) {
      return 1;
   } else {
      return 0;
   }
}

sub _prune {
    my $grid = shift;
    my $pruned;
    do {
	$pruned = 0;
	for my $key (keys %$grid) {
	    next unless exists $grid->{$key}; # will delete keys during loop. Keys could be missing.
	    next if $key < 5; # don't prune beyond children of the rootnode
            my @ancestors = _ancestors($key);
	    my $parent   = _parent($key);
	    my @siblings = _children($parent);
            if (_any_exists($grid, @ancestors)) {
		delete @$grid{@siblings};
		$pruned = 1;
            } elsif (_all_exists($grid, @siblings)) {
		delete @$grid{@siblings};
		$grid->{$parent}++;
		$pruned = 1;
	    }
	}
    } while ($pruned);
}

sub _all_exists {
    my ($hash, @keys) = @_;
    for my $key (@keys) {
	return unless exists $hash->{$key};
    }
    return 1;
}

sub _any_exists {
    my ($hash, @keys) = @_;
    for my $key (@keys) {
        if (exists $hash->{$key}) {
           return 1;
        }
    }
    return 0;
}

sub _findid {
    my $index = shift;
    my $gridid = _gridpos($index);
    while ($index > 0) {
	$index = _parent($index);
	last if $index == 0;
	$gridid = _gridpos($index) . $gridid;
    }
    return $gridid;
}

sub _findindex {
   my $node = shift;
   my @digits = ();
   while ($node ne "") {
      unshift (@digits,chop($node));
   }
   my $index = 0;
   foreach my $digit (@digits) {
      $index = 4*$index + $digit;
   }
   return $index;
}

sub _parent {
    my $index = shift;
    return int( ($index-1)/4 );
}

sub _ancestors {
    my $index = shift;
    my @result = ();
    while ($index >= 5) {
       $index = ($index-1)/4;
       push (@result,$index);
    }
    return @result;
}

sub _children {
    my $index = shift;
    my $offset = $index*4;
    return $offset+1 .. $offset+4;
}

sub _gridpos {
    my $index = shift;
    return (1 .. 4)[($index-1)%4];
}

sub _get_proj4 {
    my $self = shift;

    my $projstr = $self->{PROJ};

#    return Geo::Proj4->new($projstr);
    my %proj_params;
    my @params = split ' ' => $projstr;
    for (@params){
	next if /^<>$/;
	next unless /\S/;
	my ($k, $v) = split /=/;
	$k =~ s/^\+//;
	$proj_params{$k} = $v;
    }
    return Geo::Proj4->new(%proj_params);
}

sub _fill_area {
   my ($self,$gridref,$x_low,$y_low,$x_high,$y_high) = @_;
   my $depth = $self->{DEPTH};
#
#  Purpose: Find a set of indices that includes the indices in
#  $gridref, as well as the indices internal to the polygon 
#  defined by $gridref. The resulting set of indices are added
#  to $self->{GRID}.
#
#  Initially, fill the temporary grid $agrid with indices covering the
#  rectangle-shaped area defined by the min- and max-values of the
#  (x,y) point set of the polygon:
#
   my $agrid = {};
   $self->_add_index($agrid,$x_low,$y_low,$x_high,$y_high);
#
#  Find the indices for the four corners of the rectangle-shaped area:
#
   my $bottom_left = $self->get_index($x_low,$y_low);
   my $bottom_left_down = _neighbour($bottom_left,3,$depth);
   my $bottom_left_left = _neighbour($bottom_left,4,$depth);
   my $upper_left = $self->get_index($x_low,$y_high);
   my $upper_left_up = _neighbour($upper_left,1,$depth);
   my $upper_left_left = _neighbour($upper_left,4,$depth);
   my $upper_right = $self->get_index($x_high,$y_high);
   my $upper_right_up = _neighbour($upper_right,1,$depth);
   my $upper_right_right = _neighbour($upper_right,2,$depth);
   my $bottom_right = $self->get_index($x_high,$y_low);
   my $bottom_right_down = _neighbour($bottom_right,3,$depth);
   my $bottom_right_right = _neighbour($bottom_right,2,$depth);
#
#  Set up a queue for indices to be processed:
#
   my @queue = ();
   my %visited = ();
   _linefill($bottom_left,$upper_left,\@queue,0,\%visited,1,$depth,0);
   _linefill($upper_left,$upper_right,\@queue,0,\%visited,2,$depth,0);
   _linefill($upper_right,$bottom_right,\@queue,0,\%visited,3,$depth,0);
   _linefill($bottom_right,$bottom_left,\@queue,0,\%visited,4,$depth,0);
   _linefill($bottom_left_left,$upper_left_left,\@queue,1,\%visited,1,$depth,1);
   _linefill($upper_left_up,$upper_right_up,\@queue,1,\%visited,2,$depth,1);
   _linefill($upper_right_right,$bottom_right_right,\@queue,1,\%visited,3,$depth,1);
   _linefill($bottom_right_down,$bottom_left_down,\@queue,1,\%visited,4,$depth,1);
#
#  $queue is a FIFO containing indices that exist in the $agrid hash. Initially,
#  all indices along the edge of the rectangle-shaped area comprising $agrid are found
#  in $queue.  The loop below removes indices from $agrid that are not found in $gridref.
#  If removed, neighbouring indices are added to $queue if they are not already visited.
#
#  Since indices in the $agrid rectangle are visited from the edge and against the
#  center, and since the processing stops at indices found in $gridref, indices
#  corresponding to the internal area of the polygon are not removed.
#
   my $ix = shift(@queue);
   while (defined $ix) {
      $visited{$ix} = 1;
      if (!exists($gridref->{$ix})) {
         delete($agrid->{$ix});
         foreach my $direction (1 .. 4) {
            my $nextix = _neighbour($ix,$direction,$depth);
            if ($nextix >= 0 && !exists($visited{$nextix})) {
               if (!grep($_ == $nextix, @queue)) {
                  push (@queue,$nextix);
               }
            }
         }
      }
      $ix = shift(@queue);
   }
#
#  Add the $agrid keys to $self->{GRID}:
#
   my $selfgrid = $self->{GRID};
   foreach my $ix1 (keys %$agrid) {
      $selfgrid->{$ix1} = 1;
   }
}

sub _linefill {
   my ($from,$to,$queue,$mark,$visited,$direction,$depth,$incend) = @_;

   if ($from < 0 || $to < 0) {return}
   my $counter = 0;
   for (my $ix = $from; $ix != $to; $ix = _neighbour($ix,$direction,$depth)) {
      if (++$counter > 5000 || $ix < 0) {
         die "_linefill: counter ix = $counter $ix Unable to find end of line\n";
         return;
      }
      if ($mark) {
         $visited->{$ix} = 1;
      } else {
         push (@$queue,$ix);
      }
   }
   if ($incend) {
      if ($mark) {
         $visited->{$to} = 1;
      } else {
         push (@$queue,$to);
      }
   }
}

sub _neighbour {
   my ($index,$direction,$depth) = @_;
   my @digits = ();
   while ($index > 0) {
      push (@digits,($index-1)%4+1);
      $index = int(($index-1)/4);
   }
   my $origindex = join("",reverse @digits);
   my @newdigits = ();
   my $copyrest = 0;
   if ($direction == 1) { # UP
      foreach my $dig (@digits) {
         if ($copyrest) {
            push (@newdigits,$dig);
            next;
         }
         if ($dig == 1) {push (@newdigits,3)}
         if ($dig == 2) {push (@newdigits,4)}
         if ($dig == 3) {push (@newdigits,1)}
         if ($dig == 4) {push (@newdigits,2)}
         if ($dig == 3 || $dig == 4) {$copyrest = 1}
      }
   } elsif ($direction == 2) { # RIGHT
      foreach my $dig (@digits) {
         if ($copyrest) {
            push (@newdigits,$dig);
            next;
         }
         if ($dig == 1) {push (@newdigits,2)}
         if ($dig == 2) {push (@newdigits,1)}
         if ($dig == 3) {push (@newdigits,4)}
         if ($dig == 4) {push (@newdigits,3)}
         if ($dig == 1 || $dig == 3) {$copyrest = 1}
      }
   } elsif ($direction == 3) { # DOWN
      foreach my $dig (@digits) {
         if ($copyrest) {
            push (@newdigits,$dig);
            next;
         }
         if ($dig == 1) {push (@newdigits,3)}
         if ($dig == 2) {push (@newdigits,4)}
         if ($dig == 3) {push (@newdigits,1)}
         if ($dig == 4) {push (@newdigits,2)}
         if ($dig == 1 || $dig == 2) {$copyrest = 1}
      }
   } elsif ($direction == 4) { # LEFT
      foreach my $dig (@digits) {
         if ($copyrest) {
            push (@newdigits,$dig);
            next;
         }
         if ($dig == 1) {push (@newdigits,2)}
         if ($dig == 2) {push (@newdigits,1)}
         if ($dig == 3) {push (@newdigits,4)}
         if ($dig == 4) {push (@newdigits,3)}
         if ($dig == 2 || $dig == 4) {$copyrest = 1}
      }
   }
   if ($copyrest == 0) {
      return (-1);
   }
   $index = 0;
   foreach my $dig (reverse @newdigits) {
      $index = $index*4 + $dig;
   }
   my $newindex = join("",reverse @newdigits);
   return $index;
}

sub _add_index () {
   my ($self, $gridref, $x1, $y1, $x2, $y2) = @_;
   if ($x2 < $x1) {
      my $xswap = $x2;
      $x2 = $x1;
      $x1 = $xswap;
   }
   if ($y2 < $y1) {
      my $yswap = $y2;
      $y2 = $y1;
      $y1 = $yswap;
   }
   my $ixstart = POSIX::floor(($x1 - $self->{XMIN}) / $self->{XSTEP});
   my $ixstop = POSIX::floor(($x2 - $self->{XMIN}) / $self->{XSTEP});
   my $iystart = POSIX::floor(($self->{YMAX} - $y1) / $self->{YSTEP});
   my $iystop = POSIX::floor(($self->{YMAX} - $y2) / $self->{YSTEP});
   my $ilength = $self->{DEPTH} - 1;
   for (my $ix=$ixstart; $ix <= $ixstop; $ix++) {
      for (my $iy=$iystart; $iy >= $iystop; $iy--) {
         my $icommon = _compute_index($ilength,$ix,$iy);
         $gridref->{$icommon} = 1;
      }
   }
}

sub _add_line () {
   my ($self, $gridref, $ix1, $iy1, $ix2, $iy2) = @_;
   my $ilength = $self->{DEPTH} - 1;
   my $rowwise;
   my $currentlength;
   my $partcount;
   if (abs($ix1-$ix2) <= abs($iy1-$iy2)) {
      $rowwise = 0;
      $currentlength = abs($iy1-$iy2) + 1;
      $partcount = abs($ix1-$ix2) + 1;
   } else {
      $rowwise = 1;
      $currentlength = abs($ix1-$ix2) + 1;
      $partcount = abs($iy1-$iy2) + 1;
   }
   my $iydir = 1;
   if ($iy2 < $iy1) {
      $iydir = -1;
   }
   my $ixdir = 1;
   if ($ix2 < $ix1) {
      $ixdir = -1;
   }
   my $iy = $iy1;
   my $ix = $ix1;
   while ($currentlength > 0) {
      my $partlength = int(($currentlength + 0.5)/$partcount);
      $currentlength -= $partlength;
      for (my $i1=0; $i1 < $partlength; $i1++) {
         my $index;
         if ($rowwise == 1) {
            my $ixut = $ix+$ixdir*$i1;
            $index = _compute_index($ilength,$ix+$ixdir*$i1,$iy);
         } else {
            my $iyut = $iy+$iydir*$i1;
            $index = _compute_index($ilength,$ix,$iy+$iydir*$i1);
         }
         $gridref->{$index} = 1;
      }
      $partcount--;
      if ($rowwise == 1) {
         $iy += $iydir;
         $ix += $partlength*$ixdir;
      } else {
         $ix += $ixdir;
         $iy += $partlength*$iydir;
      }
   }
}

sub _get_ixiy () {
   my ($self,$xval,$yval) = @_;
   my $ix = int(($xval - $self->{XMIN}) / $self->{XSTEP});
   my $iy = int(($self->{YMAX} - $yval) / $self->{YSTEP});
   return ($ix *10000) + $iy;
}

sub _add_to_points () {
   my ($self,$pointsref,$ixiy) = @_;
   if (defined($ixiy)) {
      my $ix = POSIX::floor(($ixiy+0.001)/10000);
      my $iy = $ixiy % 10000;
      if (scalar @$pointsref > 0) {
         my $ixprev = $pointsref->[-1]->[0];
         my $iyprev = $pointsref->[-1]->[1];
         if (defined($ixprev) && $ixprev == $ix && $iyprev == $iy ) {
            return;
         }
      }
      push(@$pointsref,[$ix,$iy]);
   } else {
      push(@$pointsref,[undef,undef]);
   }
}

sub get_index () {
   my ($self,$xval,$yval) = @_;
   my $ix = int(($xval - $self->{XMIN}) / $self->{XSTEP});
   my $iy = int(($self->{YMAX} - $yval) / $self->{YSTEP});
   my $ilength = $self->{DEPTH} - 1;
   return _compute_index($ilength,$ix,$iy);
}

sub _compute_index () {
   my ($ilength,$ix,$iy) = @_;
   use integer;
   my $icommon = 0;
   for (my $k=0; $k < $ilength; $k++) {
      $icommon += (1 << (2*$k)) * (($ix & 1) + (($iy & 1) << 1) + 1);
      $ix >>= 1;
      $iy >>= 1;
   }
   return $icommon;
}

sub _report_border () {
   my ($borederref,$previxiy,$currentixiy) = @_;
   print "BORDER: ";
   foreach my $ixiy (@$borederref) {
      print "$ixiy, ";
   }
   if (defined($previxiy)) {
      print "$previxiy, ";
   }
   if (defined($currentixiy)) {
      print "$currentixiy, ";
   }
   print "\n";
}
1;
