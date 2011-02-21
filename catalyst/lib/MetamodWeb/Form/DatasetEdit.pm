package MetamodWeb::Form::DatasetEdit;

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

use HTML::FormHandler::Moose; # REMOVE
use MetamodWeb::Utils::Exception qw( error_from_exception );
use Try::Tiny;
use namespace::autoclean;


extends 'HTML::FormHandler::Model::DBIC';

=head1 NAME

MetamodWeb::Form::DatasetCreate - HTML::FormHandler form for editing a dataset.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 FUNCTIONS/METHODS

=cut

has '+item_class' => ( default => 'Dataset' );

has_field 'u_id' => ( type => 'Hidden' );

has_field 'a_id' => ( type => 'Hidden' );

has_field 'ds_name' => ( type => 'Text', label => 'Dataset name', required => 1 );

has_field 'dataset_key' => ( type => 'Text', label => 'Dataset key' );

has_field 'projection_xml' => ( type => 'TextArea', label => 'Projections setup' );

has_field 'wms_xml' => ( type => 'TextArea', label => 'WMS parameters' );

sub validate_projection_xml {
    my ( $self, $field ) = @_;

    my $infods_rs = $self->schema()->resultset('Infods');

    try {
        $infods_rs->validate_projection_xml( $field->value );
    } catch {
        $field->add_error( error_from_exception($_) );
    };
}

sub validate_wms_xml {
    my ( $self, $field ) = @_;

    my $infods_rs = $self->schema()->resultset('Infods');

    try {
        $infods_rs->validate_wms_xml( $field->value );
    } catch {
        $field->add_error( error_from_exception($_) );
    }
}


__PACKAGE__->meta->make_immutable();

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
