=begin licence

----------------------------------------------------------------------------
METAMOD - Web portal for metadata search and upload

Copyright (C) 2013 met.no

Contact information:
Norwegian Meteorological Institute
Box 43 Blindern
0313 OSLO
NORWAY
email: geira@met.no

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

=end licence

=cut

=head1 NAME

Metamod::Config::Sanity - sanity check the configuration environment

=head1 SYNOPSIS

  use Metamod::Config::Sanity;

...

=head1 DESCRIPTION

Checks the most important variables are set correctly.

=head1 FUNCTIONS

=cut

package Metamod::Config::Sanity;
#use Data::Dumper;
use Exporter;
@EXPORT = qw(check); # FIXME

use strict;
#use warnings;

use Metamod::Config;
use Test::More;
use Data::Validate::Email qw(is_email);

sub check {
    my $conf = Metamod::Config->new();
    printf "Testing config in %s\n", $conf->config_dir;
    my $vars = $conf->getall;
    my $flags = $conf->getallflags;
    #print Dumper \$vars;

    # required files/dirs
    ok( -d $conf->config_dir, 'config directory found');
    ok( -w $$vars{WEBRUN_DIRECTORY}, 'WEBRUN_DIRECTORY is writable' );
    ok( -d $$vars{CATALYST_LIB}, 'CATALYST_LIB found' );
    ok( -d $$vars{INSTALLATION_DIR}, 'INSTALLATION_DIR found' );
    ok( -e $$vars{PG_POSTGIS_SYSREF_SCRIPT}, 'PG_POSTGIS_SYSREF_SCRIPT found' );
    ok( -e $$vars{PG_POSTGIS_SCRIPT}, 'PG_POSTGIS_SCRIPT found' );

    # required directives
    ok( $$vars{SERVER}, 'SERVER is set' );
    ok( $$vars{PG_ADMIN_USER}, 'PG_ADMIN_USER is set' );
    ok( $$vars{PG_WEB_USER}, 'PG_WEB_USER is set' );
    ok( $$vars{DATABASE_NAME}, 'DATABASE_NAME is set' );
    ok( $$vars{USERBASE_NAME}, 'USERBASE_NAME is set' );
    ok( $$vars{PG_WEB_USER}, 'PG_WEB_USER is set' );
    ok( $$vars{OPERATOR_EMAIL}, 'OPERATOR_EMAIL is set' );
    ok( $$vars{DATASET_TAGS}, 'DATASET_TAGS is set' );
    ok( $$vars{APPLICATION_ID}, 'APPLICATION_ID is set' );
    ok( $$vars{UPLOAD_OWNERTAG}, 'UPLOAD_OWNERTAG is set' );

    # obsolete directives
    #is( $$vars{},                undef, ' is obsolete' );
    is( $$vars{METADATA_SEARCH_URL},        undef, 'METADATA_SEARCH_URL is obsolete' );
    is( $$vars{UPLOAD_URL},                 undef, 'UPLOAD_URL is obsolete' );
    is( $$vars{PHPLOGLEVEL},                undef, 'PHPLOGLEVEL is obsolete' );
    is( $$vars{PHPLOGFILE},                 undef, 'PHPLOGFILE is obsolete' );
    is( $$vars{PG_CONNECTSTRING_PHP},       undef, 'PG_CONNECTSTRING_PHP is obsolete' );
    is( $$vars{QUEST_METADATA_UPLOAD_FORM}, undef, 'QUEST_METADATA_UPLOAD_FORM is obsolete' );
    is( $$vars{QUEST_SENDER_ADDRESS},       undef, 'QUEST_SENDER_ADDRESS is obsolete' );
    is( $$vars{QUEST_RECIPIENTS},           undef, 'QUEST_RECIPIENTS is obsolete' );
    is( $$vars{QUEST_OKMESSAGE},            undef, 'QUEST_OKMESSAGE is obsolete' );
    is( $$vars{QUEST_FORM_DEFINITON_FILE},  undef, 'QUEST_FORM_DEFINITON_FILE is obsolete' );
    is( $$vars{QUEST_ADM_BACKGROUND},       undef, 'QUEST_ADM_BACKGROUND is obsolete' );
    is( $$vars{QUEST_ADM_TOPDIR},           undef, 'QUEST_ADM_TOPDIR is obsolete' );
    is( $$vars{QUEST_FORM_DEFINITON_FILE},  undef, 'QUEST_FORM_DEFINITON_FILE is obsolete' );
    is( $$vars{QUEST_CONFIG_DIRECTORY},     undef, 'QUEST_CONFIG_DIRECTORY is obsolete' );

    ok( is_email($$vars{OPERATOR_EMAIL}),   'OPERATOR_EMAIL is a valid email address' );

    done_testing();

}

1;
