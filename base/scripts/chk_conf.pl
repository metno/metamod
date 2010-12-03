#!/usr/bin/perl -w

=begin LICENCE

----------------------------------------------------------------------------
  METAMOD - Web portal for metadata search and upload

  Copyright (C) 2008 met.no

  Contact information:
  Norwegian Meteorological Institute
  Box 43 Blindern
  0313 OSLO
  NORWAY
  email: egil.storen@met.no

  This file is part of METAMOD

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
----------------------------------------------------------------------------

=end LICENCE

=cut

use strict;
use warnings;
use Getopt::Std;

our $opt_v; # verbose
our $opt_c; # count
getopts('cv');

my $orig = shift @ARGV or usage();
my $cust = shift @ARGV;

my %vars;

open ORIG, $orig or die "Can't open file '$orig'";
while (<ORIG>) {
    $vars{$1} = 1 if /^([A-Z_]+) =/;
}

if ($cust) {

    open CUST, $cust or die "Can't open file '$cust'";
    while (<CUST>) {
        if ( /^([A-Z_]+) =/ ) {
            if ($vars{$1}) {
                printf "+%s\n", $1 if $opt_v;
            } else {
                printf "-%s\n", $1;
            }
        }
    }

} else {

    if ($opt_c) {
        printf "%d directives in %s\n", scalar keys %vars, $orig;
    } else {
        for (sort keys %vars) {
            print "$_\n";
        }
    }

}

# END ####################################

sub usage {
    print STDERR "Usage: $0 [-v] auth_master_config [my_master_config]\n";
    exit (1);
}

=head1 NAME

B<chk_conf.pl> - check METAMOD master_config

=head1 DESCRIPTION

Given one parameter, it lists all the configuration directives in the file.

Given two parameters, it checks that all the directives in the former file
(normally B<app/example/master_config.txt>)  is present in the latter.

=head1 USAGE

 chk_conf.pl [-v] file1 [file2]

=head1 OPTIONS

=head2 Parameters

=over 4

=item -v

Verbose - lists both present and missing directives

=item file1

=item file2

Path to master_config files (the first one being the authorative)

=back

=head1 LICENSE

Copyright (C) 2010 The Norwegian Meteorological Institute.

METAMOD is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

=cut
