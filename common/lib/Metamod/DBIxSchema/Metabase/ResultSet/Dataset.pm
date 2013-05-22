package Metamod::DBIxSchema::Metabase::ResultSet::Dataset;

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

use base 'Metamod::DBIxSchema::Resultset';

use Data::Dumper;
use Log::Log4perl qw( get_logger ); # does this work?
use Params::Validate qw( :all );
use Time::localtime;

=head2 $self->metadata_search(%PARAMS)

Search for dataset by looking at the associated metadata for the datasets.

=over

=item curr_page (optional, default = 1)

The current page to view in the paged search result.

=item ownertags

An array ref of owner tags to search for.

=item rows_per_page (optional, default = 10)

The number of rows to fetch.

=item search_criteria

See the corresponding parameter in C<metadata_search_params>

=item return

Returns a C<DBIx::Class> result sets for the search.

=back

=cut

sub metadata_search {
    my $self = shift;

    my %params = validate(
        @_,
        {
            curr_page       => { type => SCALAR, optional => 1 },
            ownertags       => { type => ARRAYREF },
            #rows_per_page   => { type => SCALAR, optional => 10 }, # typo?
            rows_per_page   => { type => SCALAR, default => 10 },
            search_criteria => { type => HASHREF },
            all_levels      => { type => SCALAR, default => 0 },
        }
    );

    my ( $all_levels, $curr_page, $ownertags, $rows_per_page, $search_criteria ) =
        @params{qw( all_levels curr_page ownertags rows_per_page search_criteria )};

    my ( $search_conds, $search_attrs )  = $self->metadata_search_params( { ownertags => $ownertags,
                                                                            search_criteria => $search_criteria } );

    $search_conds->{'me.ds_parent'}   = 0 if !$all_levels;

    if( $curr_page && $rows_per_page ) {
        $search_attrs->{ page } = $curr_page;
        $search_attrs->{ rows } = $rows_per_page;
    }

    my $matching_datasets = $self->search( $search_conds, $search_attrs );

    return $matching_datasets;

}

=head2 $self->metadata_search_params(%PARAMS)

Create DBIx::Class compatible search parameters from a set of search critieria.

=over

=item ownertags

An array ref of owner tags to search for.

=item search_criteria

The search criteria a hash reference. The hash reference is best explained with an example as each type of meta data
requires a slightly different structure.

  $search_criteria = {
      basickey => [
        [ 1000, 1001, 1002 ], # basic keys for one search category
        [ 2000, 2001, ], # basic keys for another search category.
      ],
      dates => { 8 => { from => '20100205', to => '20100801', } },
      freetext => [ 'Some text' ],
      coords => { srid => 93995, x1 => 1, x2 => 10, y1 => 1, y2 => 10 },
      topics => { bk_ids => [ 1, 2, 3 ], hk_ids => [ 10, 20, 30 ] },
  }


=item return

Returns a list of two items. The first item is a hash reference with
C<DBIx::Class> search conditions. The second item contains a C<DBIx::Class>
compatible search attributes that are  neccessary for the search specified in
the condtions to work.

=back

=cut

sub metadata_search_params {
    my $self = shift;

    my %params = validate(
        @_,
        {
            ownertags       => { type => ARRAYREF },
            search_criteria => { type => HASHREF },
        }
    );
    my ( $ownertags, $search_criteria ) = @params{qw( ownertags search_criteria )};

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
                    ni_from => { '<=' => $date->{to}||scalar time },
                    ni_to
                    => { '>=' => $date->{from}||0 },

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


        my @bk_conds = ();
        if( @$hk_ids ){
            my $hrb_rs = $self->result_source()->schema()->resultset('HkRepresentsBk');
            my $bk_search = $hrb_rs->search( { hk_id => { IN => $hk_ids } }, { distinct => 1 } );
            push @bk_conds, { IN => $bk_search->get_column('bk_id')->as_query() }
        }

        if( @$bk_ids ){
            push @bk_conds, { IN => $bk_ids };
        }

        my $bk_describes_ds_rs = $self->result_source->schema->resultset('BkDescribesDs');
        my $basickey_search = $bk_describes_ds_rs->search( { bk_id => [ @bk_conds ] } );

        my %cond = ( IN => $basickey_search->get_column('ds_id')->as_query() );
        push @ds_ids_conds, \%cond;
    }

    $search_cond{'me.ds_ownertag'} = { IN => $ownertags };
    $search_cond{'me.ds_status'} = 1;
    $search_cond{'me.ds_id'}    = [ -and => @ds_ids_conds ] if @ds_ids_conds;

    my %search_attrs = (
            join     => [ { 'ds_has_mds' => 'md_id' } ],
            distinct => 1,
            order_by => 'me.ds_name',
    );

    return ( \%search_cond, \%search_attrs );
}

=head2 $self->two_way_table($search_criteria, $ownertags, $vertical_col, $horisontal_col)

Search the database for matching datasets and create a two way table for the result.

=over

=item $search_criteria

The search criteria used for selecting datasets. See C<metadata_search()> for more details.

=item $ownertags

The owner tags that the datasets should match.

=item $vertical_col

The C<mt_name> for the vertical column.

=item $horisontal_col

The C<mt_name> for the horisontal column.

=item return

Returns a hash reference where the values for the vertical column is used as
the keys and the values are hash references where the values for the horisontal
column is used as key and the value is the number of datasets that match the
value of the horisontal and vertical key. This is simpler to understand with an
example.

  { model_run => { 'Baltic Sea' => 4, 'Barents Sea' => 0, 'Artic Ocean' => 3 },
    observation => { 'Baltic Sea' => 1, 'Barents Sea' => 32, 'Artic Ocean' => 5 },
  }

=back

=cut

sub two_way_table {
    my $self = shift;

    my ( $search_criteria, $ownertags, $vertical_col, $horisontal_col ) = @_;

    my $matching_datasets = $self->metadata_search( { search_criteria => $search_criteria,
                                                      ownertags => $ownertags,
                                                      all_levels => 0 } );

    my $h_search = $self->search(
        { 'md_id.mt_name' => $horisontal_col, 'me.ds_id' => { IN => $matching_datasets->get_column('ds_id')->as_query() } },
        {
            join      => { 'ds_has_mds' => 'md_id' },
            columns   => [qw( me.ds_id )],
            '+select' => ['md_id.md_content'],
            '+as'     => ['md_content'],

        },
    );
    my $v_search = $self->search(
        { 'md_id.mt_name' => $vertical_col, 'me.ds_id' => { IN => $matching_datasets->get_column('ds_id')->as_query() } },
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

        my $ds_id = $v_row->ds_id(); my $v_key =
        $v_row->get_column('md_content');

        $two_way_table{$v_key} = {} if !exists $two_way_table{$v_key};

        my $h_keys = $h_keys_for{$ds_id};         foreach my $h_key ( keys
%$h_keys ) {             $two_way_table{$v_key}->{$h_key}++;         }     }

    return \%two_way_table;

}

=head2 $self->level1_datasets($ownertags)

=over

=item $ownertags

A list of owner tags that the datasets should match.

=item return

Return a C<DBIx::Class> resultset for all active level 1 datasets that match the current owner tags.

=back

=cut

sub level1_datasets {
    my $self = shift;

    my ($ownertags) = @_;

    return $self->search(
        {
            ds_ownertag => { IN => $ownertags },
            ds_status   => 1,
            ds_parent   => 0,
        }
    );

}

=head2 $self->level2_datasets(%PARAMS)

Fetch level 2 datasets for a specific level 1 dataset.

=over

=item $ds_id

The C<ds_id> of the level 1 datasets to fetch level 2 datasets for.

=item max_files (optional, default = 100)

The maximum number of level 2 datasets to return.

=item max_age (optional, default = 90)

The maximum age of the level 2 datasets to return if more C<max_files> are
found in the catalogue. If the C<max_files> limit is not reached, older
datasets can be returned.

=item return

The datasets are returned as a list of C<DBIx::Class> row objects.

=back

=cut

sub level2_datasets {
    my $self = shift @_;

    my %parameters = Params::Validate::validate( @_, { ds_id => 1,
                                                       max_files => { default => 100, },
                                                       max_age => { default => 90 } } );

    my $config         = Metamod::Config->instance();
    my $dbh            = $config->getDBH();
    my $days           = $parameters{max_age} + 0; # get into numeric presentation
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

=head2 $self->dataset_location_search($srid, $x1, $y1, $x2, $y2)

Create a condition that can be used for searching dataset locations.

=over

=item $srid

The SRID for the map that is used as the basis for the search.

=item $x1

The first x coordinate for the search.

=item $y1

The first y coordinate for the search.

=item $x2

The second x coordinate for the search.

=item $y2

The second y coordinate for the search.

=item return

A C<DBIx::Class> search condition that can be used for doing a dataset location search.

=back

=cut

sub dataset_location_search {
    my $self = shift;

    my ( $srid, $x1, $y1, $x2, $y2 ) = @_;

    my $config = Metamod::Config->instance();

    #my %fake_srid = (
    #    3995 => 93995,
    #    3031 => 93031,
    #);
    #
    #$srid = $fake_srid{$srid} if exists $fake_srid{$srid};

    # default is no conversion (assuming client can calculate proper coordinates if not defined in master_config)
    my $scale_factor_x = $config->has("SRID_MAP_SCALE_FACTOR_X_$srid") ? $config->has("SRID_MAP_SCALE_FACTOR_X_$srid") : 1;
    my $scale_factor_y = $config->has("SRID_MAP_SCALE_FACTOR_Y_$srid") ? $config->has("SRID_MAP_SCALE_FACTOR_Y_$srid") : 1;
    my $offset_x       = $config->has("SRID_MAP_OFFSET_X_$srid")       ? $config->has("SRID_MAP_OFFSET_X_$srid")       : 0;
    my $offset_y       = $config->has("SRID_MAP_OFFSET_Y_$srid")       ? $config->get("SRID_MAP_OFFSET_Y_$srid")       : 0;

    my $x1m = ($x1 - $offset_x)*$scale_factor_x;
    my $x2m = ($x2 - $offset_x)*$scale_factor_x;
    my $y1m = ($y1 - $offset_y)*$scale_factor_y;
    my $y2m = ($y2 - $offset_y)*$scale_factor_y;

    $x1m = $self->quote_sql_value( $x1m );
    $x2m = $self->quote_sql_value( $x2m );
    $y1m = $self->quote_sql_value( $y1m );
    $y2m = $self->quote_sql_value( $y2m );

    my $selected_box = "ST_MakeBox2D(ST_Point($x1m, $y1m),ST_Point($x2m,$y2m))";
    my $bounding_box = "ST_SetSRID($selected_box,$srid)";
    my $geom_column  = "geom_$srid";

    my $search_cond = {
        IN => \"( SELECT DISTINCT ds_id FROM dataset_location WHERE ST_DWITHIN( $bounding_box, $geom_column, 0.1))",
    };
    #print STDERR "*** coord search is " . Dumper \$search_cond;
    Log::Log4perl::get_logger('metamod::common::'.__PACKAGE__)->debug( 'PostGIS: ' . ${ $$search_cond{'IN'} });
    return $search_cond;

}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
