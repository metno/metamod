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

    use Metamod::Config::Sanity qw(check);
    my $conf =  Metamod::Config->new( $configfile, { nolog => 1 } );
    Metamod::Config::Sanity::check($conf);

=head1 DESCRIPTION

Checks the most important variables are set correctly, and deprecated
variables unset. Prints TAP output, can be used as unit test.

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

=head2 check( [$filename] )

Run tests on config singleton, optionally given path to master_config.txt explicitly

=cut

sub check {
    my $conf = shift || Metamod::Config->new();
    printf "# Testing config in %s\n", $conf->config_dir;
    my $vars = $conf->getall;
    my $flags = $conf->getallflags;
    #print Dumper \$vars;

    # required files/dirs - FIXME: move to separate function so can be run before prepare_runtime_env.sh
    ok( -d $conf->config_dir, 'config directory found');
    ok( -w $$vars{WEBRUN_DIRECTORY}, "WEBRUN_DIRECTORY is writable: $$vars{WEBRUN_DIRECTORY}" );
    ok( -w $$vars{UPLOAD_DIRECTORY}, "UPLOAD_DIRECTORY is writable: $$vars{UPLOAD_DIRECTORY}" );
    ok( -d $$vars{CATALYST_LIB}, "CATALYST_LIB found: $$vars{CATALYST_LIB}" );
    ok( -d $$vars{INSTALLATION_DIR}, "INSTALLATION_DIR found: $$vars{INSTALLATION_DIR}"  );
    ok( -e $$vars{PG_POSTGIS_SYSREF_SCRIPT}, 'PG_POSTGIS_SYSREF_SCRIPT found' );
    ok( -e $$vars{PG_POSTGIS_SCRIPT}, 'PG_POSTGIS_SCRIPT found' );
    ok( -x $$vars{FIMEX_PROGRAM} || !defined($$vars{FIMEX_PROGRAM}), "FIMEX_PROGRAM executable: $$vars{FIMEX_PROGRAM}"  );

    # required directives
    ok( $$vars{SERVER},         'SERVER is set' );
    ok( $$vars{PG_ADMIN_USER},  'PG_ADMIN_USER is set'  );
    ok( $$vars{PG_WEB_USER},    'PG_WEB_USER is set'    );
    ok( $$vars{DATABASE_NAME},  'DATABASE_NAME is set'  );
    ok( $$vars{USERBASE_NAME},  'USERBASE_NAME is set'  );
    ok( $$vars{PG_WEB_USER},    'PG_WEB_USER is set'    );
    ok( $$vars{OPERATOR_EMAIL}, 'OPERATOR_EMAIL is set' );
    ok( $$vars{DATASET_TAGS},   'DATASET_TAGS is set'   ); #diag($$vars{DATASET_TAGS});
    ok( $$vars{APPLICATION_ID}, 'APPLICATION_ID is set' ); #diag($$vars{APPLICATION_ID});
    ok( $$vars{UPLOAD_OWNERTAG},'UPLOAD_OWNERTAG is set'); #diag($$vars{UPLOAD_OWNERTAG});
    ok( $$vars{SRID_ID_COLUMNS},'SRID_ID_COLUMNS is set'); #diag($$vars{SRID_ID_COLUMNS});
    ok( $$vars{SRID_ID_NAMES},  'SRID_ID_COLUMNS is set'); #diag($$vars{SRID_ID_NAMES});
    is( scalar @{ $conf->split('SRID_ID_COLUMNS') },
        scalar @{ $conf->split('SRID_ID_NAMES')   }, 'Equal number of SRID columns and names' );

    is( ( grep { $$vars{$_} eq 'Substituted by test_application.sh' } keys %$vars ), 0, '"Substituted by test_application.sh" not present');

    # obsolete directives
    #is( $$vars{},                undef, ' is obsolete' );
    is( $$vars{BASE_DIRECTORY},             undef, 'BASE_DIRECTORY is obsolete' );
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
    is( $$vars{PMH_PORT_NUMBER},            undef, 'PMH_PORT_NUMBER is obsolete' );
    is( $$vars{PMH_CONTENT_TYPE},           undef, 'PMH_CONTENT_TYPE is obsolete' );

    ok( is_email($$vars{OPERATOR_EMAIL}) || $$vars{OPERATOR_EMAIL} eq 'root@localhost',
        'OPERATOR_EMAIL is a valid email address' );

    done_testing();

}

1;

=head1 AUTHOR

Geir Aalberg, E<lt>geira@met.noE<gt>

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=head1 SEE ALSO

L<Metamod::Config>

=cut
