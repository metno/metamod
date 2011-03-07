package MetamodWeb::Utils::UI::Login;

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

=head1 NAME

MetamodWeb::Utils::UI::Login - Utility functions used for building the UI common for the login pages

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 FUNCTIONS/METHODS

=cut

extends 'MetamodWeb::Utils::UI::Base';

=head2 $self->user_institituions()

Get the list of institutions that a new user can belong to.

=over

=item return

Returns the list of institutions as a hash reference. The key is the can be used as an option value and the value is
used as a display name.

=back

=cut

sub user_institutions {
    my $self = shift;

    my $institution_list = $self->config->get('INSTITUTION_LIST');
    my @institutions = split "\n", $institution_list;
    my %institutions = ();
    foreach my $institution (@institutions){

        if( $institution =~ /^\s*([^ ]+) (.*)$/ix ){
            $institutions{$1} = $2;
        }
    }

    return \%institutions;
}

__PACKAGE__->meta->make_immutable;

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
