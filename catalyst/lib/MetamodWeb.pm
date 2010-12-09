package MetamodWeb;

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

use 5.008008;
use Moose;
use namespace::autoclean;

use Catalyst::Runtime 5.80;
use Catalyst::Log::Log4perl;

use Metamod::Config;
use MetamodWeb::Utils::GenCatalystConf;

# Set flags and add plugins for the application
#
#         -Debug: activates the debug mode for very useful log messages
#   ConfigLoader: will load the configuration from a Config::General file in the
#                 application's home directory
# Static::Simple: will serve static files from the application's root
#                 directory

use Catalyst qw/
    -Debug
    ConfigLoader
    Static::Simple
    Authentication
    Session
    Session::State::Cookie
    Session::Store::FastMmap
    SmartURI
/;

extends 'Catalyst';

our $VERSION = '0.01';
$VERSION = eval $VERSION;

# Configure the application.
#
# Note that settings in metamod_web.conf (or other external
# configuration file that you set up manually) take precedence
# over this when using ConfigLoader. Thus configuration
# details given here can function as a default configuration,
# with an external configuration file acting as an override for
# local deployment.

my %default_config = (
    disable_component_resolution_regex_fallback => 1,

    'View::TT' => {
        INCLUDE_PATH => [
            __PACKAGE__->path_to( 'root', 'src' ),
        ],
        TEMPLATE_EXTENSION => '.tt',
        CATALYST_VAR => 'c',
    },

    'View::Raw' => {
        INCLUDE_PATH => [
            __PACKAGE__->path_to( 'root', 'src' ),
        ],
        TEMPLATE_EXTENSION => '.tt',
        CATALYST_VAR => 'c',
    },

    'default_view' => 'TT'
);

# we generate a Catalyst configuration hash at runtime from the master config file.
# This removes the need for an extra configuration file at the cost of the possibility of
# manually overwriting the generated configuration. If you need to manually override the configuration
# use a metamodweb_local.json file
my %master_catalyst_config = MetamodWeb::Utils::GenCatalystConf::catalyst_conf();

__PACKAGE__->config(
    %default_config,
    %master_catalyst_config
);

my $mm_config = Metamod::Config->new();
$mm_config->initLogger();

if ( my $catconf = $mm_config->get('CATALYST_SITE_CONFIG') ) {
    __PACKAGE__->config( 'Plugin::ConfigLoader' => { file => $catconf } );
}

# Log::Log4perl is already initialised so the Catalyst logger will not initialise it again
__PACKAGE__->log( Catalyst::Log::Log4perl->new() );

# Start the application
__PACKAGE__->setup();


=head1 NAME

MetamodWeb - Catalyst based application

=head1 SYNOPSIS

    script/metamod_web_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 SEE ALSO

L<MetamodWeb::Controller::Root>, L<Catalyst>

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
