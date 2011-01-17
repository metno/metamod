package MetamodWeb::Controller::Restricted::DatasetAdmin;

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

BEGIN { extends 'Catalyst::Controller'; }

use Metamod::Dataset;
use MetamodWeb::Utils::FormValidator;
use MetamodWeb::Utils::UI::DatasetAdmin;
use MetamodWeb::Form::DatasetEdit;

=head1 NAME

MetamodWeb::Controller::DatasetAdmin - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

has 'dataset_form' => (
    isa     => 'MetamodWeb::Form::DatasetEdit',
    is      => 'rw',
    lazy    => 1,
    default => sub { MetamodWeb::Form::DatasetEdit->new() }
);

sub auto : Private {
    my ( $self, $c ) = @_;

    my $da_ui_utils = MetamodWeb::Utils::UI::DatasetAdmin->new( c => $c, config => $c->stash->{mm_config} );
    $c->stash( da_ui_utils => $da_ui_utils );

    return $self->SUPER::auto($c);

}

sub list : Path('/dataset_admin') : Args(0) {
    my ( $self, $c ) = @_;

    $c->stash( template => 'dataset_admin/list_datasets.tt' );

}

sub create : Path('/dataset_admin/create') : Args(0) {
    my ( $self, $c ) = @_;

    $c->stash(
        template            => 'dataset_admin/edit_dataset.tt',
        dataset_form        => $self->dataset_form(),
        page_header         => 'Create new dataset',
        submit_button_value => 'Create',
        form_action         =>  $c->uri_for('/dataset_admin/store_new'),
    );

    # we need to clear the form to ensure that any data from a previous edit is removed.
    $self->dataset_form()->clear();
}

sub store_new : Path('/dataset_admin/store_new') : Args(0) {
    my ( $self, $c ) = @_;

    my $form_params = $c->req->parameters;
    $form_params->{u_id} = $c->user->u_id();
    $form_params->{a_id} = $c->user->a_id();
    $self->dataset_form->params($form_params);

    if ( $self->dataset_form()->process( params => $form_params, schema => $c->model('Userbase') ) ) {
        $c->flash->{status_msg} = 'Dataset created';
        $c->response->redirect( $c->uri_for('/dataset_admin') );
    } else {
        $c->detach('create');
    }
}

sub dataset_id : Chained(""): PathPart("dataset_admin") : CaptureArgs(1) {
    my ( $self, $c, $ds_id ) = @_;

    my $ds = $c->model('Userbase::Dataset')->find($ds_id);
    if ( !defined $ds ) {
        $c->response->body('Dataset not found');
        $c->response->status(404);
        return;
    }

    $c->stash->{ ds_id } = $ds_id;
    $c->stash->{ ds } = $ds;

}

sub edit_dataset :Chained("dataset_id") :PathPart("edit") : Args(0) {
    my ( $self, $c ) = @_;

    my $ds_id = $c->stash->{ ds_id };

    my $ds = $c->stash->{ ds };

    $c->stash(
        template            => 'dataset_admin/edit_dataset.tt',
        dataset_form        => $self->dataset_form(),
        page_header         => 'Edit dataset',
        submit_button_value => 'Save',
        form_action         =>  $c->uri_for('/dataset_admin/' . $ds_id . '/edit'),
    );

    if ( !$self->dataset_form()->process( params => $c->req->params, schema => $c->model('Userbase'), item => $ds )
        ) {
        return;
    }

    $c->flash->{status_msg} = 'Dataset has been updated', $c->response->redirect( $c->uri_for('/dataset_admin/') );

}

sub view_questionnaire :Chained("dataset_id") :PathPart("questionnaire") :Args(0) {
    my ( $self, $c ) = @_;

    my $config = $c->stash->{ mm_config };
    my $quest_config_file = $config->get('QUEST_FORM_DEFINITON_FILE');
    my $metadata_directory = $config->get('QUEST_OUTPUT_DIRECTORY');
    my $ds_name = $c->stash->{ds}->ds_name();

    my %metadata = ();
    my $metamod_ds = $self->metamod_dataset( $c, $metadata_directory, $ds_name) ;
    if( defined $metamod_ds ){
        %metadata = $metamod_ds->getMetadata();
    }

    while( my ($name, $value) = each %{ $c->req->params } ){

        if( $name =~ /^metadata_(.*)$/ ){
            my $metadata_name = $1;

            if( !ref $value ){
                $metadata{ $metadata_name } = [ $value ];
            } elsif( ref $value eq 'ARRAY' ){
                $metadata{ $metadata_name } = $value;
            }
        }
    }

    $c->stash(
        template => 'dataset_admin/questionnaire.tt',
        quest_config_file => $quest_config_file,
        metadata => \%metadata,
        css_files => [ $c->uri_for( '/static/css/quest.css' ) ],
    );

}

sub edit_metadata :Chained("dataset_id") :PathPart('edit_metadata') :Args(0) {
    my ($self, $c) = @_;

    my $config = $c->stash->{ mm_config };
    my $quest_config_file = $config->get('QUEST_FORM_DEFINITON_FILE');
    my $da_ui_utils = $c->stash->{ da_ui_utils };
    my $form_profile = $da_ui_utils->quest_validator($quest_config_file);

    # fetch only the relevant metadata to be stored.
    my %metadata_params = ();
    while( my ($name, $value) = each %{ $c->req->params } ){
        if( $name =~ /^metadata_(.*)$/ ){
            $metadata_params{ $1 } = $value;
        }
    }

    my $validator = MetamodWeb::Utils::FormValidator->new( validation_profile => $form_profile);
    my $validation_res = $validator->validate(\%metadata_params);
    if( $validation_res->has_invalid() || $validation_res->has_missing() ){
        $c->stash( validator => $validator );
        $c->forward('view_questionnaire');
    }

    my $metadata_directory = $config->get('QUEST_OUTPUT_DIRECTORY');
    my $ds_name = $c->stash->{ds}->ds_name();
    my $metamod_ds = $self->metamod_dataset( $c, $metadata_directory, $ds_name );
    $self->save_metadata( $c, $metamod_ds, \%metadata_params );

    $c->forward('view_questionnaire');

}

sub metamod_dataset :Private {
    my ($self, $c, $metadata_directory, $ds_name) = @_;

    my $dataset_basename = "${metadata_directory}/${ds_name}";
    if( -r "${dataset_basename}.xmd" ){
        return Metamod::Dataset->newFromFile($dataset_basename);
    } else {
        $c->log->info("Could not find read the file ${dataset_basename}.xmd");
        return;
    }
}

sub save_metadata :Private {
    my ( $self, $c, $metamod_ds, $metadata ) = @_;

    my @info_tags = qw(
        name
        drpath
        creationDate
        datestamp
        ownertag
        status
        metadataFormat
        quadtree_nodes
    );

    my %info = ();
    foreach my $tag (@info_tags){

        my $info_tag = $tag;

        # drpath is a special case that is an alias for name
        $info_tag = 'name' if $tag eq 'drpath';

        if( exists $metadata->{ $tag } ){
            $info{$info_tag} = $metadata->{$tag};
        }
    }

    #metamod_ds->setInfo( \%info );


}

__PACKAGE__->meta->make_immutable;

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
