package MetamodWeb::Controller::Admin::ShowXML;

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
use MetamodWeb::Utils::AdminUtils;

BEGIN { extends 'MetamodWeb::BaseController::Base'; }

=head1 NAME

MetamodWeb::Controller::Admin::ShowXML - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub auto : Private {
    my ( $self, $c ) = @_;

    my $mm_config = $c->stash->{mm_config};
    my $xmldir = $mm_config->get('WEBRUN_DIRECTORY') ."/XML/" . $mm_config->get('APPLICATION_ID');

    $c->stash(
        #xmldir => $xmldir,
        xmldir => '/home/user/projects/metamod28/src/test/xmlinput',
        current_view => 'Raw'
    );
}

sub listfiles :Path('/admin/showxml') :Args(0) {
    # show list of files in xml dir
    my ( $self, $c ) = @_;

    $c->stash(
        template => 'admin/showxml.tt',
        admin_utils => MetamodWeb::Utils::AdminUtils->new(),
    );
}

sub getfile :Path('/admin/showxml') {
    # download file as spec'd in args
    my ( $self, $c ) = @_;

    $c->req->path =~ m|admin/showxml/(.+)| or die "Chose the wrong path";
    my $file = $c->stash->{xmldir} ."/$1";
    #printf STDERR "+++++++++++++ $file ... %s\n", -e $file ? 'OK' : 'ERROR';

    if( -r $file ){
        $c->serve_static_file( $file );
    } else {
        $c->detach('Root', 'default' );
    }
}

=head1 AUTHOR

geira,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;
