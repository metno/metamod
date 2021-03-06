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

use Log::Log4perl qw(get_logger);
use Moose;
use namespace::autoclean;
use warnings;

use MetamodWeb::Utils::UI::Common;

=head1 NAME

MetamodWeb::BaseController::Base - Base controller that adds some additional utility methods.

=head1 DESCRIPTION

=head1 FUNCTIONS/METHODS

=cut

BEGIN {extends 'Catalyst::Controller'; }

#
# The logger object that is used for all controllers.
#
has 'logger' => ( is => 'ro', default => sub { get_logger('metamodweb::control') } );

=head2 $self->chk_logged_in($c)

Check that user of request is logged in

=over

=item $c

The Catalyst context object.

=item return

Return 1 if logged in, 0 otherwise.

=back

=cut

sub chk_logged_in {
    my ($self, $c) = @_;

    if (!$c->user_exists) {

        # Dump a log message to the development server debug output
        $self->logger->debug('***User not found, forwarding to /login');

        my $wanted_path = '/' . $c->request->path();
        my $ui_utils = MetamodWeb::Utils::UI::Common->new( { c => $c } );
        my $wanted_string = $ui_utils->stringify_params($c->request->params());
        $self->logger->debug("Wanted: $wanted_string");

        # Redirect the user to the login page
        my $url = $c->uri_for('/login', { return_path => $wanted_path, return_params => $wanted_string } );
        $self->logger->debug("* url = $url" );
        $c->response->redirect($url);

        # Return 0 to cancel 'post-auto' processing and prevent use of application
        return 0;
    }

    # User found, so return 1 to continue with processing after this 'auto'
    return 1;

}

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
    my ($self, $c, $msg_type, $msgs ) = @_;

    my $curr_msgs = $c->stash->{ $msg_type };
    $curr_msgs = [] if !defined $curr_msgs;

    if( ref $msgs eq 'ARRAY' ){
        push @{ $curr_msgs }, @$msgs;
    } else {
        push @{ $curr_msgs }, $msgs;
    }

    $c->flash( $msg_type => $curr_msgs ); # rewrite to use Catalyst::Plugin::StatusMessage - FIXME
    # see http://search.cpan.org/~jjnapiork/Catalyst-Plugin-Session-0.39/lib/Catalyst/Plugin/Session.pm

    return;
}

=head2 $self->add_form_errors($c, $validator)

Add form validation errors to the flash for later display.

=over

=item $c

The Catalyst context object.

=item $validator

A C<MetamodWeb::Utils::FormValidator> where the function C<validate()> has
already been called and the form was not validated successfully.

=item return

Always returns true. Dies if the $validator state is not as expected.

=back

=cut

sub add_form_errors {
    my ($self, $c, $validator) = @_;

    my $result = $validator->result();
    if( !defined $result ){
        die 'Appears that you are adding form errors before running validate(). Not allowed';
    }

    if( $result->success() ){
        die 'Appears that you are trying to add form errors for a valid form. Not allowed';
    }

    my %error_messages = ();

    my @missing = $result->missing();
    foreach my $field (@missing) {
        $error_messages{$field} = { msg => 'Missing required input', label => $validator->field_label($field)||$field };
    }

    my $msgs = $result->msgs();
    my $invalid = $result->invalid();
    while( my ($field, $failed_constraints) = each %$invalid ){

        my $msg = '';

        # If we just have the default message we use the constraint names instead
        # since that can be 'hacked' to create a more detailed message
        if( $msgs->{$field} eq 'Invalid' ){
            # we ignore the possiblity of multiple constraints for now
            $msg = $failed_constraints->[0];
        } else {
            $msg = $msgs->{$field};
        }
        $error_messages{$field} = { label => $validator->field_label($field), msg => $msg };

    }

    $c->flash( 'form_errors' => \%error_messages );
    return 1;
}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

__PACKAGE__->meta->make_immutable;

1;
