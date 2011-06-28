package DatasetImporterFailer;

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

=head1 NAME

DatasetImporterFail - Sub-class of Metamod::DatasetImporter that always will fail writing to database.

=head1 DESCRIPTION

This class is a sub class of C<Metamod::DatasetImporter>. It is used to test the error handling of
C<write_to_database()> since it will always fail when calling _update_geo_location().

=head1 FUNCTIONS/METHODS

=cut

use Moose;

extends 'Metamod::DatasetImporter';


sub _update_geo_location {
    my $self = shift;

    die 'Failure forced by test module';

}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut
1;
