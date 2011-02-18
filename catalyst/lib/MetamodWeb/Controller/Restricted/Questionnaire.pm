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
use Log::Log4perl qw(get_logger);

use MetamodWeb::Utils::QuestionnaireUtils;
use MetamodWeb::Utils::UI::Questionnaire;

=head1 NAME

MetamodWeb::Restricted::Editor - Controller for the restricted part of the metadata editor.

=head1 DESCRIPTION

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

    my $validator = $c->flash->{validator};
    $c->stash( validator => $validator ) if defined $validator;
    return 1;

}


sub view_metadata :Chained('/questionnaire/check_config') :PathPart('restricted/view') :Args(1) {
    my ( $self, $c, $userbase_ds_id ) = @_;

    my $config_id = $c->stash->{config_id};
    my $quest_utils = $c->stash->{quest_utils};
    my $current_data = $quest_utils->load_dataset_metadata( $userbase_ds_id );

    if(!defined $current_data){
        return 'Not valid dataset';
    }

    my $config = $quest_utils->config_for_id($config_id);

    my $quest_response  = $quest_utils->quest_data();
    my %merged_response = ( %$current_data, %$quest_response );

    $c->stash(
            quest_config_file => $config->{ config_file },
            template   => 'questionnaire/questionnaire.tt',
            quest_data => \%merged_response,
            quest_save_url => $c->uri_for( '/editor', $config_id, 'restricted', 'save', $userbase_ds_id ),
        );

}

sub save_metadata :Chained('/questionnaire/check_config') :PathPart('restricted/save') :Args(1) {
    my ($self, $c, $userbase_ds_id ) = @_;

    my $config_id   = $c->stash->{config_id};
    my $quest_utils = $c->stash->{quest_utils};
    my $quest_data  = $quest_utils->quest_data();
    my $is_valid    = $c->forward('MetamodWeb::Controller::Questionnaire', 'validate_response', [ $quest_data ] );

    if( !$is_valid ) {
        return $c->res->redirect($c->uri_for('/editor', $config_id, 'restricted/view', $userbase_ds_id, $c->req->params ));
    }

    my $success = $quest_utils->save_dataset_metadata( $userbase_ds_id, $quest_data );
    if ($success) {
        my $msg = "Thank you. You response has been saved.";
        $self->add_info_msgs( $c, $msg );
    } else {
        $self->add_error_msgs( $c, 'Failed to save the response on the error. Please contact the administrator.' );
    }

    return $c->res->redirect($c->uri_for('/editor', $config_id, 'restricted/view', $userbase_ds_id ));

}


=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

__PACKAGE__->meta->make_immutable;

1;
