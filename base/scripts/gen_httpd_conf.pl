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
use Getopt::Std;

our $opt_p; # print to stdout
getopts('p');
my $appdir = shift @ARGV or usage();

my $mm_config = Metamod::Config->new("$appdir/master_config.txt");
my $source = $mm_config->get('SOURCE_DIRECTORY');
my $target = $mm_config->get('TARGET_DIRECTORY');
my $conf_file = "$target/etc/httpd";
my $virtualhost = $mm_config->get('VIRTUAL_HOST');
my $local = $mm_config->get('LOCAL_URL');
my $base = $mm_config->get('BASE_PART_OF_EXTERNAL_URL');
my $port = $mm_config->get('CATALYST_PORT');

my $site = $local;
$site .= " on $virtualhost" if $virtualhost;
my $config_dir = $virtualhost ? "/etc/apache/sites-available" : "/etc/apache2/conf.d";

my $conf_text = <<EOT;

#
# Autogenerated httpd config stub for Metamod application $site
# Copy/link til file to your $config_dir directory

# (none yet since all handled by catalyst)

# --------------
# Catalyst proxy settings

<Proxy *>
    Order deny,allow
    Allow from all
</Proxy>

ProxyPass           $local/search http://127.0.0.1:$port/search
ProxyPassReverse    $local/search http://127.0.0.1:$port/search

# static files should be served directly from Apache
Alias               $local/static   $target/lib/MetamodWeb/root/static
# or if running from source (during devel)
#Alias              $local/static   $source/catalyst/root/static

# -----------
# The remaining lines are used when installing to a clean Apache
# DO NOT USE if you've already configured your server manually
# (including using symlinks to specify htdocs dir) - you have to
# figure out what each directive means and copy/change what you need.

Alias $local	$target/htdocs

<Directory $target/htdocs>
    Options Indexes FollowSymLinks MultiViews
    AddDefaultCharset UTF-8
    #AllowOverride None
    Order allow,deny
    allow from all
</Directory>

EOT

=begin OLD

#
# Autogenerated httpd config stub for Metamod application $site
# Copy/link til file to your $config_dir directory

ScriptAlias     $local/sch/wmsthmb  $target/cgi-bin/wmsthmb.pl
ScriptAlias     $local/sch/gc2wmc   $target/cgi-bin/gc2wmc.pl

# note slash after "feed"
ScriptAlias     $local/sch/feed/    $target/cgi-bin/feed.pl/
RedirectMatch   $local/sch/feed\$   $base$target/sch/feed/

# The remaining lines are used when installing to a clean Apache
# DO NOT USE if you've already configured your server manually
# (including using symlinks to specify htdocs dir)!

Alias $local	$target/htdocs

<Directory $target/htdocs>
    Options Indexes FollowSymLinks MultiViews
    AddDefaultCharset UTF-8
    #AllowOverride None
    Order allow,deny
    allow from all
</Directory>

EOT

=cut

if ($virtualhost) {
    $conf_text = "<VirtualHost $virtualhost>\n\n" . $conf_text . "</VirtualHost>\n"
}

if ($conf_file && !$opt_p) {
    open FH, ">$conf_file" or die "Cannot open $conf_file for writing";
    print FH $conf_text;
} else {
    print $conf_text;
}

sub usage {
    print STDERR "Usage: $0 [-p] application_directory\n";
    exit (1);
}

=head1 NAME

B<gen_httpd_conf.pl> - Apache config generator for Metamod

=head1 DESCRIPTION

This utility generates a stub Apache config to be placed somewhere in sites-available
(if using VirtualHosts) or conf.d (if using path to specify different sites).

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
