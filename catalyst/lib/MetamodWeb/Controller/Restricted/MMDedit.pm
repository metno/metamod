=begin LICENSE

Copyright (C) 2012 met.no

This file is part of METAMOD

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

package MetamodWeb::Controller::Restricted::MMDedit;

=head1 NAME

MetamodWeb::Controller::Restricted::MMDedit - edit XML data files via external editor

=head1 DESCRIPTION

Designed to be used with the Met.no Metadata Editor L<https://github.com/metno/metadata-editor>

Only available if the directive MMDEDIT_URL is set in master_config.

=head1 METHODS

=cut

use Moose;
use namespace::autoclean;

our $VERSION = do { my @r = (q$LastChangedRevision$ =~ /\d+/g); @r ? sprintf "0.%d", @r : 0 };

BEGIN {extends 'MetamodWeb::BaseController::Base'; }


=head2 /editxml



=cut

sub transform :Path('/editxml') :Args(1) {
    my ($self, $c, $ds_id) = @_;

    my $config = Metamod::Config->instance();
    my $fimexpath = $config->get('MMDEDIT_URL')
        or $c->detach( 'Root', 'error', [ 501, "Missing MMDEDIT_URL in config"] );


    $c->stash( template => 'mmdedit.tt', 'current_view' => 'Raw' );
    $c->stash( debug => $self->logger->is_debug() );


}


__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=head1 AUTHOR

Geir Aalberg, E<lt>geira@met.noE<gt>

=head1 SEE ALSO

=cut
