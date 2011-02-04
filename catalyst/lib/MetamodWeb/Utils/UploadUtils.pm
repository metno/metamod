package MetamodWeb::Utils::UploadUtils;

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
use namespace::autoclean;
use warnings;

#
# A Metamod::Config object containing the configuration for the application
#
has 'config' => ( is => 'ro', isa => 'Metamod::Config', required => 1 );

=head1 NAME

MetamodWeb::Utils::UploadUtils - Utilities for data upload.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 FUNCTIONS/METHODS

=cut



sub validate_datafile {
    my $self = shift;
    my $filename = shift or die "Missing filename";

    return $filename =~ /^\w+_\w+\.\w+/;

}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
