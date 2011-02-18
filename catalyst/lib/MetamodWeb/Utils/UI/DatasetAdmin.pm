package MetamodWeb::Utils::UI::DatasetAdmin;

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

use JSON;
use Moose;
use namespace::autoclean;

use warnings;

extends 'MetamodWeb::Utils::UI::Base';

=head1 NAME

MetamodWeb::Utils::UI::DatasetAdmin - Utility functions for building the dataset admin UI.

=head1 FUNCTIONS/METHODS

=cut

=head2 $self->user_datasets()

Get the list of datasets owned by the currently logged in user.

=over

=item return

A reference to a list of DBIx::Class rows objects for the datasets that the user owns.

=back

=cut

sub user_datasets {
    my $self = shift;

    my $user_id = $self->c->user()->u_id();
    my @datasets = $self->user_db->resultset('Dataset')->search( { u_id => $user_id } )->all();

    return \@datasets;

}

=head2 $self->user_files()

Get the list of files uploaded by the currently logged in user.

=over

=item return

A reference to a list of DBIx::Class rows objects for the files that the user has uploaded.

=back

=cut

sub user_files {
    my $self = shift;

    my $user_id = $self->c->user()->u_id();
    my @files = $self->user_db->resultset('File')->search( { u_id => $user_id } )->all();

    return \@files;

}

__PACKAGE__->meta->make_immutable;

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
