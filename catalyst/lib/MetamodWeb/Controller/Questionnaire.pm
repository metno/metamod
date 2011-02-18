package MetamodWeb::Controller::Questionnaire;

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

use MetamodWeb::Utils::QuestionnaireUtils;
use MetamodWeb::Utils::UI::Questionnaire;

BEGIN { extends 'MetamodWeb::BaseController::Base'; }

=head1 NAME

MetamodWeb::Controller::Questionnaire - Controller for viewing a questionnaire and storing answers.

=head1 DESCRIPTION

=head1 FUNCTIONS/METHODS

=cut

sub auto : Private {
    my ( $self, $c ) = @_;

    my $quest_utils = MetamodWeb::Utils::QuestionnaireUtils->new( c => $c );
    my $quest_ui_utils = MetamodWeb::Utils::UI::Questionnaire->new( c => $c );
    $c->stash(
        quest_utils    => $quest_utils,
        quest_ui_utils => $quest_ui_utils,
    );

}

sub display_questionnaire : Private {
    my ( $self, $c ) = @_;

    my $config_id   = $c->stash->{config_id};
    my $quest_utils = $c->stash->{quest_utils};
    my $config_file = $quest_utils->config_for_id($config_id);
    $c->stash( quest_config_file => $config_file );

    my $response_key = $c->req->params->{response_key};
    if ($response_key) {

        my $current_data    = $c->stash->{current_data};
        my $quest_response  = $quest_utils->quest_data();
        my %merged_response = ( %$current_data, %$quest_response );

        $c->stash(
            template   => 'questionnaire/questionnaire.tt',
            quest_data => \%merged_response,
        );

    } else {
        $c->stash( template => 'questionnaire/start_quest.tt' );
    }
}

sub validate_response : Private {
    my ($self, $c, $config_id, $response_data) = @_;

    my $quest_utils = $c->stash->{quest_utils};
    my $config_file = $quest_utils->config_for_id($config_id);

    my $validation_profile = $quest_utils->quest_validator($config_file);
    my $validator          = MetamodWeb::Utils::FormValidator->new( validation_profile => $validation_profile );
    my $validation_res     = $validator->validate($response_data);

    if ( $validation_res->has_invalid() || $validation_res->has_missing() ) {
        $c->stash( validator => $validator );
        return;
    }

    return 1;

}

sub view_metadata : Path('/editor') : Args(1) {
    my ( $self, $c, $config_id ) = @_;

    $c->stash( config_id => $config_id );

    my $response_key = $c->req->params->{response_key};
    if ($response_key) {

        my $quest_utils = $c->stash->{quest_utils};
        my $current_data = $quest_utils->load_anon_metadata( $config_id, $response_key ) || {};
        $c->stash(
            current_data   => $current_data,
            quest_save_url => $c->uri_for( '/editor', 'save', $config_id ),
        );
    }

    $c->forward('display_questionnaire');

}

sub save_metadata : Path('/editor/save') : Args(1) {
    my ( $self, $c, $config_id ) = @_;

    my $response_key = $c->req->params->{response_key};

    my $quest_utils = $c->stash->{quest_utils};
    my $quest_data  = $quest_utils->quest_data();
    my $is_valid    = $c->forward('validate_response', [ $config_id, $quest_data ] );

    if( !$is_valid ) {
        $c->detach('view_metadata');
    }

    my $success = $quest_utils->save_anon_metadata( $config_id, $response_key, $quest_data );
    if ($success) {
        my $msg = "Thank you. You response has been save. Use '$response_key' if you want to edit your response later.";
        $self->add_info_msgs( $c, $msg );
    } else {
        $self->add_error_msgs( $c, 'Failed to save the response on the error. Please contact the administrator.' );
    }

    $c->forward('view_metadata');

}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

__PACKAGE__->meta->make_immutable;

1;
