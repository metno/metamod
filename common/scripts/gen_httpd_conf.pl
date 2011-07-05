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
use Getopt::Std;

our $opt_p; # print to stdout
getopts('p');
my $appdir = shift @ARGV or usage();

my $mm_config = Metamod::Config->new("$appdir/master_config.txt");
my $source = $mm_config->get('SOURCE_DIRECTORY');
my $target = $mm_config->get('TARGET_DIRECTORY');
my $webrun = $mm_config->get('WEBRUN_DIRECTORY');
my $conf_file = "$target/etc/httpd.conf";
my $virtualhost = $mm_config->get('VIRTUAL_HOST');
my $local = $mm_config->get('LOCAL_URL');
my $base = $mm_config->get('BASE_PART_OF_EXTERNAL_URL');
my $port = $mm_config->get('CATALYST_PORT');
my $operator_email = $mm_config->get('OPERATOR_EMAIL');

my %obsolete = (
    sch => '/search',
    upl => '/upload',
    qst => '/editor',
);

my $old_redirect = "";

if ( $mm_config->has('OLD_REDIRECT') ) {
    my $prefix =  $mm_config->get('OLD_REDIRECT');

    foreach ( keys %obsolete ) {
        $old_redirect .= "RedirectMatch   301     /$prefix/$_     $base$local$obsolete{$_}\n";
    }
}


my $site = $local;
$site .= " on $virtualhost" if $virtualhost;
my $config_dir = $virtualhost ? "/etc/apache/sites-available" : "/etc/apache2/conf.d";

# running catalyst from target or source?
my $from_target = $Bin eq "$target/scripts";
my %paths = $from_target ?
    ( root => "$target/lib/MetamodWeb/root" ) :
    ( root => "$source/catalyst/root" );

my $conf_text = <<EOT;
#
# Autogenerated httpd config stub for Metamod application $site
# Copy/link this file to $config_dir

# NOTE: use EITHER sites-available (if using virtual hostnames in DNS) OR conf.d (with path prefix).
# DO NOT PUT PARTIAL METAMOD CONFIGURATION IN BOTH!!!!!

# --------------
# Catalyst proxy settings

<Proxy *>
    Order deny,allow
    Allow from all
</Proxy>

# static doesn't work due to the way custom files is implemented in metamod 2.8
#ProxyPass           $local/static   !

ProxyPass           $local/pmh      !
ProxyPass           $local/upl      !

ProxyPass           $local/         http://127.0.0.1:$port/
ProxyPassReverse    $local/         http://127.0.0.1:$port/

# broken - generates infinite redirect loop
#Redirect seeother   $local          $base$local/

# -----------
# Plain Apache settings

$old_redirect

# OAI-PMH still running PHP
Alias               $local/pmh      $target/htdocs/pmh

# static files should be served directly from Apache
#Alias               $local/static   $paths{root}/static

# ditto for error reports (which has a hardcoded url)
Alias               $local/upl/uerr $webrun/upl/uerr

# if you don't want the default favicon, put custom file in applic-dir and update filelist.txt
# FIXME: make custom icon per app
#Alias               favicon.ico     $paths{root}/favicon.ico

<Directory $target/htdocs>
    Options Indexes FollowSymLinks MultiViews
    AddDefaultCharset UTF-8
    #AllowOverride None
    Order allow,deny
    allow from all
</Directory>
EOT

if ($virtualhost) {
    my $serveralias = ( $virtualhost =~ /^([^.]+)/ ) ? "ServerAlias $1" : '';
    $conf_text = <<EOT2;
<VirtualHost *>

ServerName $virtualhost
$serveralias
ServerAdmin $operator_email
$conf_text

</VirtualHost>
EOT2

}

if ($conf_file && !$opt_p) {
    open FH, ">$conf_file" or die "Cannot open $conf_file for writing";
    print STDERR "Writing Apache config to $conf_file\n";
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

The generated file is written to $target/etc/httpd.conf, or stdout if using -p.

=head1 USAGE

=head2 Running script from source

 trunk/gen_httpd_conf.pl application_directory

This will assume you want to proxy Apache against Catalyst running from trunk

=head2 Running script from target

 target/gen_httpd_conf.pl .

This will assume you want to proxy Apache against Catalyst running from target

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
