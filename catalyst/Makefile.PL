#!/usr/bin/env perl
# IMPORTANT: if you delete this file your app will not work as
# expected.  You have been warned.

use inc::Module::Install 1.02;
use Module::Install::Catalyst; # Complain loudly if you don't have
                               # Catalyst::Devel installed or haven't said
                               # 'make dist' to create a standalone tarball.

name 'MetamodWeb';
all_from 'lib/MetamodWeb.pm';

requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Action::RenderView';
requires 'Moose';
requires 'namespace::autoclean';
requires 'Config::General'; # This should reflect the config file format you've chosen
                 # See Catalyst::Plugin::ConfigLoader for supported formats


# Dependencies that once were handled by the internal Catalyst .deb package (now carton)
requires 'Catalyst::Devel' => '1.37';
requires 'Catalyst::Runtime' => '5.90019';
requires 'Starman' => '0.3006';
requires 'Catalyst::Plugin::Authentication';
requires 'Catalyst::Action::REST';
requires 'Catalyst::Authentication::Store::DBIx::Class';
requires 'Catalyst::Authentication::Store::LDAP';
requires 'Catalyst::Plugin::Authorization::Roles';
requires 'Catalyst::Plugin::Unicode::Encoding';
requires 'Catalyst::Plugin::Session';
requires 'Catalyst::Plugin::Session::State::Cookie';
requires 'Catalyst::Plugin::Session::Store::FastMmap';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Action::RenderView';
requires 'Catalyst::View::TT' => '0.40';
#requires 'Catalyst::Log::Log4perl' => '1.04'; # DEPRECATED use Log::Log4perl::Catalyst instead
requires 'Log::Log4perl' => '1.31';
requires 'Catalyst::Controller::ActionRole' => '0.15';

requires 'Moose' => '1.14';
requires 'DBIx::Class' => '0.08123';
requires 'DBIx::Class::QueryLog' => '1.3.0';
requires 'Data::Page' => '2.00';
requires 'namespace::autoclean';
requires 'JSON' => '2.00';
requires 'Template' => '2.22';
requires 'HTML::FormHandler' => '0.32005';
requires 'Data::FormValidator' => '4.66';
requires 'TheSchwartz' => 1.10;
requires 'POD::Simple::Wiki';
requires 'Archive::Zip';
requires 'HTTP::OAI';
requires 'XML::SAX::Writer';

requires 'Imager'; # If installing from CPAN you need libpng-dev (Ubuntu)
requires 'XML::LibXML';
requires 'XML::LibXSLT';
requires 'XML::RSS::LibXML';
requires 'POE';
requires 'POE::Component::Cron';
requires 'DateTime::Set';


test_requires 'Test::More' => '0.88';
test_requires 'Test::WWW::Mechanize::Catalyst';
test_requires 'TAP::Harness::Archive';
test_requires 'Test::Files';
test_requires 'Benchmark::Timer';
test_requires 'JSON::Any';
test_requires 'Test::Pod::Coverage';

catalyst;

install_script glob('script/*.pl');

# All installation should by default be by .deb packages
if( !( grep { /--skipdeps|--defaultdeps|--testonly|--checkdeps/ } @ARGV ) ){
    $ENV{ PERL_AUTOINSTALL } = '--skipdeps';
}
auto_install;

WriteAll;
