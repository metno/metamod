package MetamodWeb::Utils::Exception;

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

use base 'Exporter';

our @EXPORT_OK = qw( error_from_exception );

=head2 error_from_exception($exception)

Parse the error message from an exception.

=over

=item $exception

The exception string as thrown by die, croak and confess.

=item return

=back

=cut

sub error_from_exception {
    my ($exception) = @_;

    if( $exception =~ /^ (.+) at\s+ (\/[\w\d_-])+ /ixsm ){
        return $1;
    }

    return $exception;
}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
