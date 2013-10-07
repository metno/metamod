package MetamodWeb::Utils::UI::Search;

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
use Data::Dumper;
use Metamod::WMS;

use Memoize;

# We cache some functions that just return data from the database. The data in the database is
# static so this should not cause problems. Keep in mind that the memoized functions cannot use any input that
# is context/object specific. Then can just read data from the database since we memoize once not once for each object.
# The NORMALIZER parameter is required to disregard the $self parameter when checking if the parameters are the same
memoize('_related_basickeys', NORMALIZER => sub { return '_related_basickeys_cache' } );
memoize('_hierarchy', NORMALIZER => sub { return '_hierarchy_cache' } );
memoize('_basickey_rows', NORMALIZER => sub { my ($self, $category_id ) = @_; return '_basickey_rows_cache_' . $category_id } );

use warnings;

extends 'MetamodWeb::Utils::UI::Base';

#
# The search conditions used for the current metadata search
#
has 'current_search_conds' => (is => 'rw', isa => 'HashRef', lazy => 1, builder => '_build_current_search_conds' );

#
# The search attrs used for the current metadata search
#
has 'current_search_attrs' => (is => 'rw', isa => 'HashRef', lazy => 1, builder => '_build_current_search_attrs' );

#
# Initialise the current_search_conds attribute
#
sub _build_current_search_conds {
    my $self = shift;

    my ($conds, $attrs) = $self->_current_search_params();
    return $conds;
}

#
# Initialise the current_search_attrs attribute
#
sub _build_current_search_attrs {
    my $self = shift;

    my ($conds, $attrs) = $self->_current_search_params();
    return $attrs;
}

#
# Helper function for _build_current_search_conds and _build_current_search_attrs
#
sub _current_search_params {
    my $self = shift;

    my $search_utils = MetamodWeb::Utils::SearchUtils->new( { c => $self->c, config => $self->config } );
    my $search_criteria = $search_utils->selected_criteria( $self->c->req->params() );
    my $ownertags = $search_utils->get_ownertags();
    my $dataset_rs = $self->meta_db->resultset('Dataset');
    my ($conds, $attrs ) = $dataset_rs->metadata_search_params( { ownertags => $ownertags,
                                                                  search_criteria => $search_criteria } );
    return ($conds,$attrs);
}

=head1 NAME

MetamodWeb::Utils::UI::Search- Utility functions for building the search ui.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 FUNCTIONS/METHODS

=cut

=head2 $self->search_categories()

Get a list of all the search categories for this instance.

=over

=item return

Returns a reference to a list of hash references. Each hash reference has the
following keys: sc_id, sc_idname, sc_type. In addtion it the parsed values from
sc_fnc are included as key/value pairs.

=back

=cut

sub search_categories {
    my $self = shift;

    my @cat_sequence = split ',', $self->config->get('SEARCH_CATEGORY_SEQUENCE');
    my $categories = $self->meta_db->resultset('Searchcategory')->search( { sc_idname => { -IN => \@cat_sequence } } );
    my %categories = ();
    while ( my $category = $categories->next() ) {
        my %columns = $category->get_columns();
        my $fnc     = $category->sc_fnc_parsed();
        if ( defined $fnc ) {
            %columns = ( %columns, %$fnc );
        }

        $categories{ $columns{ sc_idname } } = \%columns;
    }

    # we must jump through some hoops to get the results properly sorted since the database will
    # place them in any order.
    my @categories = ();
    foreach my $cat_name (@cat_sequence){

        if( !exists $categories{$cat_name} ){
            $self->c->log->warn("'$cat_name' was not found in the database. Check configuration");
            next;
        }
        push @categories, $categories{$cat_name};
    }

    return \@categories;

}

=head2 $self->selected_bks($category_id)

Get the selected basic keys for a category.

=over

=item $category_id

The C<sc_id> of the category.

=item return

Returns a hash reference with all the selected basic keys for the category. The key is the basic key id and
the value is the name of the basic key.

=back

=cut
sub selected_bks {
    my $self = shift;

    my ($category_id) = @_;

    my $basickey_rows    = $self->_basickey_rows($category_id);
    my %selected_bks = ();
    foreach my $basickey (@$basickey_rows){

        my $html_id = 'bk_id_' . $category_id . '_' . $basickey->bk_id();
        if ( $self->c->req->param($html_id) ) {
            $selected_bks{ $basickey->bk_id() } = $basickey->bk_name();
        }
    }

    return \%selected_bks;
}

sub _basickey_rows {
    my $self = shift;

    my ($category_id) = @_;

    my $category = $self->meta_db->resultset('Searchcategory')->find($category_id);
    my @basickey_rows    = $category->basickeys( undef, { order_by => 'bk_name ' } )->all();
    return \@basickey_rows;

}

=head2 $self->basickeys($category_id)

Get all the basic keys for a category.

=over

=item $category_id

The C<sc_id> for the category.

=item return

Returns the basic keys as reference to a list. Each element in the list is hash
reference with the colum values for the basic key.

=back

=cut

sub basickeys {
    my $self = shift;

    my ($category_id) = @_;

    my $basickey_rows = $self->_basickey_rows($category_id);
    my @basickeys = ();
    foreach my $basickey (@$basickey_rows){

        my %columns = $basickey->get_columns();
        push @basickeys, \%columns;
    }
    return \@basickeys;

}

=head2 $self->two_way_table_h_keys($two_way_table)

=over

=item $two_way_table

A two way table structure as returned by
C<Metamod::DBIxSchema::Metabase::ResultSet::Dataset::two_way_table>.

=item return

Returns all the horisontal keys in the two way table sorted alphabetically.

=back

=cut

sub two_way_table_h_keys {
    my $self = shift;

    my ($two_way_table) = @_;

    my %horisontal_keys = ();
    while ( my ( $v_key, $h_keys ) = each %$two_way_table ) {
        while ( my ( $h_key, $num ) = each %$h_keys ) {
            $horisontal_keys{$h_key} = 1;
        }
    }

    # We do a locale insensivtive sort so we need to compare the lower case of the keys to ensure that
    # upper and lower case letters are treated the same
    my @horisontal_keys = sort { lc($a) cmp lc($b) } keys %horisontal_keys;
    return \@horisontal_keys;
}

=head2 $self->num_search_cols()

=over

=item return

Returns SEARCH_APP_MAX_COLUMNS from master_config.txt

=back

=cut

sub num_search_cols {
    my $self = shift;

    return $self->config->get('SEARCH_APP_MAX_COLUMNS');

}

=head2 $self->search_options()

Get the search options for which metadata to use in the search result.

=over

=item return

A reference to a list of hash references.

=back

=cut

sub search_options {
    my $self = shift;

    my $query_params   = $self->c->req->params();

    my $show_columns = $self->search_app_show_columns();
    foreach my $column_info (@$show_columns){

        # if the column number is selected in the CGI parameter we remove the information here.
        # it will be added again later if it this metadata type is selected for the column name
        if( exists $column_info->{col} ){
            my $col_num = $column_info->{col};
            if( $query_params->{ 'shown_mt_name_' . $col_num } ){
                delete $column_info->{col};
            }
        }

        # if metadata used for the 2-way-table is selected in the CGI
        # parameters remove the default selection. This is added again later if
        # the selected is the same as the default.
        if( exists $column_info->{cross} ){
            my $cgi_name = $column_info->{cross} eq 'v' ? 'vertical_mt_name' : 'horisontal_mt_name';
            if( $query_params->{$cgi_name} && $column_info->{cross} ne 'no' ){
                delete $column_info->{cross};
            }
        }

        # check the query parameters to see if the mt_name is selected for some of the columns
        # or for the vertical or horisontal axis
        my $num_search_cols = $self->num_search_cols();
        foreach my $col_num ( 1 .. $num_search_cols ) {
            my $param_name = 'shown_mt_name_' . $col_num;
            if ( exists $query_params->{$param_name} && $query_params->{$param_name} eq $column_info->{mt_name} ) {
                $column_info->{col} = $col_num;
            }
        }

        if ( exists $query_params->{'vertical_mt_name'} && $query_params->{'vertical_mt_name'} eq $column_info->{mt_name} ) {
            $column_info->{cross} = 'v';
        }

        if ( exists $query_params->{'horisontal_mt_name'} && $query_params->{'horisontal_mt_name'} eq $column_info->{mt_name} ) {
            $column_info->{cross} = 'h';
        }
    }

    return $show_columns;

}

=head2 $self->default_mt_name($col_num)

=over

=item $col_num

The column number to get the default mt_name for.

=item return

The mt_name of the default column for the specific C<$col_num>.

=back

=cut

sub default_mt_name {
    my $self = shift;

    my ($col_num) = @_;

    my $show_columns = $self->search_app_show_columns();
    foreach my $column_info (@$show_columns){
        if( defined $column_info->{ col } and $column_info->{ col } eq $col_num ){
            return $column_info->{ mt_name };
        }
    }

    die "No default mt_name for '$col_num'. Error in config.";
}

=head2 $self->default_vertical_mt_name()

=over

=item return

The default mt_name for the vertical column in a two way table.

=back

=cut

sub default_vertical_mt_name {
    my $self = shift;

    my $show_columns = $self->search_app_show_columns();
    foreach my $column_info (@$show_columns){
        if( $column_info->{ cross } eq 'v' ){
            return $column_info->{ mt_name };
        }
    }

    die "No default vertical column. Error in config.";

}

=head2 $self->default_horisontal_mt_name()

=over

=item return

The default mt_name for the horisontal column in a two way table.

=back

=cut

sub default_horisontal_mt_name {
    my $self = shift;

    my $show_columns = $self->search_app_show_columns();
    foreach my $column_info (@$show_columns){
        if( $column_info->{ cross } eq 'h' ){
            return $column_info->{ mt_name };
        }
    }

    die "No default horisontal column. Error in config.";

}

=head2 $self->search_app_show_columns()

This function parses the C<SEARCH_APP_SHOW_COLMNS> configuration variable from
the master config and returns the result as a list of hash references.

=over

=item return

Returns an array reference with hash references. Each hash reference contains
information about one metadata type that can be displayed in the search result.

=back

=cut

sub search_app_show_columns {
    my $self = shift;

    # rewrite to use config->split() FIXME

    my $search_columns = $self->config->get('SEARCH_APP_SHOW_COLUMNS');
    $search_columns =~ s|^\n||; # skip initial blank line
    my @search_columns = split "\n", $search_columns;
    my @show_columns  = ();

    foreach my $column (@search_columns) {

        my ( $mt_name, $shown_name, @extra_params );

        # check if there are any single quotes, if so we use them to split. Otherwise we just split by space
        if ( index( $column, "'" ) ) {
            my $extra_params;
            ( $mt_name, $shown_name, $extra_params ) = map { $self->trim($_) } split "'", $column;
            @extra_params = split " ", $extra_params if $extra_params;
        } else {
            ( $mt_name, $shown_name, @extra_params ) = map { $self->trim($_) } split " ", $column;
        }

        my %column_info = ( mt_name => $mt_name, shown_name => $shown_name );

        # add each extra parameter as its own key/value pair
        foreach my $param (@extra_params) {
            my ( $param_type, $param_value ) = split '=', $param;
            $column_info{$param_type} = $param_value;
        }

        push @show_columns, \%column_info;
    }

    return \@show_columns;
}

=head2 $self->mt_name_to_display_name($mt_name)

=over

=item $mt_name

A <mt_name> column value.

=item return

Returns the display name for a metadata column if it exists in
SEARCH_APP_SHOW_COLUMNS. Otherwise just returns the C<mt_name> again.

=back

=cut

sub mt_name_to_display_name {
    my ($self, $mt_name) = @_;

    my $show_columns = $self->search_app_show_columns();

    die "*** ERROR: Missing mt_name\n" unless $mt_name;

    foreach my $column_info (@$show_columns){
        if($column_info->{mt_name} eq $mt_name ){
            return $column_info->{shown_name};
        }
    }

    $self->c->log->warn("Could not find display name for $mt_name");
    return $mt_name;

}

=head2 $self->selected_map()

=over

=item return

Returns the SRID for the currently selected map. If the user has not selected a
map yet, the first map in the map list will be selected.

=back

=cut

sub selected_map {
    my $self = shift;

    my $selected_map = $self->c->req->params->{selected_map};

    return $selected_map if $selected_map;

    my $srid_columns = $self->config->get('SRID_ID_COLUMNS');
    my @srid_columns = split /\s+/, $srid_columns;

    return $srid_columns[0];

}

=head2 $self->available_maps() [DEPRECATED]

=over

=item return

Returns a reference to a list of available maps. Each map is returned as a hash
reference with the following keys: C<srid>, C<name> and optionally <selected>
for the currently selected map.

=back

=cut

sub available_maps {
    my $self = shift;

    my $srid_columns = $self->config->get('SRID_ID_COLUMNS');
    my $srid_names   = $self->config->get('SRID_ID_NAMES');

    my @srid_columns = split /\s+/, $srid_columns;
    my @srid_names   = split /\s+/, $srid_names;
    my $selected_map = $self->selected_map();

    my @available_maps = ();
    foreach my $srid_column (@srid_columns) {
        my $srid_name = shift @srid_names;
        next if getMapURL("EPSG:$srid_column"); # dynamic WMS map available - ignoring
        my $map = { srid => $srid_column, name => $srid_name };
        $map->{selected} = 1 if ( $srid_column == $selected_map );
        push @available_maps, $map;
    }

    return \@available_maps;

}

=head2 map_coordinates()

=over

=item return

Returns a hash reference with the currently selected map coordinates. The map
coordinates are given as two points. The keys in the hash are: C<x1>, C<y1>,
C<x2> and C<y2>.

=back

=cut

sub map_coordinates {
    my $self = shift;

    my $x1 = $self->c->req->params->{ $self->html_id_for_map('x1') };
    my $x2 = $self->c->req->params->{ $self->html_id_for_map('x2') };
    my $y1 = $self->c->req->params->{ $self->html_id_for_map('y1') };
    my $y2 = $self->c->req->params->{ $self->html_id_for_map('y2') };

    return { x1 => $x1, y1 => $y1, x2 => $x2, y2 => $y2 };

}

=head2 $self->topics_tree()

Generate the hierarchical topics and variables tree.

=over

=item return

Returns a reference to a list of roots. Each root is the start of a tree
structure.

=back

=cut

sub topics_tree {
    my $self = shift;

    my ($roots, $children_for) = $self->_hierarchy();

    my $bks_for_hk = $self->_related_basickeys();

    my $params = $self->c->req->params();
    my @topics_tree = ();
    foreach my $root (@$roots) {
        my $subtree = $self->_gen_topics_tree( $root, $children_for, $bks_for_hk, $params );
        push @topics_tree, $subtree;
    }

    return \@topics_tree;

}

sub _hierarchy {
    my $self = shift;

    my $hk_rs = $self->meta_db->resultset('Hierarchicalkey');

    my $hierarchical_keys = $hk_rs->search( { 'me.sc_id' => 4 },
                                            { select   => [ 'hk_id', 'hk_parent', 'hk_name' ],
                                              order_by => 'hk_name' } );

    # build a list of children for each node in the tree and get roots
    my %children_for = ();
    my @roots        = ();
    my @hk_rows = $hierarchical_keys->cursor()->all();

    foreach my $row (@hk_rows){
        my $hk = {};
        $hk->{hk_id} = $row->[0];
        $hk->{hk_parent} = $row->[1];
        $hk->{hk_name} = $row->[2];

        $children_for{$hk->{hk_id}} = [] if !exists $children_for{$hk->{hk_id}};

        # add the child to the parents list of children
        if ( $hk->{hk_parent} != 0 ) {
            push @{ $children_for{$hk->{hk_parent}} }, $hk;
        } else {
            push @roots, $hk;
        }
    }

    return (\@roots, \%children_for);
}

sub _related_basickeys {
    my $self = shift;

    my $bk_rs = $self->meta_db->resultset('Basickey');

    # here we can use an inner join to get an efficient query since we want every basickey
    # that represent a hierarchical key
    my $related_bks = $bk_rs->search(
        {},
        {
            select     => [ 'me.bk_id', 'bk_name', 'sc_id', 'hk_represents_bks_inner.hk_id' ],
            join       => 'hk_represents_bks_inner',
            '+columns' => 'hk_represents_bks_inner.hk_id'
        }
    );

    # doing normal object creation proved to be to slow for the this volume of
    # basic keys. Instead we get the raw data from the DBI cursor and do some
    # extra processing our selves.
    my %bks_for_hk = ();
    my @rows = $related_bks->cursor()->all();
    foreach my $row (@rows){
        my $bk = {};
        $bk->{bk_id}   = $row->[0];
        $bk->{bk_name} = $row->[1];
        $bk->{sc_id}   = $row->[2];
        $bk->{hk_id}   = $row->[3];

        push @{ $bks_for_hk{ $bk->{hk_id} } }, $bk;

    }

    return \%bks_for_hk;

}

sub _gen_topics_tree {
    my $self = shift;

    my ( $root, $children_for, $bks_for_hk, $params ) = @_;

    my %tree = ();

    $tree{hk_id} = $root->{hk_id};

    # shorten the name as the hierarchy is apparent in the visual structure
    my $node_name = $root->{hk_name};
    if ( $node_name =~ /.*>\s(.*)/ ) {
        $node_name = $1;
    }

    $tree{name}     = $node_name;
    $tree{category} = $root->{'sc_id'};
    $tree{type}     = 'hk';

    # if the topic has been selected
    if ( $params->{ $self->html_id_for_hk_topic( $tree{hk_id} ) } ) {
        $tree{selected} = 1;
    }

    my @children = @{ $children_for->{ $root->{hk_id} } };
    if (@children) {
        my @subtrees = ();
        foreach my $child (@children) {
            my $subtree = $self->_gen_topics_tree( $child, $children_for, $bks_for_hk, $params );
            push @subtrees, $subtree;
        }
        $tree{subtrees} = \@subtrees;
    } else {

        # we are at the bottom level. Let us include the basickeys
        my @subtrees          = ();
        my $hk_represents_bks = $bks_for_hk->{ $root->{hk_id} };
        foreach my $hk_represents_bk (@$hk_represents_bks) {

            my $name = $hk_represents_bk->{bk_name};

            # hidden element should not be shown. Hidden elements are marked by
            # having HIDDEN in their name
            next if ( $name =~ /> HIDDEN/ );

            my %subtree = ();
            $subtree{type}  = 'bk';
            $subtree{name}  = $name;
            $subtree{bk_id} = $hk_represents_bk->{bk_id};

            # if the basickey has already been selected
            if ( $params->{ $self->html_id_for_bk_topic( $subtree{bk_id} ) } ) {
                $subtree{selected} = 1;
            }

            push @subtrees, \%subtree;
        }
        $tree{subtrees} = \@subtrees;
    }

    return \%tree;

}

=head2 $self->selected_topics()

Get a list of all the selected topics.

=over

=item return

Returns a reference to a list of selected topics. Each selected topic is a hash
reference with the following keys: C<type>, C<name> and C<id>

=back

=cut

sub selected_topics {
    my $self = shift;

    my $params = $self->c->req->parameters;

    # get the ids of all the selected hks and bks
    my @selected_hk_ids = ();
    my @selected_bk_ids = ();
    while ( my ( $key, $value ) = each %$params ) {

        if ( $key =~ /^hk_id_(\d+)$/ ) {
            push @selected_hk_ids, $1;
        } elsif ( $key =~ /^bk_id_topic_(\d+)$/ ) {
            push @selected_bk_ids, $1;
        }
    }

    my $hks = $self->meta_db->resultset('Hierarchicalkey')->search( { hk_id => { IN => \@selected_hk_ids } } );
    my $bks = $self->meta_db->resultset('Basickey')->search(        { bk_id => { IN => \@selected_bk_ids } } );

    my @selected_topics = ();
    while ( my $hk = $hks->next() ) {
        my %topic = ();
        $topic{type} = 'hk';
        $topic{name} = $hk->hk_name();
        $topic{id}   = $hk->hk_id();
        push @selected_topics, \%topic;
    }

    while ( my $bk = $bks->next() ) {
        my %topic = ();
        $topic{type} = 'bk';
        $topic{name} = $bk->bk_name();
        $topic{id}   = $bk->bk_id();
        push @selected_topics, \%topic;
    }

    return \@selected_topics;

}

=head2 $self->level2_result( $dataset )

Get the datasets at level 2 that related to the supplied dataset at level 1.
The level 2 datasets will be paged across several pages if there are several
results.

=over

=item $dataset

A DBIx::Class row object for dataset. It is expected that this dataset is at level 1.

=item return

A DBIx::Class resultset for the level 2 datasets. The dataset will be paged.

=back

=cut

sub level2_result {
	my $self = shift;

	my ($dataset) = @_;

	my $current_page = $self->c->req->params->{ 'level2_page_' . $dataset->ds_id() } || 1;

    my $files_per_page = $self->c->req->params->{ files_per_page } || 10;

    my $conds = $self->current_search_conds();
    my %attrs = %{ $self->current_search_attrs() };
    $attrs{ rows } = $files_per_page;
    $attrs{ page } = $current_page;

    # We cache the row objects so that we can fetch the associated metadata only once
    $attrs{ cache } = 1;

	my $level2_datasets = $dataset->child_datasets()->search( $conds, \%attrs );

	return $level2_datasets;

}

=head2 level2_metadata_columns($dataset)

Calculate which metadata columns to display at level 2 in the search result for
a particular dataset.

A metadata column should be displayed at level 2 if the metadata column has data
and it is different from the value at level 1.

=over

=item $dataset

A DBIx::Class row object for the level 1 dataset that the level 2 datasets
belong to.

=item return

A reference to a list of metadata column names.

=back

=cut

sub level2_metadata_columns {
    my $self = shift;

    my ( $dataset, $level2_datasets ) = @_;

    my $metadata_rs = $self->meta_db->resultset('Metadata');
    my $mt_names = $metadata_rs->available_metadata();
    my $level1_md = $dataset->metadata();

    # we convert the metadata content on level 1 to a string for simpler comparison
    my %level1_as_string = ();
    while( my($mt_name, $md_content) = each %$level1_md ){
        $level1_as_string{$mt_name} = join ',', @$md_content;
    }

    my $show_columns = $self->search_app_show_columns();
    my %columns_to_show = map { $_->{mt_name} => 1 } @$show_columns;

    my %non_equal_metadata = ();
    while( my $level2_ds = $level2_datasets->next() ){

        my $md = $level2_ds->metadata();
        while( my ($mt_name, $md_content) = each %$md ){

            # the meta data is not part of the columns that is configured to displayed, so just skip.
            next if !exists $columns_to_show{$mt_name};

            # dataref is added in the end anyway as it is always use to link to
            # the resource if present. To simplify things a bit we do not care
            # if it is actually set or not since the dataset name column that
            # it is related to is displayed anyway.
            next if $mt_name eq 'dataref';

            next if !defined $md_content || @$md_content == 0;

            my $md_as_string = join ',', @$md_content;
            if( !exists $level1_as_string{ $mt_name } || $md_as_string ne $level1_as_string{ $mt_name } ){
                $non_equal_metadata{ $mt_name } = 1
            }
        }
    }
    $level2_datasets->reset();

    my @md_columns = keys %non_equal_metadata;

    # subtract one as the dataref is always included.
    my $max_columns = $self->config->get('SEARCH_APP_MAX_COLUMNS') - 1;
    if( @md_columns > $max_columns ){
        $self->c->log->debug("Number of columns larger than '$max_columns'. Removing the list end" );
        @md_columns = @md_columns[0 .. $max_columns - 1];
    }
    $self->c->log->debug(dump @md_columns);

    push @md_columns, 'dataref';

    return \@md_columns;

}

=head2 $self->looks_like_url($dataref)

Check if a dataref looks like an URL so that we can link to it.

=over

=item $dataref

The dataref string to check.

=item return

Returns true if we can link to it. False otherwise.

=back

=cut

sub looks_like_url {
    my ($self, $dataref) = @_;

    return 1 if $dataref =~ /^http.*/;

    return;
}

=head2 $self->remove_hidden_flag($basickeys)

Removes the textual hidden flag that is present on basic keys names that are
associated with hierarchical keys.

=over

=item $basickeys

An array ref with basic keys.

=item return

An array ref where the '> HIDDEN' flag has been removed from any basic key
where it is present.

=back

=cut

sub remove_hidden_flag {
    my ($self, $bks) = @_;

    my @without_flag = ();
    foreach my $bk (@$bks){
        if( $bk =~ /(.*)>\sHIDDEN$/ ){
            push @without_flag, $1;
        } else {
            push @without_flag, $bk;
        }
    }

    return \@without_flag;
}

=head2 $self->urls_to_links($md_content)

Replace text URLs in the content with HTML links.

=over

=item $md_content

A reference to a list of md_content values.

=item return

A reference to a list of md_content values where the URLs have been replaced
with HTML links.

=back

=cut

sub urls_to_links {
    my ($self, $md_content) = @_;


    # insert spaces brackets around urls
    foreach my $content (@$md_content){

        # insert spaces brackets around urls
        $content =~ s/\(((https?|ftp|irc|mailto):\S+)\)([.,;]?(\s|$))/($1 )$3/g;

        # make long (>20 chars) urls short  and clickable
        $content =~ s/(((https?|ftp|irc|mailto):\S{20})\S+)/<a href="$1" target="_new">$2...<\/a> /g;

        # make short (<=20chars) urls clickable
        $content =~ s/((https?|ftp|irc|mailto):\S{1,20})(\s|$)/<a href="$1" target="_new">$1<\/a> /g;

    }

    return $md_content;

}

=head2 $self->dataset_in_userbase($ds)

Check wether a level 1 dataset is found in the user base or not.

=over

=item $ds

A DBIx::Class row object for the dataset in the metabase.

=item return

Returns 1 if dataset is also found in the user base. False otherwise.

=back

=cut

sub dataset_in_userbase {
    my $self = shift;

    my ($ds) = @_;

    my $userbase_ds = $self->user_db->resultset('Dataset')->search( { ds_name => $ds->unqualified_ds_name() } );
    my $matches = $userbase_ds->count();
    if( $matches == 1 ){
        return 1;
    } elsif( $matches == 0 ){
        return;
    } else {
        my $msg = "The dataset '" . $ds->unqualified_ds_name() . "' was found more than once in the userbase. ";
        $msg .= "This indiciates an error somewhere else.";
        $self->c->log->warn($msg);
        return;
    }

}

=head2 $self->pages_to_show($pager, $max_range)

Calculate the list of page numbers to show in the pager navigation. The pages
to show will be between current page - C<$max_range> and current page +
C<$max_range>. First and last page constraints will be respected.

=over

=item $pager

A C<Data::Page> object.

=item $max_range (default = 10)

=item return

An array reference with the page numbers to show.

=back

=cut

sub pages_to_show {
    my $self = shift;

    my ($pager, $max_range) = @_;

    $max_range = 10 if !defined $max_range;

    my $first_page = $pager->current_page() - $max_range;
    $first_page = 1 if $first_page < 1;

    my $last_page = $pager->current_page() + $max_range;
    $last_page = $pager->last_page() if $last_page > $pager->last_page();

    my @page_list = $first_page .. $last_page;

    $self->c->log->debug( "First page: $first_page Last page: $last_page Page list" . dump @page_list );

    return \@page_list;

}

=head2 $self->navigation_url($url_template, $page)

B<IMPLEMENTATION REMARK:> This funciton is only needed since Template::Toolkit
does not have a C<sprintf> function.

=over

=item $url_template

A printf compatible string with a single %s parameter

=item $page

The page that should be placed in the C<$url_template>

=item return

The C<$url_template> string with the C<$page> inserted at the correct place.

=back

=cut

sub navigation_url {
    my ($self, $url_template, $page ) = @_;

    return sprintf( $url_template, $page );
}

=head2 $self->html_id_for_bk($category_id, $bk_id)

=over

=item $category_id

The C<sc_id> for the category that the basic key belongs to.

=item $bk_id

The C<bk_id> if the basic key.

=item return

Returns the html id that will be used for the basic key form element.

=back

=cut

sub html_id_for_bk {
    my $self = shift;

    my ( $category_id, $bk_id ) = @_;

    return 'bk_id_' . $category_id . '_' . $bk_id;

}

=head2 $self->html_id_for_ni($category_id, $bk_id)

=over

=item $category_id

The C<sc_id> for the category that the number item belongs to.

=item $bk_id

The C<bk_id> if the basic key.

=item return

Returns the html id that will be used for the number item form element.

=back

=cut
sub html_id_for_ni {
    my ( $self, $category_id, $bk_id ) = @_;

    return 'bk_id_' . $category_id . '_' . $bk_id;

}

=head2 $self->html_id_for_freetext($category_id)

=over

=item $category_id

The C<sc_id> for the category that the freetext field belongs to.

=item return

Returns the html id that will be used for freetext the form element.

=back

=cut
sub html_id_for_freetext {
    my ( $self, $category_id ) = @_;

    return 'freetext_' . $category_id;
}

=head2 $self->html_id_for_date($category_id, $date_type)

=over

=item $category_id

The C<sc_id> for the category that the date field belongs to.

=item $date_type

The type of date for the form element. Either C<to> or C<from>.

=item return

Returns the html id that will be used for the form element.

=back

=cut
sub html_id_for_date {
    my ( $self, $category_id, $date_type ) = @_;

    return 'date_' . $date_type . '_' . $category_id;

}

=head2 $self->html_id_for_map($coord_id)

=over

=item $coord_id

The coordinate id for the form element. Either C<x1>, C<x2>, C<y1> or C<y2>.

=item return

Returns the html id that will be used for the form element.

=back

=cut
sub html_id_for_map {
    my ( $self, $coord_id ) = @_;

    return 'map_coord_' . $coord_id;

}

=head2 $self->html_id_for_hk_topic($hk_id)

=over

=item $hk_id

The C<hk_id> for the topic.

=item return

Returns the html id that will be used for the form element.

=back

=cut
sub html_id_for_hk_topic {
    my ( $self, $hk_id ) = @_;

    return 'hk_id_' . $hk_id;

}

=head2 $self->html_id_for_bk_topic($bk_id)

=over

=item $bk_id

The C<bk_id> if the basic key in the topic tree.

=item return

Returns the html id that will be used for the form element in the topic tree.

=back

=cut
sub html_id_for_bk_topic {
    my ( $self, $bk_id ) = @_;

    return 'bk_id_topic_' . $bk_id;
}

=head2 $self->trim($string)

=over

=item $string

The string to trim.

=item return

Returns the string with any whitespaces removed from the start and end of the
string.

=back

=cut

sub trim {
    my ( $self, $string ) = @_;

    return if !defined $string;

    $string =~ s/^\s+//;
    $string =~ s/\s+$//;

    return $string;
}

=head2 $self->wrap_text($string, $len)

Chop a string into fixed lenght lines w/ line breaks each $len chars

=cut

sub wrap_text {
    my ($self, $string, $len) = @_;
    return unless defined $string;
    return $string unless $len;

    my @lines;
    while ( $_ = substr($string, 0, $len, '') ) {
        push @lines, $_;
        print STDERR "--- $_\n"
    }
    return join("\n", @lines);
}

__PACKAGE__->meta->make_immutable;

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
