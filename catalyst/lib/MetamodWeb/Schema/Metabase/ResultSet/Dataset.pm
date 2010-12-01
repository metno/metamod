package MetamodWeb::Schema::Metabase::ResultSet::Dataset;

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

use base 'MetamodWeb::Schema::Resultset';

use Data::Dump qw( dump );
use Log::Log4perl qw( get_logger );
use Params::Validate qw( :all );

sub metadata_search {
    my $self = shift;

    my %params = validate(
        @_,
        {
            curr_page       => { type => SCALAR, optional => 1 },
            ownertags       => { type => ARRAYREF },
            rows_per_page   => { type => SCALAR, optional => 1 },
            search_criteria => { type => HASHREF },
            all_levels      => { type => SCALAR, default => 0 },
        }
    );
    my ( $all_levels, $curr_page, $ownertags, $rows_per_page, $search_criteria ) =
        @params{qw( all_levels curr_page ownertags rows_per_page search_criteria )};

    my %search_cond  = ();
    my @ds_ids_conds = ();

    if ( exists $search_criteria->{basickey} ) {

        my $bk_describes_ds_rs = $self->result_source->schema->resultset('BkDescribesDs');

        my $key_lists = $search_criteria->{basickey};
        foreach my $bk_ids (@$key_lists) {

            my $basickey_search = $bk_describes_ds_rs->search( { bk_id => { IN => $bk_ids } } );
            my %cond = ( IN => $basickey_search->get_column('ds_id')->as_query() );

            push @ds_ids_conds, \%cond;
        }

    }

    if ( exists $search_criteria->{dates} ) {

        my $numberitem_rs = $self->result_source->schema->resultset('Numberitem');
        while ( my ( $sc_id, $date ) = each %{ $search_criteria->{dates} } ) {

            my $numberitem_search = $numberitem_rs->search(
                {
                    sc_id   => $sc_id,
                    ni_from => { '<=' => $date->{to} },
                    ni_to   => { '>=', $date->{from} },

                }
            );
            my %cond = ( IN => $numberitem_search->get_column('ds_id')->as_query() );
            push @ds_ids_conds, \%cond;
        }

    }

    if ( exists $search_criteria->{freetext} ) {

        my $termlist       = $search_criteria->{freetext};
        my @fulltext_conds = ();
        foreach my $term (@$termlist) {
            my $condition = {
                -or => {
                    'md_id.md_content_vector' => $self->fulltext_search($term),
                    'me.ds_name'              => { LIKE => '%' . $term . '%' }
                }
            };
            push @fulltext_conds, $condition;
        }
        push @{ $search_cond{ -and } }, \@fulltext_conds;
    }

    if( exists $search_criteria->{ coords } ){

        my %coords = %{ $search_criteria->{ coords } };
        my ($srid, $x1, $y1, $x2, $y2) = @coords{qw( srid x1 y1 x2 y2 )};

        # check that we have values for all the parameters
        my @empty_coords = grep { !defined $_ || $_ eq "" } ($srid, $x1, $y1, $x2, $y2);

        if( !@empty_coords ){
            my $dataset_location_cond = $self->dataset_location_search( $srid, $x1, $y1, $x2, $y2 );
            push @ds_ids_conds, $dataset_location_cond;
        }

    }

    if( exists $search_criteria->{ topics } ){

        my $hk_ids = $search_criteria->{ topics }->{ hk_ids };
        my $bk_ids = $search_criteria->{ topics }->{ bk_ids };

        # To simplify the search query a little we fetch the related bk_ids as a separate
        # query. If this proves inefficient attempt another way.
        if( @$hk_ids ){
            get_logger()->debug( dump $hk_ids );
            my $hrb_rs = $self->result_source()->schema()->resultset('HkRepresentsBk');
            my @related_bkids = $hrb_rs->search( { hk_id => { IN => $hk_ids } }, { distinct => 1 } )->get_column('bk_id')->all();
            push @$bk_ids, @related_bkids;
        }

        my $bk_describes_ds_rs = $self->result_source->schema->resultset('BkDescribesDs');
        my $basickey_search = $bk_describes_ds_rs->search( { bk_id => { IN => $bk_ids } } );
        my %cond = ( IN => $basickey_search->get_column('ds_id')->as_query() );

        push @ds_ids_conds, \%cond;
    }

    $search_cond{'me.ds_parent'}   = 0 if !$all_levels;
    $search_cond{'me.ds_ownertag'} = { IN => $ownertags };
    $search_cond{'me.ds_id'}    = [ -and => @ds_ids_conds ] if @ds_ids_conds;

    my $search_attrs =         {
            join     => [ { 'ds_has_mds' => 'md_id' } ],
            distinct => 1,
            order_by => 'me.ds_id',
    };

    if( $curr_page && $rows_per_page ) {
        $search_attrs->{ page } = $curr_page;
        $search_attrs->{ rows } = $rows_per_page;
    }

    my $matching_datasets = $self->search( \%search_cond, $search_attrs );

    return $matching_datasets;

}

sub metadata_search_with_children {
    my $self = shift;

    my $matching_datasets = $self->metadata_search( @_ );
    my $matching_with_children = $matching_datasets->search( {}, { prefetch => 'child_datasets' } );
    return $matching_with_children;
}

sub two_way_table {
    my $self = shift;

    my ( $search_criteria, $ownertags, $vertical_col, $horisontal_col ) = @_;

    my $matching_datasets = $self->metadata_search( { search_criteria => $search_criteria, ownertags => $ownertags, all_levels => 1 } );

    # we could probably do this by chaining the queries or by using a subquery,
    # but for easier debugging with fetch the ids first and then create the two
    # way table.
    my @ds_ids = $matching_datasets->get_column('ds_id')->all();

    my $h_search = $self->search(
        { 'md_id.mt_name' => $horisontal_col, 'me.ds_id' => { IN => \@ds_ids } },
        {
            join      => { 'ds_has_mds' => 'md_id' },
            columns   => [qw( me.ds_id )],
            '+select' => ['md_id.md_content'],
            '+as'     => ['md_content'],

        },
    );
    my $v_search = $self->search(
        { 'md_id.mt_name' => $vertical_col, 'me.ds_id' => { IN => \@ds_ids } },
        {
            join      => { 'ds_has_mds' => 'md_id' },
            columns   => [qw( me.ds_id )],
            '+select' => ['md_id.md_content'],
            '+as'     => ['md_content'],
        },
    );

    my %h_keys_for = ();
    while ( my $h_row = $h_search->next() ) {
        my $ds_id = $h_row->ds_id();
        my $h_key = $h_row->get_column('md_content');
        $h_keys_for{$ds_id} = {} if !exists $h_keys_for{$ds_id};
        $h_keys_for{$ds_id}->{$h_key} = 1;
    }

    my %two_way_table = ();
    while ( my $v_row = $v_search->next() ) {

        my $ds_id = $v_row->ds_id();
        my $v_key = $v_row->get_column('md_content');

        $two_way_table{$v_key} = {} if !exists $two_way_table{$v_key};

        my $h_keys = $h_keys_for{$ds_id};
        foreach my $h_key ( keys %$h_keys ) {
            $two_way_table{$v_key}->{$h_key}++;
        }
    }

    return \%two_way_table;

}

sub active_by_name {
    my $self = shift;

    my ($ds_name) = @_;

    my @ownertags = $self->_get_ownertags;

    return $self->search(
        {
            ds_ownertag => { IN => [@ownertags] },
            ds_status   => 1,
        }
    )->find( { ds_name => $ds_name } );

}

sub level1_datasets {
    my $self = shift;

    my @ownertags = $self->_get_ownertags;

    return $self->search(
        {
            ds_ownertag => { IN => [@ownertags] },
            ds_status   => 1,
            ds_parent   => 0,
        }
    );

}

sub level2_datasets {
    my $self = shift @_;

    my %parameters =
        Params::Validate::validate( @_,
        { ds_id => 1, max_files => { default => 100, }, max_age => { default => 90 } } );

    my $config         = Metamod::Config->new();
    my $dbh            = $config->getDBH();
    my $days           = $parameters{max_age} + 0;                                       # get into numeric presentation
    my ($cut_off_date) = $dbh->selectrow_array("SELECT now() - interval '$days days'");

    my @datasets = $self->search(
        {
            ds_parent    => $parameters{ds_id},
            ds_status    => 1,
            ds_datestamp => { '>' => $cut_off_date },
        },
        { order_by => { -desc => ['DS_datestamp'] }, }
    )->all();

    if ( @$datasets < $parameters{max_files} ) {
        my $limit          = $parameters{max_files} - @$datasets;
        my @extra_datasets = $self->search(
            {
                ds_parent    => $parameters{ds_id},
                ds_status    => 1,
                ds_datestamp => { '<=' => $cut_off_date },
            },
            { order_by => { -desc => ['DS_datestamp'] }, limit => $limit }
        )->all();

        push @datasets, @extra_datasets;

    }

    return @datasets;
}

sub _get_ownertags {
    my $self = shift;

    my @ownertags;
    my $config    = Metamod::Config->new();
    my $ownertags = $config->get('DATASET_TAGS');
    if ( defined $ownertags ) {

        # comma-separated string
        @ownertags = split /\s*,\s*/, $ownertags;

        # remove '' around tags
        @ownertags = map { s/^'//; s/'$//; $_ } @ownertags;
    }
    return @ownertags;
}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
