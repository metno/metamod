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

    return 1;
}


sub check_config : Chained('/') : PathPart('editor') : CaptureArgs(1) {
    my ( $self, $c, $config_id ) = @_;

    my $quest_utils = $c->stash->{quest_utils};
    my $config      = $quest_utils->config_for_id($config_id);

    if ( !defined $config ) {
        die 'Invalid config';
    }

    $c->stash( quest_config => $config, quest_config_file => $config->{config_file}, config_id => $config_id );

}

sub validate_response : Private {
    my ( $self, $c ) = @_;

    my $quest_utils   = $c->stash->{quest_utils};
    my $config_file   = $c->stash->{quest_config_file};

    my $validation_profile = $quest_utils->quest_validator($config_file);
    my $validator          = MetamodWeb::Utils::FormValidator->new( validation_profile => $validation_profile );
    my $validation_res     = $validator->validate($c->req->params);

    $c->stash( validator => $validator );
    return $validation_res;

}

sub questionnaire : Chained('check_config') : PathPart('') : Args(0) : ActionClass('REST') {
    my ($self, $c ) = @_;

}

sub questionnaire_GET :Private {
    my ( $self, $c ) = @_;

    my $quest_utils = $c->stash->{quest_utils};
    my $config_id   = $c->stash->{config_id};

    my $response_key = $c->req->params->{response_key};
    if ($response_key) {

        my $current_data    = $quest_utils->load_anon_metadata( $config_id, $response_key ) || {};
        my %merged_response = ( %$current_data, %{ $c->req->params() } );
        $c->stash(
            template       => 'questionnaire/questionnaire.tt',
            quest_data     => \%merged_response,
            quest_save_url => $c->uri_for( '/editor', $config_id, ),
        );
    } else {
        $c->stash( template => 'questionnaire/start_quest.tt' );
    }

}

sub questionnaire_POST : Private {
    my ( $self, $c ) = @_;

    my $config_id    = $c->stash->{config_id};
    my $response_key = $c->req->params->{response_key};

    my $quest_utils = $c->stash->{quest_utils};
    my $result    = $self->validate_response($c);
    my $quest_data = $result->valid();

    if ( !$result->success() ) {
        $self->add_form_errors($c, $c->stash->{validator});
        return $c->res->redirect( $c->uri_for( '/editor', $config_id, $c->req->params ) );
    }

    my $success = $quest_utils->save_anon_metadata( $config_id, $response_key, $quest_data );
    if ($success) {
        my $msg = "Thank you. Your response has been save. Use '$response_key' if you want to edit your response later.";
        $self->add_info_msgs( $c, $msg );
    } else {
        $self->add_error_msgs( $c, 'Failed to save the response because of an error. Please contact the administrator.' );
    }

    return $c->res->redirect( $c->uri_for( '/editor', $config_id, { response_key => $response_key } ) );

}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

__PACKAGE__->meta->make_immutable;

1;
