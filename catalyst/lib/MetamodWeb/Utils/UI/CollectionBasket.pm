package MetamodWeb::Utils::UI::CollectionBasket;

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

extends 'MetamodWeb::Utils::UI::Base';

=head1 NAME

MetamodWeb::Utils::UI::CollectionBasket - Utility functions for building the collection basket UI.

=head1 FUNCTIONS/METHODS

=cut

sub files_in_basket {
    my $self = shift;

    my $cookie = $self->c->req->cookies->{metamod_basket};

    my @files = ();

    return [] if !defined $cookie;

    if ( defined $cookie ) {

        my @dataset_ids = $cookie->value();

        return [] if 0 == @dataset_ids;

        my $datasets = $self->meta_db()->resultset('Dataset')->search( { ds_id => { -IN => \@dataset_ids } } );
        while ( my $dataset = $datasets->next() ) {
            my $file = {
                ds_id    => $dataset->ds_id(),
                location => $dataset->file_location(),
                name     => $dataset->ds_name()
            };
            push @files, $file;
        }

    }

    return \@files;

}

__PACKAGE__->meta->make_immutable;

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
