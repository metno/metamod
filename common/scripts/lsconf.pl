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

use FindBin qw($Bin);
use lib "$Bin/../../common/lib", , "$Bin/../lib";
use Metamod::Config;
use Getopt::Long;
use Data::Dumper;

my $config_file_or_dir;
my $split;
GetOptions('split' => \$split,
           'config=s' => \$config_file_or_dir,
) or usage();

if(!Metamod::Config->config_found($config_file_or_dir)){
    usage();
}

my $var = shift @ARGV;

my $vars;

my $mm_config = Metamod::Config->new($config_file_or_dir, { nolog => 1 } );

if (defined $var) {
    missing($var) unless $mm_config->has($var);
    if ($split) {
        $vars = $mm_config->split($var);
    } else {
        printf "%s=\"%s\"\n", $var, $mm_config->get($var);
    }
} else {
    $vars = $mm_config->getall();
}

foreach (sort keys %$vars) {
    my $val = $$vars{$_};
    #print Dumper $val;
    printf "$_=%s\n", ref $val ?
        '[ ' . join(', ', @$val) . ' ]' :
        "\"$val\"";
}

sub usage {
    print STDERR "Usage: $0 [--config <config file or dir>] [--split] [<variable>]\n";
    exit (1);
}

sub missing {
    my $var = shift or die;
    print STDERR "Variable $var is not defined\n";
    exit (1);
}

=head1 NAME

B<lsconf.pl> - list METAMOD config variables

=head1 DESCRIPTION

Given a variable name as parameter, list the computed value (optionally parsed as a hash if the --split option is used).

With no arguments, list all variables alphabetically.

=head1 USAGE

 chk_conf.pl [--config <file>] [--split] [variable]

=head1 LICENSE

Copyright (C) 2010 The Norwegian Meteorological Institute.

METAMOD is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

=cut
