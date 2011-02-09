package MetamodWeb::Controller::Restricted::Upload;

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

use MetamodWeb::Utils::UploadUtils;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller' };

sub auto :Private {
    my ( $self, $c ) = @_;
    my $da_ui_utils = MetamodWeb::Utils::UI::DatasetAdmin->new( c => $c, config => $c->stash->{mm_config} );
    $c->stash( da_ui_utils => $da_ui_utils );
    $c->stash( section => 'upload' );
}

#
# upload file
#
sub upload : Path('/upload') :ActionClass('REST') : Args(0) {
    my ( $self, $c ) = @_;
}

sub upload_GET {
    my ( $self, $c ) = @_;

    $c->stash(
        template => 'upload/form.tt',
    );

}

sub upload_POST  {
    my ( $self, $c ) = @_;

    my $upload_utils = MetamodWeb::Utils::UploadUtils->new( { c => $c, config => $c->stash->{ mm_config } } );

    #my $cru = new Catalyst::Request::Upload;
    my $upload = $c->req->upload('data');
    my $data = $upload->filename . " (" . $upload->size . "B) uploaded. ";
    my $fn = $upload->filename;

    if (! $upload->size) {
        $data = "ERROR: File size is zero bytes.";
    } elsif ( !( my $dsname = $upload_utils->validate_datafile($fn) ) ) {
        $data .= "FAILED validation!";
    } elsif ( !( my $dataset = $c->model('Userbase::Dataset')->search( { ds_name => $dsname } )->first() ) ) {
        $data .= "No such dataset '$dsname' registered!";
    } elsif ( ! $dataset->validate_dskey( $c->req->param('dirkey') ) ) {
        $data = "Invalid key!";
    } else {
        my $institution = $c->user->u_institution;
        my $updir = $c->stash->{mm_config}->get('UPLOAD_DIRECTORY');
        my $target = join( '/', $updir, $institution, $dsname, $fn);

        printf STDERR "* file %s\n", $target;

        mkdir "$updir/$institution";
        mkdir "$updir/$institution/$dsname";
        $upload->copy_to($target) or die $!;

        #$c->response->redirect('/upload/test');
        #$c->detach();
    }

    $c->stash(
        template => 'upload/form.tt',
        data => $data,
    );

}

#
# test file
#
sub test : Path('/upload/test') :ActionClass('REST') : Args(0) {
    my ( $self, $c ) = @_;
}

sub test_GET {
    my ( $self, $c ) = @_;

    $c->stash(
        template => 'upload/test.tt',
    );

}

sub test_POST  {
    my ( $self, $c ) = @_;

    my $data;

    my $upload_utils = MetamodWeb::Utils::UploadUtils->new( { c => $c, config => $c->stash->{ mm_config } } );

    if ( my $upload = $c->req->upload('data') ) {

        my $fn = $upload->filename;

        if (! $upload->size) {
            $data = "ERROR: File size is zero bytes.";
        } elsif (! $upload_utils->validate_datafile($fn) ) {
            $data = "File name must start with \"dir_\" where dir is a destination directory (which need not exist)";
        } else {
            # FIXME - move this from controller to uploadutils
            my $target = $c->stash->{mm_config}->get('WEBRUN_DIRECTORY') . "/upl";

            $upload->copy_to("$target/ftaf/$fn") or die $!;
            open(my $etaf, '>', "$target/etaf/$fn") or die $!;
            print $etaf $c->user->u_email . "\n";
            close $etaf;
            $data = sprintf "File $fn (%s bytes) uploaded successfully. Test report will be sent on e-mail.", $upload->size;
        }
    } else {
        $data = "No file uploaded. Try again.";
    }

    $c->stash(
        template => 'upload/test.tt',
        data => $data,
    );

}

=head2 index

Action for displaying the search front page.

=cut

sub index : Path("/search") :Args(0) {
    my ( $self, $c ) = @_;

    $c->stash( template => 'search/search.tt');

}

=head1 NAME

MetamodWeb::Controller::Restricted:Upload - Catalyst Controller for file upload

=head1 DESCRIPTION

blah blah blah

=head1 METHODS

blah blah blah

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

__PACKAGE__->meta->make_immutable;

