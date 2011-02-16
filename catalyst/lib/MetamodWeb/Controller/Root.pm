package MetamodWeb::Controller::Root;

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
use Metamod::Config;
use namespace::autoclean;

use Data::Dump qw( dump );

use MetamodWeb::Utils::UI::Common;

# By extending from ActionRole we can apply action roles to actions.
BEGIN { extends 'Catalyst::Controller::ActionRole' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config(namespace => '' );

=head1 NAME

MetamodWeb::Controller::Root - Root Controller for MetamodWeb

=head1 DESCRIPTION

This is the root controller for the MetamodWeb Catalyst application. The root controller is special in that its
auto(), begin() and end() actions are relevant for all other controllers. The auto() action in this controller will be
called for all Controllers for instance.

=head1 METHODS

=head2 index

The root page (/) for the Catalyst site. We configure it to send the user directly to the search page.

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->visit( 'Search', 'index' );

}

=head2 default

Standard 404 error page

=cut

sub default :Path {
    my ( $self, $c ) = @_;
    $c->response->body( "<h1>Page not found</h1>\n" );
    $c->response->content_type('text/html');
    $c->response->status(404);
}

=head2 begin()

Default begin action.

=cut

sub begin :Does('InitQueryLog'){
    my ( $self, $c ) = @_;

}

=head2 auto()

Default auto action. This function is responsible for all application specific
setup that is required for all request.

For instance creating objects that are relevant for all requests.

=cut

sub auto :Private {
    my ( $self, $c ) = @_;

    my $mm_config = Metamod::Config->new();

    $c->stash( mm_config => $mm_config );

    my $ui_utils = MetamodWeb::Utils::UI::Common->new( { config => $mm_config, c => $c } );
    $c->stash( ui_utils => $ui_utils,
               title => $mm_config->get('SEARCH_APP_TITLE'), # FIXME: only true for search, not upload etc
               css_files => [] );

}

=head2 end

Default end action. Attempt to render a view, if needed.

It is seldom necessary to override the end() action in a sub controller.

=cut

sub end : ActionClass('RenderView') :Does('DumpQueryLog') :Does('DeleteStash')  {
    my ( $self, $c ) = @_;


}

__PACKAGE__->meta->make_immutable;

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
