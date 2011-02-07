package MetamodWeb::Controller::Admin;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

MetamodWeb::Controller::Admin - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched MetamodWeb::Controller::Admin in Admin.');
}

=head2 menu

=cut

sub adminmenu :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->stash(template => 'admin/adminmenu.tt');
    $c->stash(use_admin_wrapper => 1);
#    my $config = $c->stash( "mm_config" );
}


=head1 AUTHOR

Egil Støren

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
