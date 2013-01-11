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

=head1 NAME

MetamodWeb::Controller::Restricted:Upload - Catalyst Controller for file upload

=head1 DESCRIPTION

Catalyst Controller for file upload

=head1 RESOLVES

=cut

use Moose;
use namespace::autoclean;
use MetamodWeb::Utils::UI::Upload;
use MetamodWeb::Utils::UploadUtils;
use MetamodWeb::Utils::Exception qw(error_from_exception);
use Metamod::Queue;
use Data::Dumper;
#use Devel::Peek;

BEGIN { extends 'MetamodWeb::BaseController::Base' };

my $queue = Metamod::Queue->new();


sub auto :Private {
    my ( $self, $c ) = @_;

    return 0 unless $self->chk_logged_in($c);

    if( !$c->check_user_roles("upload") ){
        # detach() does not work correctly in auto()
        $c->forward("Root", "unauthorized", ['upload']);
        return 0;
    }

    my $upload_ui_utils = MetamodWeb::Utils::UI::Upload->new( c => $c );
    $c->stash( upload_ui_utils => $upload_ui_utils );
    $c->stash( section => 'upload' );
    my $xrep = $c->stash->{mm_config}->get('EXTERNAL_REPOSITORY') || 0;
    $c->stash( external_repository => $xrep eq 'false' ? 0 : $xrep ? 1 : 0 ); # store as bool for easy eval
}

=head2 /upload

Action for uploading files

=cut

sub upload :Path('/upload') :ActionClass('REST') : Args(0) {
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

    $c->detach('Root', 'default' ) if $c->stash->{external_repository}; # don't accept any uploads

    my $institution = $c->user->u_institution;
    my $updir = $c->stash->{mm_config}->get('UPLOAD_DIRECTORY');
    my $upload_utils = MetamodWeb::Utils::UploadUtils->new( { c => $c, config => $c->stash->{ mm_config } } );

    $c->stash( template => 'upload/form.tt' );

    if ( my $overwrite = $c->req->params->{BTN_overwrite} ) {

        my $file = $c->req->params->{filename};

        if ($overwrite ne 'OK') { # user pressed cancel ... presumably
            $self->logger->debug("Cancelled upload of file '$file'");
            unlink "$updir/${file}_" or warn "Temp file '${file}_' mysteriously gone.";
            $c->response->redirect('/upload', 303);
            $c->detach();
        }

        # OK to overwrite file

        $self->logger->info("Existing file '$file' uploaded");
        rename("$updir/${file}_", "$updir/$file") or die "Can't overwrite file '$file'";
        $c->stash( data => "File $file replaced." );

        my $success = $queue->insert_job(
            job_type => 'Metamod::Queue::Worker::Upload',
            job_parameters => { file => "$updir/$file", type => 'WEB' },
            priority => 10,
        );

        if( $success ){
            $self->logger->debug("File $file replaced, will be processed shortly.");
        } else {
            $self->logger->error('Internal error: Could not add file to processing queue!');
        }

        return;
    }

    # move most of this stuff to uploadutils.... FIXME

    my $upload = $c->req->upload('data');
    my $data = $upload->filename . " (" . $upload->size . "B) uploaded.\n";
    my $fn = $upload->filename;
    my $dsname = $upload_utils->validate_datafile($fn);

    my $filepath = join( '/', $institution, $dsname, $fn) if $dsname;
    mkdir "$updir/$institution";
    mkdir "$updir/$institution/$dsname";
    $self->logger->info("Uploaded file '$filepath'.");

    if ( ! $dsname ) { # not validated (for some reason)

        $data .= "ERROR: Invalid filename!"; # or whatever
        $self->logger->debug("ERROR: Invalid filename!");

    } elsif (! $upload->size) { # empty file

        $data = "ERROR: File size is zero bytes!";
        $self->logger->debug("ERROR: File size is zero bytes!");

    } elsif ( !( my $dataset = $c->model('Userbase::Dataset')->search( { ds_name => $dsname } )->first() ) ) { # missing dataset

        $data .= "ERROR: No such dataset '$dsname' registered!";
        $self->logger->debug("ERROR: No such dataset '$dsname' registered!");

    } elsif ( ! $dataset->validate_dskey( $c->req->params->{dirkey} ) ) { # wrong key supplied

        $data = "ERROR: Incorrect key supplied!";
        $self->logger->debug("ERROR: Incorrect key supplied!");

    } elsif ( $c->model('Userbase::File')->search( { f_name => $upload->filename } )->first() ) { # file exists
        # run this test last so can check dskey & filesize before writing

        $upload->copy_to("$updir/${filepath}_") or die "$!"; # temp file
        $data = "File already exists in database. Overwrite?";
        $c->stash( overwrite_file => $filepath );

    } else {

        $self->logger->info("New file '$filepath' uploaded");
        $upload->copy_to("$updir/$filepath") or die $!;

        my $success = $queue->insert_job(
            job_type => 'Metamod::Queue::Worker::Upload',
            job_parameters => { file => "$updir/$filepath", type => 'INDEX' },
            priority => 10,
        );

        if( $success ){
            $data = "File uploaded, will be processed shortly.";
            $self->logger->debug('File uploaded');
        } else {
            $data = "Internal error: Could not add file to processing queue!";
            $self->logger->error('Internal error: Could not add file to processing queue!');
        }

    }

    $c->stash( data => $data );
}

=head2 /upload/test

Action for testing uploaded files

=cut

sub test :Path('/upload/test') :ActionClass('REST') :Args(0) {
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
            my $updir = $c->stash->{mm_config}->get('WEBRUN_DIRECTORY') . "/upl";

            $upload->copy_to("$updir/ftaf/$fn") or die $!;
            open(my $etaf, '>', "$updir/etaf/$fn") or die $!;
            printf $etaf "%s %s\n", $c->user->u_email, $c->user->u_name;
            close $etaf;

            my $success = $queue->insert_job(
                job_type => 'Metamod::Queue::Worker::Upload',
                job_parameters => { file => "$updir/ftaf/$fn", type => 'TAF' },
            );

            if( $success ){
                $self->logger->info("File $fn uploaded, will be tested shortly.");
            } else {
                $self->logger->error('Internal error: Could not add file to processing queue!');
            }

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


=head2 /upload/dataset

Action for dealing with dataset administration.

Without parameters, list (GET) or create (POST) datasets.

With id as parameter, display (GET) or edit (POST) the dataset.

=cut

# all datasets

sub dataset :Path('/upload/dataset') :ActionClass('REST') :Args(0) {
    my ( $self, $c ) = @_;
    $c->stash( root => $c->uri_for('/upload/dataset') ); # needed for form action in template
}

sub dataset_GET { # show list + blank form for creating new datasets
    my ( $self, $c ) = @_;
    my $dataset = { };
    my $para = $c->request->params;

    if ( keys %$para ) {
        # we got errors, or maybe a login timeout
        $c->stash( dataset => $para ); # repopulate form
    }

    $c->stash( template => 'upload/dataset.tt' );

}

sub dataset_POST  { # create a new dataset
    my ( $self, $c ) = @_;

    my $para = $c->request->params;
    my $path = "/" . $c->req->match;

    my $row = {
        a_id => $c->stash->{mm_config}->get('APPLICATION_ID'),
        u_id => $c->user->u_id(),
    };

    my $rs = $c->model('Userbase')->resultset('Dataset');

    my $ds_id = eval { $rs->create_ds( $para, $row ) };

    if ($@) {
        # create record failed
        $self->add_error_msgs( $c, error_from_exception($@) );
        $c->response->redirect( $c->uri_for($path, $para ) );
    } else {
        # success - now go back and read dataset from db
        $c->response->redirect( $c->uri_for($path, $ds_id) );
    }
}

# single dataset

sub dataset_x :Path('/upload/dataset') :ActionClass('REST') :Args(1) {
    my ( $self, $c ) = @_;
    $c->stash(
        root => $c->uri_for('/upload/dataset'),
        ds_id => $c->req->args->[0],
    );
}

sub dataset_x_GET { # show editor for a dataset
    my ( $self, $c ) = @_;
    my $dataset = { };
    my $para = $c->request->params;
    my $ds_id = $c->stash->{ds_id};

    if ( keys %$para ) {
        # we got errors, or maybe a login timeout
        $c->stash( dataset => $para );
    } else {
        # a normal dataset lookup
        $dataset = $c->model('Userbase')->resultset('Dataset')->get_ds($ds_id);
        $c->detach( 'Root', 'default' ) unless $dataset; # not found
        my $files = $c->model('Userbase')->resultset('File')->count({
            f_name => { 'like', $$dataset{ds_name} ."%"}
        });
        $c->stash( dataset => $dataset, files => $files );
    }

    $c->stash( template => 'upload/dataset.tt' );

}

sub dataset_x_POST  { # update existing dataset
    my ( $self, $c ) = @_;

    my $para = $c->request->params;
    my $ds_id = $c->stash->{ds_id};
    my $path = "/" . $c->req->match;

    my $row = {
        a_id => $c->stash->{mm_config}->get('APPLICATION_ID'),
        u_id => $c->user->u_id(),
    };

    my $rs = $c->model('Userbase')->resultset('Dataset');

    my $dataset = $rs->find( $ds_id );
    $c->detach( 'Root', 'default' ) unless $dataset; # not found

    if (exists $$para{delete}) {

        eval { $dataset->delete; };
        if ($@) {
            # delete record failed
            $self->add_error_msgs( $c, error_from_exception($@) );
            $c->response->redirect( $c->uri_for($path) );
        } else {
            # success - now go back to dataset list
            $self->logger->debug("Deleted dataset $ds_id");
            $self->add_error_msgs( $c, 'Dataset deleted' );
            $c->response->redirect( $c->uri_for($path) );
        }

    } else { # normal update

        eval { $dataset->set_info_ds($para); };
        if ($@) {
            # update record failed
            $self->add_error_msgs( $c, error_from_exception($@) );
            $c->response->redirect( $c->uri_for($path, $ds_id, $para) );
        } else {
            # success - now go back and read dataset from db
            $c->response->redirect( $c->uri_for($path, $ds_id) );
        }

    }

}

=head2 /upload/help

Help texts for dummies

=cut

sub help :Path('/upload/help') : Args(0) {
    my ( $self, $c ) = @_;

    $c->stash(
        template => 'upload/help.tt',
    );

}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

__PACKAGE__->meta->make_immutable;
