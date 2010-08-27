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
use Metamod::Config;

my $appdir = shift @ARGV or die "Usage: $0 application_directory";

my $mm_config = Metamod::Config->new("$appdir/master_config.txt");
my $conf_file = $mm_config->get('APACHE_SITE_CONFIG');
my $target = $mm_config->get('TARGET_DIRECTORY');
my $local = $mm_config->get('LOCAL_URL');
my $base = $mm_config->get('BASE_PART_OF_EXTERNAL_URL');

my $conf_text = <<EOT;

ScriptAlias     $local/sch/wmsthmb  $target/cgi-bin/wmsthmb.pl
ScriptAlias     $local/sch/gc2wmc   $target/cgi-bin/gc2wmc.pl

# note slash after "feed"
ScriptAlias     $local/sch/feed/    $target/cgi-bin/feed.pl/
RedirectMatch   $local/sch/feed\$   $base$target/sch/feed/

Alias $local	$target/htdocs

<Directory $target/htdocs>
    Options Indexes FollowSymLinks MultiViews
    AllowOverride None
    Order allow,deny
    allow from all
</Directory>

EOT

print $conf_text;

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
