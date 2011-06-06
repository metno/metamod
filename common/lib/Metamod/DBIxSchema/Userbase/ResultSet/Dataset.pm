package Metamod::DBIxSchema::Userbase::ResultSet::Dataset;

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
use Carp;
use Data::Dumper;
use base 'Metamod::DBIxSchema::Resultset';

=head2 $self->get_ds($ds_id)

Find a dataset by id and return a hash containing name + values from Infods

=cut

sub get_ds {
    my $self = shift;
    my $ds_id = shift or die "Missing ds_id";
    my $dataset = {};

    if ( my $ds = $self->find({ ds_id => $ds_id }) ) {
        return $ds->get_info_ds;
    } else {
        return;
    }
}

=head2 $self->create_ds()

Create a new dataset and return id

=cut

sub create_ds {
    my $self = shift;
    my $para = shift or die "Missing params";
    my $data = shift or die "Missing credentials";

    $$data{ds_name} = $$para{ds_name} or croak "Missing ds_name";
    croak "Dataset name too long" if length $$para{ds_name} > 20;
    die "Dataset " . $$data{ds_name} . " is already registered!" if ( $self->find({ ds_name => $$data{ds_name} }) );
    my $ds = $self->create( $data, {key => 'dataset_pkey'} );
    return $ds->set_info_ds($para); # returns ds_id
}

1;

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut
