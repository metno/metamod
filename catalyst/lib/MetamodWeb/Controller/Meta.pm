package MetamodWeb::Controller::Meta;

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

use Data::Dump qw( dump );

use Moose;
use namespace::autoclean;

=head1 NAME

MetamodWeb::Controller::Meta - Controller for various diagnostic and admnistrative functions

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

BEGIN { extends 'MetamodWeb::BaseController::Base'; }

=head2 version

Displays version information

=cut

sub version :Path('/version') :Args(0) {
    my ($self, $c) = @_;

    $c->response->content_type('text/plain');
    my $dir = $c->stash->{mm_config}->get('INSTALLATION_DIR');
    $c->serve_static_file( "$dir/VERSION" );
}


=head2 settings

Displays (some) settings information to aid external monitoring (nothing very secret)

=cut

sub settings :Path('/settings') :Args {
    my ($self, $c, $key) = @_;
    my $r = $c->response;

    $r->content_type('text/plain');

    my $config = $c->stash->{mm_config};
    my $vars = $config->split('EXPOSE_CONFIG_SETTINGS');
    if ($key) {
        $c->detach( 'Root', 'error', [404, "Key $key not found"] ) unless $key ~~ @$vars;
        $r->write( $config->has($key) ? $config->get($key) : '-' );
    } else {
        for (@$vars) {
            $r->write( sprintf "%20s : %-20s\n", $_, $config->has($_) ? $config->get($_) : '-' );
        }
    }
    $r->body('');
}


=head2 robots

Output generated robots.txt

=cut

sub robots :Path('/robots.txt') :Args(0) {
    my ($self, $c) = @_;

    $c->response->content_type('text/plain');
    $c->stash( template => 'robots.tt', 'current_view' => 'None' );

}

__PACKAGE__->meta->make_immutable;

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
