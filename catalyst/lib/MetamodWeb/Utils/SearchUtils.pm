package MetamodWeb::Utils::SearchUtils;

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

use warnings;

#
# A Metamo::Config object containing the configuration for the application
#
has 'config' => ( is => 'ro', isa => 'Metamod::Config', required => 1 );

#
# A Catalyst context object.
#
has 'c' => (
    is       => 'ro',
    required => 1,
    handles  => {
        meta_db => [ model => 'Metabase' ],
        user_db => [ model => 'Usebase' ],
    }
);



=head1 NAME

MetamodWeb::Utils::SearchUtils - Utilities for search.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 FUNCTIONS/METHODS

=cut

=head2 $self->selected_criteria($parameters)

Transforms the request parameters into a hash reference for all the search criteria.

=over

=item $parameters

A reference to a hash reference of HTTP request parameters.

=item return

A hash reference containing all the selected criteria. The following keys are
used:

C<basickeys>: The value is a list of lists. Each list related to one basickey.

C<freetext>: The value is a list of words to search.

C<dates>: The value is hash with categories as keys and the value is a hash
with to and from dates.

C<coords>: The value is a hash having the keys srid, x1, x2, y1, y2.

C<topics>: The value is a hash with the keys hk_ids and bk_ids. The values in
the internal has is a list of hk ids and bk ids.

=back

=cut
sub selected_criteria {
    my $self = shift;

    my ($parameters) = @_;

    my %criteria = ();
    my %bk_ids = ();
    my @freetext = ();
    my %dates = ();
    my %coords = ();
    my @topic_hks = ();
    my @topic_bks = ();
    while( my ( $key, $value) = each %$parameters ){

        if( $key =~ /^bk_id_(\d+)_(\d+)$/ ){
            push @{ $bk_ids{ $1 } }, $2;
        } elsif( $key =~ /^date_(to|from)_(\d+)$/) {

            my $datetype = $1;
            my $category_id = $2;
            if( $value ){

                my $total_length = 8;
                $value =~ s|-||g;

                # the comparison is done using integers that are 8 digits long so we
                # must pad the shorter ones
                $value .= '0' x ($total_length - length($value) ) if $datetype eq 'from';
                $value .= '9' x ($total_length - length($value) ) if $datetype eq 'to';

                $dates{ $category_id }->{ $datetype } = $value if $value;

            }


        }elsif( $key =~ /^freetext_(\d+)$/ ){
            push @freetext, $value if $value;
        }elsif( $key =~ /^map_coord_(\w\d)$/ ){
            $coords{$1} = $value;
        }elsif( $key =~ /^selected_map$/ ){
            $coords{srid} = $value;
        }elsif( $key =~ /^hk_id_(\d+)$/ ){
            push @topic_hks, $1;
        }elsif( $key =~ /^bk_id_topic_(\d+)$/ ){
            push @topic_bks, $1;
        }
    }

    if( %bk_ids ){
        # get the list of basic keys for each category
        my @bk_lists = map { $bk_ids{ $_ } } keys %bk_ids;
        $criteria{ basickey } = \@bk_lists;
    }

    $criteria{ freetext } = \@freetext if @freetext;

    $criteria{ dates } = \%dates if %dates;

    $criteria{ coords } = \%coords if %coords;

    if( @topic_hks || @topic_bks ){
        $criteria{ topics } = { hk_ids => \@topic_hks, bk_ids => \@topic_bks };
    }

    return \%criteria;
}

sub get_ownertags {
    my $self = shift;

    my @ownertags;
    my $ownertags = $self->config->get('DATASET_TAGS');
    if (defined $ownertags) {
        # comma-separated string
        @ownertags = split /\s*,\s*/, $ownertags;
        # remove '' around tags
        @ownertags = map {s/^'//; s/'$//; $_} @ownertags;
    }
    return \@ownertags;
}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
