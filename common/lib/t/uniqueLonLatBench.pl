#! /usr/bin/perl
use strict;
use warnings;
use Benchmark;
use lib '..';
use Metamod::LonLatPoint;
use PDL::Lite;


my @lon = (-180..180);
my @lat = (-90..90);
my @points;
foreach my $lon (@lon) {
    foreach my $lat (@lat) {
        push @points, new Metamod::LonLatPoint($lon, $lat);
    }
}
#@points = (@points, @points);

timethese(100, {
    #'lonlat->unique' => sub {Metamod::LonLatPoint::unique(@points);}, # 35s
    #'sortUniq' => sub {sortUniq(@points);},                           # 16s
#    'uniq2dimInt' => sub {uniq2dimInt(@points);},                      # 12s
#    'uniq2dimStr' => sub {uniq2dimStr(@points);},                      # 22s
#    'uniq2dimIntRelax' => sub {uniq2dimIntRelax(@points);},            #  5s
    'uniq2dimInt2' => sub {uniq2dimInt2(@points);},                     # 10s
    'uniq2dimPdl' => sub {uniq2dimPdl(@points);},                       # 9s
#    'uniq1dimStr' => sub {uniq1dimStr(@points);},                      # 20s
#    'uniq1dimStr2' => sub {uniq1dimStr2(@points);},                     # 15s
#    'uniqEncode'   => sub {uniqEncode(@points);},                      # 13s
#    'uniqEncode2dim' => sub {uniqEncode2dim(@points);},                # 10s
#    'uniqEncode1dimStr' => sub {uniqEncode1dimStr(@points);},           # 13s  
#    'uniq1dimStr3' => sub {uniq1dimStr3(@points);},                     # 16s
#    'uniqEncode1dimStr2' => sub {uniqEncode1dimStr2(@points);},           # 12s  
});

sub uniq1dimStr {
    my %uniq;
    return map {$uniq{sprintf "%.2f %.2f", @$_}++ ? () : ($_)} @_;
}
sub uniqEncode1dimStr2 {
    my %uniq;
    return map {$uniq{int($_->[0]*100+(18000.5)) . int($_->[1]*100+(9000.5))}++ ? () : $_} @_;
}
sub uniqEncode1dimStr {
    my %uniq;
    return map {$uniq{int(($_->[1]+90.005)*100).int(($_->[0]+180.005)*100)}++ ? () : $_} @_;
}

sub uniq1dimStr3 {
    my %uniq;
    return map {$uniq{int($_->[0]*100+(($_->[0] > 0) ? .5 : -.5)) . int($_->[1]*100+(($_->[1] > 0) ? .5 : -.5))}++ ? () : $_} @_;
}


sub uniq1dimStr2 {
    my %uniq;
    return map {$uniq{int($_->[0]*100+(.5* ($_->[0] <=> 0))) . int($_->[1]*100+(.5* ($_->[1] <=> 0)))}++ ? () : $_} @_;
}

sub uniqEncode2dim {
    my %uniq;
    return map {$uniq{int(($_->[1]+90.005)*100)}{int(($_->[0]+180.005)*100)}++ ? () : $_} @_;
}

sub uniq2dimInt {
    my %uniq;
    return map {$uniq{int($_->[0]*100+(.5* ($_->[0] <=> 0)))}{int($_->[1]*100+(.5* ($_->[1] <=> 0)))}++ ? () : ($_)} @_;
}

sub uniq2dimPdl {
    my $p = PDL::float(\@_);
    $p += 180.005;
    $p *= 100;
    $p = $p->long;
    $p = $p->uniq->float;
    $p -= 180;
    $p /= 100;
    
    my @lon = $p->slice("0,:")->list;
    my @lat = $p->slice("0,:")->list;
    my @out;
    foreach my $lon (@lon) {
        push @out, bless [$lon, shift @lat], 'Metamod::LonLatPoint'; 
    }
    return @out;
}

sub uniq2dimInt2 {
    my %uniq;
    return map {$uniq{int($_->[0]*100+(($_->[0] > 0) ? .5 : -.5))}{int($_->[1]*100+(($_->[0] > 0) ? .5 : -.5))}++ ? () : ($_)} @_;
}


# this code compares partially wrong (only int, not round)
sub uniq2dimIntRelax {
    my %uniq;
    return map {$uniq{int($_->[0]*100)}{int($_->[1]*100)}} @_;
}

sub uniq2dimStr {
    my %uniq;
#    my $format = '%.'.Metamod::LonLatPoint->DEC_ACCURACY.'f';
    return map {$uniq{sprintf("%f", $_->[0])}{sprintf("%f", $_->[1])}++ ? () : ($_)} @_;
}

sub sortUniq {
    # sort by lon
    my @p = sort {$a->[0] <=> $b->[0]} @_;
    my @out;
    my @equalLon = (shift @p);
    my $iEqualLon = int($equalLon[0]->[0]*100+.5);
    foreach my $p (@p) {
        my $iP = int($p->[0]*100+.5); 
        if ($iP == $iEqualLon) {
            push @equalLon, $p;
        } else {
            # new class of lons
            # hash with unique lat-values
            push @out, uniqLat(@equalLon);
            # reinit @equalLon
            @equalLon = ($p);
            $iEqualLon = $iP;
        }
    }
    # work on the remaining values
    push @out, uniqLat(@equalLon);

    return @out;
}

sub uniqLat {
    my %lat = map {int($_->[1]*100+.5) => $_} @_;
    return values %lat;
}