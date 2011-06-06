package MetamodWeb::Model::Metabase;

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
use base 'Catalyst::Model::DBIC::Schema';

__PACKAGE__->config(
    schema_class => 'Metamod::DBIxSchema::Metabase',
    connect_info => {
        # this flag is necessary to play nice with Catalyst::Plugin::Unicode::Encoding
        # without it data will be double encoded
        pg_enable_utf8 => 1
    },
);

=head1 NAME

MetamodWeb::Model::DB - Catalyst DBIC Schema Model

=head1 SYNOPSIS

See L<MetamodWeb>

=head1 DESCRIPTION

L<Catalyst::Model::DBIC::Schema> Model using schema L<Metamod::DBIxSchema>

=head1 GENERATED BY

Catalyst::Helper::Model::DBIC::Schema - 0.43

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
