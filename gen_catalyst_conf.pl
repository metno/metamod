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
use lib "$Bin/common/lib";
use lib "$Bin/catalyst/lib";
use Metamod::Config;
use MetamodWeb::Utils::GenCatalystConf;
use Getopt::Std;
use JSON;

our $opt_p; # print to stdout
getopts('p');
my $appdir = shift @ARGV or usage();

my $gen_conf = MetamodWeb::Utils::GenCatalystConf->new( master_config_dir => $appdir );
my $mm_config = $gen_conf->mm_config();

my $catalyst_conf = $gen_conf->catalyst_conf();

# don't check for output file if printing to stderr (to avoid warning)
my $conf_file = $opt_p ? undef : $mm_config->get('CATALYST_SITE_CONFIG');

if ($conf_file) {
    print STDERR "Writing Catalyst config to $conf_file...\n";
    open my $FH, ">$conf_file" or die "Cannot open $conf_file for writing";
    print $FH $catalyst_conf;
} else {
    print $catalyst_conf;
}

sub usage {
    print STDERR "Usage: [-p] $0 application_directory\n";
    exit (1);
}

=head1 NAME

B<gen_httpd_conf.pl> - Apache config generator for Metamod

=head1 DESCRIPTION

This utility generates a stub Apache config to be placed somewhere in sites-available
or conf.d.

=head1 USAGE

 trunk/gen_httpd_conf.pl application_directory

=head1 OPTIONS

=head2 Parameters

=over 4

=item -p

Prints output to stdout regardless of setting in master_config.

=item application_directory

'application_directory' is the name of a directory containing the application
specific files. Inside this directory, there must be a master_config.txt file.

=back

=head1 LICENSE

Copyright (C) 2010 The Norwegian Meteorological Institute.

METAMOD is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

=cut
