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
use JSON;

our $opt_p; # print to stdout
getopts('p');
my $appdir = shift @ARGV or usage();

my $mm_config = Metamod::Config->new("$appdir/master_config.txt");

my $json = JSON->new->allow_nonref;

my $config = {
    "name" => 'MetamodWeb',
    "Model::Metabase" => {
        "connect_info" => {
            "dsn" => "dbi:Pg:dbname=" . rget('DATABASE_NAME'),
            "user" => rget('PG_ADMIN_USER'),
            #"password" => "admin"
        }
    },
    "Model::Userbase" => {
        "connect_info" => {
            "dsn" => "dbi:Pg:dbname=" . rget('USERBASE_NAME'),
            "user" => rget('PG_ADMIN_USER'),
            #"password" => "admin"
        }
    },
    'Plugin::SmartURI' => {
        'disposition' => 'relative', # application-wide
        'uri_class' => 'URI::SmartURI' # by default
    }


};


if ( my $ldap = oget('LDAP_SERVER') ) {

    $$config{"authentication"} = {
        "default_realm" => "dbix",
        "realms" => {
            "ldap" => {
                "credential" => {
                    "class" => "Password",
                    "password_field" => "password",
                    "password_type" => "self_check"
                },
                "store" => {
                    "class" => "LDAP",
                    "ldap_server" => $ldap,
                    "ldap_server_options" => {
                        "timeout" => 30
                    },
                    "start_tsl" => 0,
                    "user_basedn" => rget('LDAP_BASE_DN'),
                    "user_filter" => "(uid=%s)",
                    "user_field" => "uid",
                    "user_search_options" => {
                        "deref" =>  "always"
                    },
                    "use_roles" => 0
                },
                "dbix" => {
                    "credential" => {
                        "class" => "Password",
                        "password_field" => "u_password",
                        "password_type" => "clear"
                    },
                    "store" => {
                        "class" => "DBIx::Class",
                        "user_model" => "Userbase::Usertable",
                        "id_field" => "u_loginname"
                    }
                }
            }
        }
    },
};

# don't check for output file if printing to stderr (to avoid warning)
my $conf_file = $opt_p ? undef : $mm_config->get('CATALYST_SITE_CONFIG');

if ($conf_file) {
    print STDERR "Writing Catalyst config to $conf_file...\n";
    open FH, ">$conf_file" or die "Cannot open $conf_file for writing";
    print FH $json->pretty->encode( $config );
} else {
    print $json->pretty->encode( $config );
}

# end

sub rget { # required get
    my $key = shift or die "Missing config key param";
    my $val = eval {
        $mm_config->get($key);
    };
    die "Missing config $key in master_config" unless $val;
    return $val;
}

sub oget { # optional get
    my $key = shift or die "Missing config key param";
    my $val = eval {
        $mm_config->get($key);
    };
    return $val;
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

=back

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
