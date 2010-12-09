package MetamodWeb::Utils::GenCatalystConf;

=begin LICENSE

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

=end LICENSE

=cut

use strict;
use warnings;

use FindBin;
use File::Spec;
use JSON;

use Metamod::Config;

=head1 NAME

MetamodWeb::Utils::GenCatalystConf - Generate a Catalyst configuration from the information found in the a master config.

=head1 DESCRIPTION

This module is used to auto-generate a Catalyst configuration file based on the
information found in a master config file. It is the intention that the
generated Catalyst configuration should be used with out any manually editing
afterwards.

=head1 FUNCTIONS

=cut

=head2 catalyst_config()

Generate a Catalyst configuration in JSON format from the information found in
the master config file.

=over

=item return

Returns the Catalyst configuration as a JSON string.

=back

=cut

sub catalyst_conf {

    my $conf = Metamod::Config->new();

    my $config = {
        "name"            => 'MetamodWeb',
        "Model::Metabase" => {
            "connect_info" => {
                "dsn"  => "dbi:Pg:dbname=" . _rget($conf,'DATABASE_NAME'),
                "user" => _rget($conf,'PG_ADMIN_USER'),

                #"password" => "admin"
            }
        },
        "Model::Userbase" => {
            "connect_info" => {
                "dsn"  => "dbi:Pg:dbname=" . _rget($conf,'USERBASE_NAME'),
                "user" => _rget($conf,'PG_ADMIN_USER'),

                #"password" => "admin"
            }
        },
        'Plugin::SmartURI' => {
            'disposition' => 'relative',        # application-wide
            'uri_class'   => 'URI::SmartURI'    # by default
            }

    };

    if ( my $ldap = _oget($conf,'LDAP_SERVER') ) {

        $$config{"authentication"} = {
            "default_realm" => "dbix",
            "realms"        => {
                "ldap" => {
                    "credential" => {
                        "class"          => "Password",
                        "password_field" => "password",
                        "password_type"  => "self_check"
                    },
                    "store" => {
                        "class"               => "LDAP",
                        "ldap_server"         => $ldap,
                        "ldap_server_options" => { "timeout" => 30 },
                        "start_tsl"           => 0,
                        "user_basedn"         => _rget($conf,'LDAP_BASE_DN'),
                        "user_filter"         => "(uid=%s)",
                        "user_field"          => "uid",
                        "user_search_options" => { "deref" => "always" },
                        "use_roles"           => 0
                    },
                    "dbix" => {
                        "credential" => {
                            "class"          => "Password",
                            "password_field" => "u_password",
                            "password_type"  => "clear"
                        },
                        "store" => {
                            "class"      => "DBIx::Class",
                            "user_model" => "Userbase::Usertable",
                            "id_field"   => "u_loginname"
                        }
                    }
                }
            }
        };
    }

    my $json = JSON->new->allow_nonref;
    return $json->pretty->encode( $config );
}

=head2 config_path()

=over

=item return

Returns the path where the configuration file should be stored depending if we
are in development or in production. Dies if it cannot determine the correct
path.

=back

=cut
sub config_path {

    my @dirs = File::Spec->splitdir($FindBin::Bin);

    my $last_dir = pop @dirs;
    if( $last_dir eq 'bin' ){
        # we are in a production environment
        return File::Spec->catfile( $FindBin::Bin, '..', 'lib', 'MetamodWeb', 'metamodweb.json' );
    } elsif( $last_dir eq 'script' ) {
        return File::Spec->catfile( $FindBin::Bin, '..', 'metamodweb.json' );
    } else {
        die "Cannot determine config path when not running script from bin/ or script/ dir"
    }

}

# private helper functions - not for export

sub _rget {    # required get
    my $conf = shift;
    my $key = shift or die "Missing config key param";
    my $val = eval { $conf->get($key); };
    die "Missing config $key in master_config" unless $val;
    return $val;
}


sub _oget {     # optional get
    my $conf = shift;
    my $key = shift or die "Missing config key param";
    my $val = eval { $conf->get($key); };
    return $val;
}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
