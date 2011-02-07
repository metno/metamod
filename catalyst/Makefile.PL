#!/usr/bin/env perl
# IMPORTANT: if you delete this file your app will not work as
# expected.  You have been warned.


use inc::Module::Install;

name 'MetamodWeb';
all_from 'lib/MetamodWeb.pm';

# Dependencies that are handled by the internal Catalyst .deb package
requires 'Catalyst::Devel' => '1.27';
requires 'Catalyst::Runtime' => '5.80022';
requires 'Catalyst::Plugin::Authentication';
requires 'Catalyst::Action::REST';
requires 'Catalyst::Authentication::Store::DBIx::Class';
requires 'Catalyst::Authentication::Store::LDAP';
requires 'Catalyst::Plugin::Session';
requires 'Catalyst::Plugin::Session::State::Cookie';
requires 'Catalyst::Plugin::Session::Store::FastMmap';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Action::RenderView';
requires 'Catalyst::View::TT' => '0.35';
requires 'Catalyst::Log::Log4perl' => '1.04';
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

# Dependencies that are not handled by the Catalyst .deb package. These should
# be using the standard Ubuntu repository (or similar on other platforms). If the package
# is not available in the repository install it from CPAN.
requires 'Imager'; # If installing from CPAN you need libpng-dev (Ubuntu)
requires 'XML::LibXML';
requires 'XML::LibXSLT';
requires 'XML::RSS::LibXML';

test_requires 'Test::More' => '0.88';

catalyst;

install_script glob('script/*.pl');

# All installation should by default be by .deb packages
if( !( grep { /--skipdeps|--defaultdeps|--testonly|--checkdeps/ } @ARGV ) ){
    $ENV{ PERL_AUTOINSTALL } = '--skipdeps';
}
auto_install;

WriteAll;
