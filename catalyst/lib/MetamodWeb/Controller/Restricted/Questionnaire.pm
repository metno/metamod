package MetamodWeb::Controller::Restricted::Questionnaire;

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

use strict;
use warnings;

use Moose;
use namespace::autoclean;

BEGIN {extends 'MetamodWeb::BaseController::Base'; }

use Data::Dump qw(dump);

use MetamodWeb::Utils::QuestionnaireUtils;
use MetamodWeb::Utils::UI::Questionnaire;

=head1 NAME

MetamodWeb::Restricted::Editor - Controller for the restricted part of the metadata editor.

=head1 DESCRIPTION

Is this operational? Has it ever worked?

=head1 FUNCTIONS/METHODS

=cut

sub auto : Private {
    my ($self, $c) = @_;

    my $quest_utils = MetamodWeb::Utils::QuestionnaireUtils->new( c => $c );
    my $quest_ui_utils = MetamodWeb::Utils::UI::Questionnaire->new( c => $c );
    $c->stash(
        quest_utils    => $quest_utils,
        quest_ui_utils => $quest_ui_utils,
    );

    return 1;

}

sub questionnaire :Chained('/questionnaire/check_config') :PathPart('restricted') :Args(1) :ActionClass('REST') {
    my ( $self, $c, $userbase_ds_id ) = @_;


}

sub questionnaire_GET :Private {
    my ( $self, $c, $userbase_ds_id ) = @_;

    my $config_id = $c->stash->{config_id};
    my $quest_utils = $c->stash->{quest_utils};
    my $current_data = $quest_utils->load_dataset_metadata( $userbase_ds_id );

    if(!defined $current_data){
        return $c->forward('Root', 'default');
    }

    my $config = $quest_utils->config_for_id($config_id);

    my %merged_response = ( %$current_data, %{ $c->req->params } );

    $c->stash(
            quest_config_file => $config->{ config_file },
            template   => 'questionnaire/questionnaire.tt',
            quest_data => \%merged_response,
            quest_save_url => $c->uri_for( '/editor', $config_id, 'restricted', $userbase_ds_id ),
        );

}

sub questionnaire_POST :Private {
    my ($self, $c, $userbase_ds_id ) = @_;

    my $config_id   = $c->stash->{config_id};
    my $quest_utils = $c->stash->{quest_utils};
    my $config_file   = $c->stash->{quest_config_file};

    my $validation_profile = $quest_utils->quest_validator($config_file);
    my $validator          = MetamodWeb::Utils::FormValidator->new( validation_profile => $validation_profile );
    my $result             = $validator->validate($c->req->params);

    if( !$result->success() ) {
        $self->add_form_errors($c, $validator );
        return $c->res->redirect($c->uri_for('/editor', $config_id, 'restricted', $userbase_ds_id, $c->req->params ));
    }
    my $quest_data = $result->valid();

    my $success = $quest_utils->save_dataset_metadata( $config_id, $userbase_ds_id, $quest_data );
    if ($success) {
        my $msg = "Dataset has been updated.";
        $self->add_info_msgs( $c, $msg );
        return $c->res->redirect($c->uri_for('/upload/dataset' ));
    } else {
        $self->add_error_msgs( $c, 'Failed to save the response because of an error. Please contact the administrator.' );
        return $c->res->redirect($c->uri_for('/editor', $config_id, 'restricted', $userbase_ds_id ));
    }



}


=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

__PACKAGE__->meta->make_immutable;

1;
