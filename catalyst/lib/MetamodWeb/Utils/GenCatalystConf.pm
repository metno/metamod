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

    my $conf = Metamod::Config->instance();

    my %config = (
        "name"            => 'MetamodWeb',
        "Model::Metabase" => {
            "connect_info" => {
                "dsn"      => $conf->getDSN(),
                "user"     => _rget( $conf, 'PG_WEB_USER' ),
                "password" => _oget( $conf, 'PG_WEB_USER_PASSWORD' ),
            }
        },
        "Model::Userbase" => {
            "connect_info" => {
                "dsn"      => $conf->getDSN_Userbase(),
                "user"     => _rget( $conf, 'PG_WEB_USER' ),
                "password" => _oget( $conf, 'PG_WEB_USER_PASSWORD' ),
            }
        },
        'Plugin::SmartURI' => {
            'disposition' => 'relative',        # application-wide
            'uri_class'   => 'URI::SmartURI'    # by default
            }

    );

    if ( my $ldap = _oget( $conf, 'LDAP_SERVER' ) ) {

        $config{"authentication"} = {
            "default_realm" => "ldap",
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
                        "user_basedn"         => _rget( $conf, 'LDAP_BASE_DN' ),
                        "user_filter"         => "(uid=%s)",
                        "user_field"          => "uid",
                        "user_search_options" => { "deref" => "always" },
                        "use_roles"           => 0
                    },
                }
            }
        };
    } else {

        # we do not have LDAP authentication we assume database authentication instead

        $config{"authentication"} = {
            "default_realm" => "dbix",
            "realms"        => {
                "dbix" => {
                    "credential" => {
                        "class"              => "Password",
                        "password_field"     => "u_password",
                        "password_type"      => "hashed",
                        "password_hash_type" => "SHA-1",
                    },
                    "store" => {
                        "class"         => "DBIx::Class",
                        "user_model"    => "Userbase::Usertable",
                        "id_field"      => "u_loginname",
                        "role_relation" => 'roles',
                        "role_field"    => 'role',
                    }
                }
            }
        };

    }

    return %config;

}

# private helper functions - not for export

sub _rget {    # required get
    my $conf = shift;
    my $key  = shift or die "Missing config key param";
    my $val  = eval { $conf->get($key); };
    die "Missing config $key in master_config" unless $val;
    return $val;
}

sub _oget {    # optional get
    my $conf = shift;
    my $key  = shift or die "Missing config key param";
    my $val  = $conf->has($key) ? $conf->get($key) : undef;
    return $val;
}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
