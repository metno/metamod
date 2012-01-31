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
use MetamodWeb::Utils::Exception qw( error_from_exception );
use Metamod::ForeignDataset;

BEGIN { extends 'MetamodWeb::BaseController::Base'; }

=head1 NAME

MetamodWeb::Controller::Admin::ShowXML

=head1 DESCRIPTION

Catalyst Controller for system administration of XML metadata files

=head1 METHODS

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

=head2 /admin/showxml

Use for listing XML metadata files

=cut

sub listfiles :Path('/admin/showxml') :Args(0) {
    # if no args, show list of files in xml dir
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

=head2 /admin/showxml

Sysadmin section for editing XML metadata files.

File path (w/o extension) used as argument.
Use GET for reading and POST for writing.

=cut


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

    my $schema = $c->stash->{mm_config}->get("INSTALLATION_DIR") . "/common/schema/";

    my $admin_utils = $c->stash->{admin_utils};
    my $base = $c->stash->{xmldir} . "/" . $c->stash->{path};

    $self->logger->debug("Reading XMD/XML file...");
    my $ds = Metamod::ForeignDataset->newFromFile($base);

    # get data in utf-8 representation
    my $xmd = '<?xml version="1.0" encoding="UTF-8"?>'."\n".
              $ds->getXMD_DOC()->documentElement()->toString(1);
    my $xml = '<?xml version="1.0" encoding="UTF-8"?>'."\n".
              $ds->getMETA_DOC()->documentElement()->toString(1);

    $self->logger->debug("Checking XMD file...");
    my $xmdvalid = $admin_utils->validate($xmd, "$schema/dataset.xsd");

    $self->logger->debug("Checking XML file...");
    my $xmlvalid = $admin_utils->validate($xml, "$schema/MM2.xsd");

    $c->stash(
        xml => { data => $xml, invalid => $xmlvalid },
        xmd => { data => $xmd, invalid => $xmdvalid }
    );

}

sub editxml_POST  { # update existing xml files
    my ( $self, $c ) = @_;

    my $schema = $c->stash->{mm_config}->get("INSTALLATION_DIR") . "/common/schema";
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
        eval {
            my $fds = Metamod::ForeignDataset->newFromDoc($c->req->params->{xmlContent}, $c->req->params->{xmdContent});
            $fds->writeToFile($base);
            $self->logger->info('Change metadata in file '.$base);
        }; if ($@) {
            # TODO: error should be returned to user instead
            $self->add_error_msgs( $c, "Cannot change metadata in file $base: " . error_from_exception($@) );
            $self->logger->error("Cannot change metadata in file $base: ".$@);
        } else {
            $self->add_info_msgs( $c, "Files saved successfully on " . gmtime() );
        }
        $c->response->redirect( $c->uri_for('/admin/editxml', $c->stash->{path}) );
    }
}

=head1 AUTHOR

geira@met.no

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

__PACKAGE__->meta->make_immutable;
