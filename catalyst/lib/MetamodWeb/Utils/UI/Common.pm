package MetamodWeb::Utils::UI::Common;

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

use Data::Dump qw( dump );
use Moose;
use namespace::autoclean;
use URI::Escape;

=head1 NAME

MetamodWeb::Utils::UI::Common - Utility functions used for building the UI common for most pages

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 FUNCTIONS/METHODS

=cut

extends 'MetamodWeb::Utils::UI::Base';

=head2 $self->app_menu()

=over

=item return

Returns the APP_MENU configuration variable as a hash reference. The key is the
text to display and the value is the link for the item.

=back

=cut
sub app_menu {
    my $self = shift;

    my $menu_items = $self->config->get('APP_MENU');
    my @items = split '\n', $menu_items;

    # mapping between name to show and the link url
    my %items = ();
    foreach my $item (@items) {
        if ( $item =~ /^\s*([^\s]+)\s+(.*)$/ ) {
            my ($link, $label, $appid) = ( $1, $2, $self->config->get('LOCAL_URL') );
            if ($link =~ /^$appid(.+)$/) {
                # web link, presumably Catalyst [TO BE REMOVED]
                $items{$label} = $self->c->uri_for($1); # makes link work both in Catalyst and Apache
            } else {
                # external link, copy verbatim
                $items{$label} = $link;
            }
            #printf STDERR "%s %s\n", $label, $link;
        }
    }
    return \%items;

}

=head2 $self->stringify_params($params)

Make an URL escaped version of the request parameters. Usefull when you need to
keep the current request parameters across several request.

=over

=item $params

A hash reference with the CGI parameters that you want to stringify. All values
will be URI escaped.

=item return

The stringified version of the parameters.

=back

=cut
sub stringify_params {
    my $self = shift;

    my ($params) = @_;

    my $params_string = '';
    while( my ( $key, $value ) = each %$params ){
        $params_string .= "$key=" . uri_escape($value) . "&";
    }
    chop $params_string;

    return $params_string;

}

__PACKAGE__->meta->make_immutable;

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
