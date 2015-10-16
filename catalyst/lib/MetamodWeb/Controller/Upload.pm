package MetamodWeb::Controller::Upload;

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

=head1 NAME

MetamodWeb::Controller:Upload - Catalyst Controller for non-restriced functions

=head1 DESCRIPTION

This is used for handlers that don't require login.

=head1 METHODS

=cut

use Moose;
use namespace::autoclean;

use MetamodWeb::Utils::UploadUtils;
use Data::Dumper;

BEGIN { extends 'MetamodWeb::BaseController::Base' };

sub auto :Private {
    my ( $self, $c ) = @_;
    #$c->stash( section => 'upload' );
}

=head2 /upload/newfiles

Webservice used for OSISAF-like sites (EXTERNAL_REPOSITORY = true) where files are stored externally.
This is called as a webservice to trigger indexing from file system.

=cut

sub newfiles : Path("/upload/newfiles") :Args(0) {
    my ( $self, $c ) = @_;

    my $data;
    my @params;

    my $upload_utils = MetamodWeb::Utils::UploadUtils->new( { c => $c, config => $c->stash->{ mm_config } } );

    foreach my $pname (qw (dataset dirkey filename)) {
        my $pval = $c->req->parameters->{$pname};
        if (!$pval) {
            $data = "Query did not contain a $pname value";
            last;
        }
        #printf STDERR " # %s is %s\n", $pname, $pval;
        push @params, $pval;
    }

    if (! $data) {
        eval {
            $data = $upload_utils->process_newfiles(@params);
        } or $data = $@;
    }

    $c->response->content_type( 'text/plain' );
    $c->response->body( "$data\n" );

}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

__PACKAGE__->meta->make_immutable;
