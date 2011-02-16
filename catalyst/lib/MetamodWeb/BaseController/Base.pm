package MetamodWeb::BaseController::Base;

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

BEGIN {extends 'Catalyst::Controller'; }



=head1 NAME

MetamodWeb::BaseController::Base - Base controller that adds some additional utility methods.

=head1 DESCRIPTION

=head1 FUNCTIONS/METHODS

=cut

=head2 $self->add_info_msgs($c, $msgs)

Add messages to the list of info message to the user for this request.

=over

=item $c

The Catalyst context object.

=item $msgs

Either a single scalar with a message to the user or an array ref of several messages.

=item return

Always returns false.

=back

=cut
sub add_info_msgs {
    my ($self, $c, $msgs) = @_;

    return $self->_add_msgs($c, 'info_msgs', $msgs );

}

=head2 $self->add_error_msgs($c, $msgs)

Add messages to the list of error message to the user for this request.

=over

=item $c

The Catalyst context object.

=item $msgs

Either a single scalar with a message to the user or an array ref of several messages.

=item return

Always returns false.

=back

=cut
sub add_error_msgs {
    my ($self, $c, $msgs) = @_;

    return $self->_add_msgs($c, 'error_msgs', $msgs );

}

sub _add_msgs {
    my ($self, $c, $msg_type, $msgs) = @_;

    my $curr_msgs = $c->stash->{ $msg_type };
    $curr_msgs = [] if !defined $curr_msgs;

    if( ref $msgs eq 'ARRAY' ){
        push @{ $curr_msgs }, @$msgs;
    } else {
        push @{ $curr_msgs }, $msgs;
    }

    $c->stash( $msg_type => $curr_msgs );
    return;
}


=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

__PACKAGE__->meta->make_immutable;

1;