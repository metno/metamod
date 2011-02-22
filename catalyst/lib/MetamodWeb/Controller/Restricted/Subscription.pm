package MetamodWeb::Controller::Restricted::Subscription;

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

use Metamod::Subscription;

use Log::Log4perl qw( get_logger );

BEGIN { extends 'MetamodWeb::BaseController::Base' };

=head1 NAME

MetamodWeb::Controller::Restricted::Subscription - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub auto : Private {
    my ( $self, $c ) = @_;

    $c->stash( section => 'subscription' );
}

sub index : Path('/subscription') : Args(0) {
    my ( $self, $c ) = @_;

    my $model         = $c->model('Userbase');
    my $userid        = $c->user()->id();
    my $subscriptions = $model->resultset('Infouds')->search(
        { 'usertable.u_id' => $userid, 'i_type' => 'SUBSCRIPTION_XML', }, { join => [ 'usertable', 'dataset' ],
         },
    );

    my $mm_subscription = Metamod::Subscription->new();
    my @subscriptions = ();
    while( my $subscription = $subscriptions->next() ){
        my $subs_info = $mm_subscription->_parse_subscription_xml( $subscription->i_content() );
        $subs_info->{ ds_name } = $subscription->dataset->ds_name();
        push @subscriptions, $subs_info;
    }

    $c->stash( subscriptions => \@subscriptions );
    $c->stash( template => 'subscription/list_subscription.tt' );

}

sub subscription :Path("/subscription") :Args(1) :ActionClass('REST') {
    my ( $self, $c, $ds_name ) = @_;

    $c->stash( ds_name => $ds_name );
}

sub subscription_GET : Private  {
    my ( $self, $c ) = @_;

    my $user = $c->user();

    my $email = $c->request->param('email');
    my $repeated_email = $c->request->param('repeated_email');

    if( !$email && !$repeated_email ){
        $email = $user->u_email();
        $repeated_email = $email;
    }

    my $ds_name = $c->stash->{ ds_name };

    $c->stash( email => $email );
    $c->stash( repeated_email => $repeated_email );
    $c->stash( template => 'subscription/new_subscription_form.tt' );

}

sub subscription_POST :Private {
    my ( $self, $c ) = @_;

    # We need to do this dispatching our selves since browsers do not support
    # the HTTP DELETE method
    return $c->forward('subscription_DELETE') if( 1 == $c->req->param('do_delete') );

    my $ds_name = $c->stash->{ds_name};
    my $email = $c->req->param('email');
    my $repeated_email = $c->req->param( 'repeated_email');

    if( $email ne $repeated_email ){
        $self->add_error_msgs($c, 'Email addresses are not identical. Subscription not stored' );
        return $c->res->redirect($c->uri_for('/subscription', $ds_name, $c->req->params ) );
    }


    my $user_db = $c->model('Userbase');
    my $mm_config = $c->stash->{ mm_config };
    my $applic_id = $mm_config->get('APPLICATION_ID');
    my $dataset = $user_db->resultset('Dataset')->find( { a_id => $applic_id, ds_name => $c->stash->{ds_name} } );

    if( !$dataset ){
        $self->add_error_msgs($c, 'The dataset name is not found in the database' );
        return $c->res->redirect($c->uri_for('/subscription', $ds_name, $c->req->params ) );
    }

    my $subscription_xml = <<END_XML;
<subscription type="email" xmlns="http://www.met.no/schema/metamod/subscription">
<param name="address" value="$email" />
</subscription>
END_XML

    my $user = $c->user();
    my $info_uds = {
        u_id => $user->u_id,
        ds_id => $dataset->ds_id,
        i_type => 'SUBSCRIPTION_XML',
        i_content => $subscription_xml,
    };

    $user_db->resultset('Infouds' )->update_or_create( $info_uds );

    $c->res->redirect( $c->uri_for('/subscription' ) );

}

sub subscription_DELETE : Private {
    my ($self, $c) = @_;

    my $user = $c->user();
    my $user_db = $c->model('Userbase');
    my $mm_config = $c->stash->{ mm_config };
    my $applic_id = $mm_config->get('APPLICATION_ID');
    my $dataset = $c->model('Userbase::Dataset')->find( { a_id => $applic_id, ds_name => $c->stash->{ds_name} } );

    my $ds_id = $dataset->ds_id();
    my $u_id = $user->u_id();

    my $subscriptions = $c->model('Userbase::Infouds')->search( { ds_id => $ds_id, u_id => $u_id, i_type => 'SUBSCRIPTION_XML' } );

    if( $subscriptions->count() != 1 ){
        get_logger()->debug("The number of matching subscriptions where wrong:" . $subscriptions->count() );
    }

    $subscriptions->delete_all();

    $self->add_info_msgs($c, 'The subscription has been deleted' );

    $c->res->redirect( $c->uri_for('/subscription' ) );

}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

__PACKAGE__->meta->make_immutable;

