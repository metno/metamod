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
#use Catalyst::Log::Log4perl; # Catalyst::Log::Log4perl is DEPRECATED, update your app to use Log::Log4perl::Catalyst FIXME 2.13
use Log::Log4perl::Catalyst;
use FindBin;
use Log::Log4perl qw(get_logger);

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
    ConfigLoader
    Static::Simple
    Authentication
    Authorization::Roles
    Session
    Session::State::Cookie
    Session::Store::FastMmap
    SmartURI
    Unicode::Encoding
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

my $mm_config = Metamod::Config->instance();
$mm_config->initLogger();

my $custdir = path_to_custom();
my %default_config = (
    disable_component_resolution_regex_fallback => 1,

    'View::TT' => {
        INCLUDE_PATH => [
            $custdir ? "$custdir/templates" : undef,
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

    'default_view' => 'TT',

    static => { # Deprecated 'static' config key used, please use the key 'Plugin::Static::Simple' instead
        include_path => [
            path_to_custom(),
            $mm_config->get('WEBRUN_DIRECTORY'),
            __PACKAGE__->config->{root},
        ],
        dirs => [ 'static', 'download' ],
        mime_types => {
            xmd => 'text/xml',
        },
    },

    'Plugin::Session' => {
        #expires => 3600,
        storage => $mm_config->get('WEBRUN_DIRECTORY') . '/session_data',
    },

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

# Log::Log4perl is already initialised so the Catalyst logger will not initialise it again
__PACKAGE__->log( Log::Log4perl::Catalyst->new() );

# Start the application
__PACKAGE__->setup();

=head2 path_to_metamod_root()

Determine the absolute path to the Metamod root directory. This directory will
be different between development and deployment.

=cut

sub path_to_metamod_root {

    if( $FindBin::Bin =~ qw!(.+)/(catalyst/script|scripts|catalyst/t.*)$! ){
        return $1;
    } else {
        get_logger('MetamodWeb')->error("Could not determine the absolute path from $FindBin::Bin to the METAMOD root directory.");
        return;
    }

}

=head2 path_to_custom()

Determine the absolute path to the custom directory under Metamod root (see over).

=cut

sub path_to_custom {

    return File::Spec->catdir($mm_config->config_dir, 'custom');

}

=head1 NAME

MetamodWeb - Catalyst based application

=head1 SYNOPSIS

    script/metamod_web_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 SEE ALSO

L<MetamodWeb::Controller::Root>, L<Catalyst>

=head1 AUTHOR

Copyright 2011 The Norwegian Meteorological Institute

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
