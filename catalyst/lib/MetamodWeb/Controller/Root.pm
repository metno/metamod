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
use HTTP::Status qw(status_message);

use Data::Dump qw( dump );

use MetamodWeb::Utils::UI::Common;

# By extending from ActionRole we can apply action roles to actions.
BEGIN { extends 'Catalyst::Controller::ActionRole', 'MetamodWeb::BaseController::Base' }

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

    #if ($c->req->user_agent =~ /Googlebot/) {
    #    return $c->res->redirect( $c->uri_for( '/dataset/', $c->req->params ), 301 );
    #} else {
        $c->visit( 'Search', 'index' );
    #}

}

=head2 error

Customizable error page (only detached to explicitly)

=cut

sub error :Path {
    my ( $self, $c, $status, $message ) = @_;
    $c->response->content_type('text/html');
    $c->response->status($status);
    $c->response->body( "<h1>$status " . status_message($status) . "</h1><pre>$message</pre>\n" );
    $c->clear_flash; # get rid of hanging error msgs on subsequent page
}

=head2 default

Standard 404 error page

=cut

sub default :Path { # must come after error so won't be overridden
    my ( $self, $c ) = @_;
    $c->stash( template => 'errorpage.tt', status_text => "Page not found (404)", 'current_view' => 'None' );
    #$c->response->body( "<h1>Page not found</h1>\n" );
    $c->response->content_type('text/html');
    $c->response->status(404);
    $self->logger->warn("404 not found: ", $c->request->uri);
}

=head2 unauthorized

Standard 403 error page

FIXME - needs better user interface

=cut

sub unauthorized :Private {
    my ( $self, $c, $required_role ) = @_;
    $self->logger->debug("Required role: $required_role");
    $c->response->status(403);
    $c->stash( template => 'unauthorized.tt', required_role => $required_role );
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

    # abort security exploit attempts as early as possible in the dispatch chain
    $c->detach('Root', 'default') if $c->request->path =~/\.(php|cgi|pl|jsp|dll|html)$/;

    my $mm_config = Metamod::Config->instance();

    $c->stash( mm_config => $mm_config );

    my $ui_utils = MetamodWeb::Utils::UI::Common->new( { config => $mm_config, c => $c } );
    $c->stash( ui_utils => $ui_utils,
               title => $mm_config->get('SEARCH_APP_TITLE'), # FIXME: only true for search, not upload etc
               css_files => [] );

    return 1;
}

=head2 end

Default end action. Attempt to render a view, if needed.

It is seldom necessary to override the end() action in a sub controller. [Well, actually we would like that...]

=cut

#sub end : ActionClass('RenderView') :Does('DumpQueryLog') :Does('DeleteStash')  {
#    my ( $self, $c ) = @_;
#}

=head3 Custom error page

This is used to avoid the dreaded "Come back later" screen

=cut

sub end : ActionClass('RenderView') :Does('DumpQueryLog') :Does('DeleteStash')  {
    my ( $self, $c ) = @_;

    if ( scalar @{ $c->error } ) {

        $c->stash->{title} = 'METAMOD fatal error';
        $c->stash->{URI} = $c->req->uri();
        $c->response->status(500);
        $c->stash->{errors}   = $c->error;
        for my $error ( @{ $c->error } ) {
            $c->log->error($error);
        }

        $c->stash->{template} = 'errors.tt';
        $c->forward('MetamodWeb::View::TT');
        $c->clear_errors;
        return 1 if $c->response->status =~ /^3\d\d$/;
        return 1 if $c->response->body;

        unless ( $c->response->content_type ) {
            $c->response->content_type('text/html; charset=utf-8');
        }
    }
}

__PACKAGE__->meta->make_immutable;

=head1 AUTHOR

Oystein Torget, E<lt>oysteint@met.noE<gt>

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
