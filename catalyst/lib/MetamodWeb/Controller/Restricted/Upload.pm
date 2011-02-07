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

    if ( my $dataset = $upload_utils->validate_datafile($fn) ) {

        my $institution = $c->user->u_institution;
        my $updir = $c->stash->{mm_config}->get('UPLOAD_DIRECTORY');
        my $target = join( '/', $updir, $institution, $dataset, $fn);

        printf STDERR "* file %s\n", $target;

        mkdir "$updir/$institution";
        mkdir "$updir/$institution/$dataset";
        $upload->copy_to($target) or die $!;

        #$c->response->redirect('/upload/test');
        #$c->detach();
    } else {
        $data .= "FAILED validation!";
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

    #my $cru = new Catalyst::Request::Upload;
    if ( my $upload = $c->req->upload('data') ) {

        my $fn = $upload->filename;

        if ( $upload_utils->validate_datafile($fn) ) {
            # FIXME - move this from controller to uploadutils
            my $target = $c->stash->{mm_config}->get('WEBRUN_DIRECTORY') . "/upl";

            $upload->copy_to("$target/ftaf/$fn") or die "Can't copy file to \"$target/ftaf/$fn\"";
            open(my $etaf, '>', "$target/etaf/$fn") or die $!;
            print $etaf $c->user->u_email . "\n";
            close $etaf;
            $data = sprintf "File $fn (%s bytes) uploaded successfully. Test report will be sent on e-mail.", $upload->size;
        } else {
            $data = "File name must start with \"dir_\" where dir is a destination directory (which need not exist)";
        }
    } else {
        $data = "No file uploaded. Try again.";
    }

    $c->stash(
        template => 'upload/test.tt',
        data => $data,
    );

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

