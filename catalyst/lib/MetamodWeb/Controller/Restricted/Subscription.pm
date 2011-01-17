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

BEGIN { extends 'Catalyst::Controller' };

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

    $c->stash( my_metamod_menu => 1 );

}

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    $c->detach('list_subscriptions');

}

sub list_subscriptions : Private {
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

sub ds_name :Chained("/") :PathPart("subscription") :CaptureArgs(1) {
    my ( $self, $c ) = @_;

    $c->stash( ds_name => $c->request->args->[0] );
}

sub display_new_subscription :Chained("ds_name") :PathPart('new') :Args(0)  {
    my ( $self, $c ) = @_;

    my $user = $c->user(); #$self->_get_user( $c );

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

sub store_new_subscription : Chained("ds_name") :PathPart('store_new') : Args(0) {
    my ( $self, $c ) = @_;

    my $email = $c->req->param('email');
    my $repeated_email = $c->req->param( 'repeated_email');

    if( $email ne $repeated_email ){
        $c->stash( error_msg => 'Email addresses are not identical. Subscription not stored' );
        $c->detach( 'Subscription', 'display_new_subscription');
    }


    my $user_db = $c->model('Userbase');
    my $mm_config = $c->stash->{ mm_config };
    my $applic_id = $mm_config->get('APPLICATION_ID');
    my $dataset = $user_db->resultset('Dataset')->find( { a_id => $applic_id, ds_name => $c->stash->{ds_name} } );

    if( !$dataset ){
        $c->stash( error_msg => 'The dataset name is not found in the database' );
        $c->detach( 'Subscription', 'display_new_subscription');
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

    $user_db->resultset('Infouds' )->create( $info_uds );

    $c->forward( 'Subscription', 'list_subscriptions' );

}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

__PACKAGE__->meta->make_immutable;

