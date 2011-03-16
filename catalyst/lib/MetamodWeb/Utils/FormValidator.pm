package MetamodWeb::Utils::FormValidator;

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

use Data::FormValidator;
use Moose;
use namespace::autoclean;

=head1 NAME

MetamodWeb::Utils::FormValidation - Module for performing form validation.

=head1 DESCRIPTION

This module provides a thin wrapper around Data::FormValidator to allow attaching labels to each field for better
error reporting to the user.

=head1 ATTRIBUTES

=cut

=head2 valid_profile

A hash ref with a C<Data::FormValidator> compatible form profile. In addition to the standard C<Data::FormValidator>
attributes it can contain the key 'labels' which takes as hash ref as value. The 'labels' hash ref is a mapping
between field names and labels shown to the user.

=cut

has 'validation_profile' => ( is => 'ro', required => 1, trigger => \&_remove_labels, isa => 'HashRef' );

=head2 field_labels

A hash reference of field labels. Set automatically when validation profile is set.

=cut

has 'field_labels' => ( is => 'rw', isa => 'HashRef' );

=head2 result

The C<Data::FormValidator::Result> object from the last validation.

=cut

has 'result' => ( is => 'rw' );

=head1 FUNCTIONS/METHODS

=cut

=head2 $self->_remove_labels($new_profile, $old_profile)

Trigger function called automatically by Moose when the attribute C<validation_profile> is set.

=over

=item $new_profile

The new attribute value.

=item $old_profile

The old attribute value.

=back

=cut

sub _remove_labels {
    my ( $self, $new_profile, $old_profile ) = @_;

    my $labels = delete $new_profile->{labels};
    $self->field_labels($labels);

}

=head2 $self->validate($params)

Validate the parameters against the validation profile using C<Data::FormValidator::check()>

=over

=item $params

A hash reference of the form parameters to check.

=item return

Returns a C<Data::FormValidator::Result> object.

=back

=cut

sub validate {
    my $self = shift;

    my ($params) = @_;

    my $result = Data::FormValidator->check( $params, $self->validation_profile() );
    $self->result($result);
    return $result;

}

=head2 $self->field_label($field_name)

=over

=item $field_name

The name of field in the form profile.

=item return

If the form field has a label the label is returned. Otherwise it returns undef.

=back

=cut

sub field_label {
    my $self = shift;

    my ($field_name) = @_;

    if ( !exists $self->field_labels->{$field_name} ) {
        return;
    }

    return $self->field_labels->{$field_name};
}

__PACKAGE__->meta->make_immutable();

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
