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
use MetamodWeb::Utils::FormValidator;

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
        xmldir => $xmldir,
        #xmldir => '/home/user/projects/metamod28/src/test/xmlinput',
        current_view => 'Raw',
        template => 'admin/showxml.tt',
        admin_utils => MetamodWeb::Utils::AdminUtils->new(),
        maxfiles => 5,
    );
}

sub listfiles :Path('/admin/showxml') :Args(0) {
    # show list of files in xml dir
    my ( $self, $c ) = @_;

    $c->stash( path => '' );
}

sub getfile :Path('/admin/showxml') {
    # download file as spec'd in args
    my ( $self, $c ) = @_;

    my ($path) = $c->req->path =~ m|admin/showxml/(.+)| or die "Chose the wrong path";

    if ( $path =~ /\.xm(l|d)$/ ) {
        my $file = $c->stash->{xmldir} ."/$path";
        #printf STDERR "+++++++++++++ $file ... %s\n", -e $file ? 'OK' : 'ERROR';
        if( -r $file ){
            $c->serve_static_file( $file );
        } else {
            $c->detach('Root', 'default' );
        }
    } else {
        $c->stash( path => $path );
    }
}

###

sub editxml :Path('/admin/editxml') :ActionClass('REST') {
    my ( $self, $c ) = @_;

    my ($path) = $c->req->path =~ m|admin/editxml/+(.+)| or die "Chose the wrong path";

    $c->stash(
        template => 'admin/editxml.tt',
        path => $path,
    );
}

sub editxml_GET { # show editor for xml files
    my ( $self, $c ) = @_;

    my $schema = $c->stash->{mm_config}->get("TARGET_DIRECTORY") . "/schema/";

    my $admin_utils = $c->stash->{admin_utils};
    my $base = $c->stash->{xmldir} . "/" . $c->stash->{path};

    print STDERR "Checking XMD file...\n";
    my $xmd = $admin_utils->read_file("$base.xmd");
    my $xmdvalid = $admin_utils->validate($xmd, "$schema/dataset.xsd");

    print STDERR "Checking XML file...\n";
    my $xml = $admin_utils->read_file("$base.xml");
    my $xmlvalid = $admin_utils->validate($xml, "$schema/MM2.xsd");

    $c->stash(
        xml => { data => $xml, invalid => $xmlvalid },
        xmd => { data => $xmd, invalid => $xmdvalid }
    );

}

sub editxml_POST  { # update existing xml files
    my ( $self, $c ) = @_;

    my $schema = $c->stash->{mm_config}->get("TARGET_DIRECTORY") . "/schema";
    my $base = $c->stash->{xmldir} . "/" . $c->stash->{path};

    my %xmlform = (
        required => [qw( xmdContent xmlContent )],
        optional => [],
        constraint_methods => {
            xmdContent => MetamodWeb::Utils::FormValidator::Constraints::xml( "$schema/dataset.xsd" ),
            xmlContent => MetamodWeb::Utils::FormValidator::Constraints::xml( "$schema/MM2.xsd" ),
        },
        labels => {
            xmdContent => 'Dataset Content',
            xmlContent => 'Metadata Content',
        },
        msgs => sub {
            xmdContent => "Invalid XMD",
            xmlContent => "Invalid MM2",
        }
    );

    my $validator = MetamodWeb::Utils::FormValidator->new( validation_profile => \%xmlform );
    my $results = $validator->validate($c->req->params);
    if ( $results->has_invalid or $results->has_missing or ($c->req->params->{submitValue} eq 'Validate') ) {
        $c->stash(
            xmd => { data => $c->req->params->{xmdContent}, invalid => $results->invalid('xmdContent') },
            xml => { data => $c->req->params->{xmlContent}, invalid => $results->invalid('xmlContent') },
        );
    } else {
        # store files
        $c->stash->{admin_utils}->write_file("$base.xml", $c->req->params->{xmlContent});
        $c->stash->{admin_utils}->write_file("$base.xmd", $c->req->params->{xmdContent});
        $c->response->redirect( $c->uri_for('/admin/editxml', $c->stash->{path}) );
    }
}

=head1 AUTHOR

geira,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;
