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

use warnings;

extends 'MetamodWeb::Utils::UI::Base';

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

sub selected_bks {
    my $self = shift;

    my ($category_id) = @_;

    my $category = $self->meta_db->resultset('Searchcategory')->find($category_id);

    my $basickeys    = $category->basickeys();
    my %selected_bks = ();
    while ( my $basickey = $basickeys->next() ) {

        my $html_id = 'bk_id_' . $category_id . '_' . $basickey->bk_id();
        if ( $self->c->req->param($html_id) ) {
            $selected_bks{ $basickey->bk_id() } = $basickey->bk_name();
        }
    }

    return \%selected_bks;
}

sub basickeys {
    my $self = shift;

    my ($category_id) = @_;

    my $category = $self->meta_db->resultset('Searchcategory')->find($category_id);

    my $basickeys = $category->basickeys();
    my @basickeys = ();
    while ( my $basickey = $basickeys->next() ) {

        my %columns = $basickey->get_columns();
        my $html_id = $self->html_id_for_bk( $category_id, $basickey->bk_id() );
        if ( $self->c->req->param($html_id) ) {
            $columns{selected} = 1;
        }
        push @basickeys, \%columns;
    }

    return \@basickeys;

}

sub two_way_table_h_keys {
    my $self = shift;

    my ($two_way_table) = @_;

    my %horisontal_keys = ();
    while ( my ( $v_key, $h_keys ) = each %$two_way_table ) {
        while ( my ( $h_key, $num ) = each %$h_keys ) {
            $horisontal_keys{$h_key} = 1;
        }
    }

    my @horisontal_keys = sort keys %horisontal_keys;
    return \@horisontal_keys;
}

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

sub mt_name_to_display_name {
    my ($self, $mt_name) = @_;

    my $show_columns = $self->search_app_show_columns();

    die "*** ERROR: Missing mt_name\n" unless $mt_name;

    #print STDERR Dumper(@$show_columns);

    foreach my $column_info (@$show_columns){
        #next unless defined $column_info->{mt_name}; # not needed after fixed in search_app_show_columns
        if($column_info->{mt_name} eq $mt_name ){
            return $column_info->{shown_name};
        }
    }

    $self->c->log->warn("Could not find display name for $mt_name");
    return $mt_name;

}

sub selected_map {
    my $self = shift;

    my $selected_map = $self->c->req->params->{selected_map};

    return $selected_map if $selected_map;

    my $srid_columns = $self->config->get('SRID_ID_COLUMNS');
    my @srid_columns = split /\s+/, $srid_columns;

    return $srid_columns[0];

}

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
        my $map = { srid => $srid_column, name => $srid_name };
        $map->{selected} = 1 if ( $srid_column == $selected_map );
        push @available_maps, $map;

    }

    return \@available_maps;

}

sub map_coordinates {
    my $self = shift;

    my $x1 = $self->c->req->params->{ $self->html_id_for_map('x1') };
    my $x2 = $self->c->req->params->{ $self->html_id_for_map('x2') };
    my $y1 = $self->c->req->params->{ $self->html_id_for_map('y1') };
    my $y2 = $self->c->req->params->{ $self->html_id_for_map('y2') };

    return { x1 => $x1, y1 => $y1, x2 => $x2, y2 => $y2 };

}

sub topics_tree {
    my $self = shift;

    my $hk_rs = $self->meta_db->resultset('Hierarchicalkey');


    my $hierarchical_keys = $hk_rs->search( { 'me.sc_id' => 4 }, { select => [ 'hk_id', 'hk_parent', 'hk_name' ] } );


    # build a list of children for each node in the tree and get roots
    my %children_for = ();
    my @roots        = ();
    my $hk_cursor = $hierarchical_keys->cursor();
    while ( my ($hk_id, $hk_parent, $hk_name) = $hk_cursor->next() ) {

        my $hk = {};
        $hk->{hk_id} = $hk_id;
        $hk->{hk_parent} = $hk_parent;
        $hk->{hk_name} = $hk_name;

        $children_for{$hk_id} = [] if !exists $children_for{$hk_id};

        # add the child to the parents list of children
        if ( $hk_parent != 0 ) {
            push @{ $children_for{$hk_parent} }, $hk;
        } else {
            push @roots, $hk;
        }
    }

    my $bks_for_hk = $self->_related_basickeys();

    my @topics_tree = ();
    foreach my $root (@roots) {
        my $subtree = $self->_gen_topics_tree( $root, \%children_for, $bks_for_hk );
        push @topics_tree, $subtree;
    }

    return \@topics_tree;

}

sub _related_basickeys {
    my $self = shift;

    my $bk_rs = $self->meta_db->resultset('Basickey');

    # here we can use an inner join to get an efficient query since we want every basickey
    # that represent a hierarchical key
    my $related_bks = $bk_rs->search(
        {},
        {
            select     => [ 'me.bk_id', 'bk_name', 'sc_id', 'hk_id' ],
            join       => 'hk_represents_bks_inner',
            '+columns' => 'hk_represents_bks_inner.hk_id'
        }
    );

    # doing normal object creation proved to be to slow for the this volume of
    # basic keys. Instead we get the raw data from the DBI cursor and do some
    # extra processing our selves.
    my %bks_for_hk = ();
    my $cursor     = $related_bks->cursor();
    while ( my @row = $cursor->next() ) {

        my $bk = {};
        $bk->{bk_id}   = $row[0];
        $bk->{bk_name} = $row[1];
        $bk->{sc_id}   = $row[2];
        $bk->{hk_id}   = $row[3];

        push @{ $bks_for_hk{ $bk->{hk_id} } }, $bk;

    }

    return \%bks_for_hk;
}

sub _gen_topics_tree {
    my $self = shift;

    my ( $root, $children_for, $bks_for_hk ) = @_;

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
    if ( $self->c->req->params->{ $self->html_id_for_hk_topic( $tree{hk_id} ) } ) {
        $tree{selected} = 1;
    }

    my @children = @{ $children_for->{ $root->{hk_id} } };
    if (@children) {
        my @subtrees = ();
        foreach my $child (@children) {
            my $subtree = $self->_gen_topics_tree( $child, $children_for, $bks_for_hk );
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
            if ( $self->c->req->params->{ $self->html_id_for_bk_topic( $subtree{bk_id} ) } ) {
                $subtree{selected} = 1;
            }

            push @subtrees, \%subtree;
        }
        $tree{subtrees} = \@subtrees;
    }

    return \%tree;

}

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
	my $level2_datasets = $dataset->child_datasets()->search( {}, { rows => $files_per_page, page => $current_page } );

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

    my ( $dataset ) = @_;

    my $level2_datasets = $dataset->child_datasets();
    my $metadata_rs = $self->meta_db->resultset('Metadata');
    my $mt_names = $metadata_rs->available_metadata();
    my $level1_md = $dataset->metadata();

    # we convert the metadata content on level 1 to a string for simpler comparison
    my %level1_as_string = ();
    while( my($mt_name, $md_content) = each %$level1_md ){
        $level1_as_string{$mt_name} = join ',', @$md_content;
    }

    my %non_equal_metadata = ();
    while( my $level2_ds = $level2_datasets->next() ){

        my $md = $level2_ds->metadata();
        while( my ($mt_name, $md_content) = each %$md ){

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

sub html_id_for_bk {
    my $self = shift;

    my ( $category_id, $bk_id ) = @_;

    return 'bk_id_' . $category_id . '_' . $bk_id;

}

sub html_id_for_ni {
    my ( $self, $category_id, $bk_id ) = @_;

    return 'bk_id_' . $category_id . '_' . $bk_id;

}

sub html_id_for_freetext {
    my ( $self, $category_id ) = @_;

    return 'freetext_' . $category_id;
}

sub html_id_for_date {
    my ( $self, $category_id, $date_type ) = @_;

    return 'date_' . $date_type . '_' . $category_id;

}

sub html_id_for_map {
    my ( $self, $coord_id ) = @_;

    return 'map_coord_' . $coord_id;

}

sub html_id_for_hk_topic {
    my ( $self, $hk_id ) = @_;

    return 'hk_id_' . $hk_id;

}

sub html_id_for_bk_topic {
    my ( $self, $bk_id ) = @_;

    return 'bk_id_topic_' . $bk_id;
}

sub trim {
    my ( $self, $string ) = @_;

    return if !defined $string;

    $string =~ s/^\s+//;
    $string =~ s/\s+$//;

    return $string;
}

__PACKAGE__->meta->make_immutable;

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
