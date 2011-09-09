package MetamodWeb::Utils::UI::Questionnaire;

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

use File::Spec;
use JSON;
use Moose;
use namespace::autoclean;

use warnings;

extends 'MetamodWeb::Utils::UI::Base';

=head1 NAME

MetamodWeb::Utils::UI::DatasetAdmin - Utility functions for building the dataset admin UI.

=head1 FUNCTIONS/METHODS

=cut

=head2 $self->gcmdlist($quest_element)

Get the gcmd option list for a questionnaire element of type gcmdlist.

=over

=item $quest_element

The questionnaire element to get the list for. The element is expected to be a
hash reference with the required key 'value' which hold the relative filename
of the file with all the list elements. The filename should be relative to the
base target directory. In addition the keys 'exclude' and 'include' are
supported which will remove or add elements respectively.

=item return

A reference to a list with all the keywords.

=back

=cut

sub gcmdlist {
    my $self = shift;

    my ( $quest_element ) = @_;

    my $file = $quest_element->{ value };
    my $full_path = $self->config->path_to_config_file($file, 'etc', 'qst');
    if( !(-r $full_path ) ){
        die "Cannot find file '$full_path'";
    }

    open my $LIST_FILE, '<', $full_path;
    my @gcmdlist = <$LIST_FILE>;
    chomp(@gcmdlist);

    # remove comments
    @gcmdlist = grep { !( /^\s*#/ ) } @gcmdlist;

    if( exists $quest_element->{exclude}){
        foreach my $name (@{ $quest_element->{ exclude } } ){
            @gcmdlist = grep { !( /^$name/ ) } @gcmdlist;
        }
    }

    if( exists $quest_element->{include} ){
        push @gcmdlist, @{ $quest_element->{include} };
    }

    return \@gcmdlist;

}

__PACKAGE__->meta->make_immutable;

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
