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

use Moose;
use warnings;

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

=head1 FUNCTIONS/METHODS

=cut

#
# The file name of the master config file.
#
has 'master_config_file' => ( is => 'ro', default => 'master_config.txt' );

#
# The directory where the master config file is located.
#
has 'master_config_dir' => ( is => 'ro', required => 1 );

#
# The Metamod::Config object for the specified master config
#
has 'mm_config' => ( is => 'ro', lazy => 1, builder => '_build_mm_config' );

sub _build_mm_config {
    my $self = shift;

    my $path = File::Spec->catfile( $self->master_config_dir, $self->master_config_file );
    return Metamod::Config->new($path);

}

=head2 $self->catalyst_config()

Generate a Catalyst configuration in JSON format from the information found in
the master config file.

=over

=item return

Returns the Catalyst configuration as a JSON string.

=back

=cut
sub catalyst_conf {
    my $self = shift;

    my $config = {
        "name"            => 'MetamodWeb',
        "Model::Metabase" => {
            "connect_info" => {
                "dsn"  => "dbi:Pg:dbname=" . $self->rget('DATABASE_NAME'),
                "user" => $self->rget('PG_ADMIN_USER'),

                #"password" => "admin"
            }
        },
        "Model::Userbase" => {
            "connect_info" => {
                "dsn"  => "dbi:Pg:dbname=" . $self->rget('USERBASE_NAME'),
                "user" => $self->rget('PG_ADMIN_USER'),

                #"password" => "admin"
            }
        },
        'Plugin::SmartURI' => {
            'disposition' => 'relative',        # application-wide
            'uri_class'   => 'URI::SmartURI'    # by default
            }

    };

    if ( my $ldap = $self->oget('LDAP_SERVER') ) {

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
                        "user_basedn"         => $self->rget('LDAP_BASE_DN'),
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
    return $json->pretty->encode( $config )
}

=head2 $self->rget($key)

Get a requird parameter from the master config.

This function will die if the key is not found in the master config.

=over

=item $key

The name of the key in the master config.

=item return

Returns the value of the key if exists. Dies on failure.

=back

=cut
sub rget {    # required get
    my $self = shift;

    my $key = shift or die "Missing config key param";
    my $val = eval { $self->mm_config->get($key); };
    die "Missing config $key in master_config" unless $val;
    return $val;
}

=head2 $self->oget($key)

Get optional parameter from master_config.

=over

=item $key

The name of the key in master config.

=item return

The value of the config variable if it exists. Returns an empty string otherwise.

=back

=cut
sub oget {
    my $self = shift;

    my $key = shift or die "Missing config key param";
    my $val = eval { $self->mm_config->get($key); };
    return $val;
}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
