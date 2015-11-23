package Metamod::SearchUtils;

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

=head1 NAME

Metamod::SearchUtils - Utilities for constructing search arguments

=head1 SYNOPSIS

Blah blah blah FIXME

=head1 DESCRIPTION

Blah blah blah FIXME

=head1 FUNCTIONS/METHODS

=cut

use Moose;
use namespace::autoclean;
use Data::Dumper;
use List::Flatten;
use warnings;

#
# A Metamod::Config object containing the configuration for the application
#
has 'config' => ( is => 'ro', isa => 'Metamod::Config', required => 1 );

=head2 $self->selected_criteria($parameters)

Transforms the request parameters into a hash reference for all the search criteria.

=over

=item $parameters

A reference to a hash reference of parameters (CGI query or command line)

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

        if ( $key =~ /^bk_id_(\d+)_(\d+)$/ ) {
            push @{ $bk_ids{ $1 } }, $2;
        } elsif ( $key =~ /^date_(to|from)_?(\d+)?$/ ) {

            my $datetype = $1;
            my $category_id = $2 || 8; # currently hardcoded in Datasetimporter.pm
            if( $value ){

                my $total_length = 8;
                $value =~ s|-||g;

                # the comparison is done using integers that are 8 digits long so we
                # must pad the shorter ones
                $value .= '0' x ($total_length - length($value) ) if $datetype eq 'from';
                $value .= '9' x ($total_length - length($value) ) if $datetype eq 'to';

                $dates{ $category_id }->{ $datetype } = $value if $value;

            }


        } elsif ( $key =~ /^freetext_?(\d*)$/ ) {
            push @freetext, flat $value if $value;
        } elsif ( $key =~ /^map_coord_(\w\d)$/ ) {
            $coords{$1} = $value;
        } elsif ( $key =~ /^selected_map$/ ) {
            $coords{srid} = $value;
        } elsif ( $key =~ /^hk_id_(\d+)$/ ) {
            push @topic_hks, $1;
        } elsif ( $key =~ /^bk_id_topic_(\d+)$/ ) {
            push @topic_bks, $1;
        }
        # remaining cases are experimental
        elsif ( $key =~ /^hk$/ ) {
            push @topic_hks, ref $value ? @$value : split ',', $value; # allow both hk=x&hk=y and hk=x,y
        } elsif ( $key =~ /^basickey$/ ) {
            push @topic_bks, ref $value ? @$value : split ',', $value; # allow both bk=x&bk=y and bk=x,y;
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

=head2 $self->get_ownertags()

=over

=item return

Returns a list of ownertags that should be used in the search conditions. The
ownertags are found by looking at DATASET_TAGS in master_config.txt

=back

=cut
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

=head2 $self->dist_statements()

=over

=item return

Returns a list of distribution statements that can be downloaded via the
collection basket.

=back

=cut

sub dist_statements {
    my $self = shift;

    my $dist_statments = $self->config->get('COLLECTION_BASKET_DIST_STATEMENTS');
    my @dist_statements = split ',', $dist_statments;
    my %dist_statements = map { lc(trim($_)) => 1 } @dist_statements;

    return \%dist_statements;

}

=head2 $self->freely_available($dataset)

Check whether a dataset is freely available or not.

=over

=item $file

A basket item hashref

=item return

Returns true if the dataset is freely available according its distribution
statement and the configuration variable COLLECTION_BASKET_DIST_STATEMENTS.

=back

=cut

sub freely_available {
    my $self = shift;

    my ($file) = @_;

    #print STDERR "++++++++++++" . Dumper \$file;

    if(!exists $file->{distribution_statement}){
        return 1;
    }

    my $dist_statements = $self->dist_statements();
    my $dist_statement = lc(trim($file->{distribution_statement}));

    return 1 if exists $dist_statements->{$dist_statement};

    return;

}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
