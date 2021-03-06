package MetamodWeb::View::TT;

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

use base 'Catalyst::View::TT';

__PACKAGE__->config(
    #TEMPLATE_EXTENSION => '.tt',
    WRAPPER => 'wrapper.tt',
    PRE_PROCESS => ['defaults.tt', 'custom.tt', 'macros.tt'],
    render_die => 1, # will be default behaviour soon
);

=head1 NAME

MetamodWeb::View::TT - TT View for MetamodWeb

=head1 DESCRIPTION

Template for normal pages using masthead, menus etc.

=head1 SEE ALSO

L<MetamodWeb::View::Raw>, 
L<MetamodWeb>

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
