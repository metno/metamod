package MetamodWeb::Controller::Admin::Viewtable;

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

BEGIN {extends 'MetamodWeb::BaseController::Base'; }

use Metamod::DbTableinfo;
# use Data::Dump;

=head1 NAME

MetamodWeb::Controller::Admin::Viewtable

=head1 DESCRIPTION

Prepare data structures representing overview and detailed content of the SQL
databases (Metadatabase and User database). These data structures will be used
in the Template Toolkit templates (View).

=head1 METHODS

=cut

=head2 auto

Controller specific initialisation for each request.
Currently empty.

=cut

sub auto :Private {
    my ( $self, $c ) = @_;
}

=head2 index

Build array @table_desc. Each array element is a reference to a hash with the following
entries:

   name      Table name in the SQL Meta database
   columns   Sting with column names for the table (blank separated)
   url       Url used to view the table content

Stash a reference to @table_desc under the name 'table_desc'.

=cut

sub index : Path("/admin/viewtable") :Args(0) {
    my ( $self, $c ) = @_;

    $c->stash(template => 'admin/viewtable.tt');
    $c->stash(current_view => 'Raw');
    my $dbh            = $c->model('Metabase')->storage()->dbh();
    my $tables_ref     = DbTableinfo::get_tablenames($dbh);
    my @table_desc = ();
    foreach my $tbl (@$tables_ref) {
       my $col_string = "";
       my $col = DbTableinfo::get_columnnames($dbh,$tbl);
       foreach my $column_name (@$col) {
           $col_string .= " " . $column_name;
       }
       my $url = $c->uri_for('/admin/viewtable/' . $tbl);
       push @table_desc, {name => $tbl, columns => $col_string, url => $url};
    }
    $c->stash(table_desc => \@table_desc);
}

=head2 viewtbl

Prepare for presenting table rows from a SQL Metadatabase table.

Activated by URLs like:

   http://.../admin/viewtable/<tablename>

where <tablename> is the name of a table in the SQL Metadatabase. This table name
is available as the third argument ($tbl) to this routine. The URL may also contain
parameters like:

   ?refcol=<colname>&refval=<colval>

If this is the case, only table rows with <colname> values equal to <colval> are
fetched from the database and presented to the user.

Build an array (referenced by $wholetable). Each array element represents one table
row in the SQL Metadatabase table given by the $tbl argument. The array element is
a reference to an array with column values from this row.

Stash the $wholetable reference.

=cut

sub viewtbl : Path("/admin/viewtable") :Args(1) {
    my ( $self, $c, $tbl ) = @_;
    $c->stash(template => 'admin/viewtbl.tt');
    $c->stash(current_view => 'Raw');
    $c->stash(name => "Metadata table: $tbl");
    my $params = $c->req->parameters;
    my $no_parent_filter = 0;
    if (exists($params->{'refcol'})) {
       $no_parent_filter = $params->{'refcol'} eq 'ds_id';
    }
    my $config = $c->stash->{ mm_config };
    my $dbh = $c->model('Metabase')->storage()->dbh();
    my $col = DbTableinfo::get_columnnames($dbh,$tbl);
    my $sth = compose_sql($dbh,$col,$tbl,$params,$no_parent_filter,0);
    $sth->execute();
    my @newcol = @$col;
    if ($tbl eq 'dataset') {
        unshift @newcol, 'Children';
    }
    if ($tbl eq 'ds_has_md') {
       push @newcol, 'mt_name';
       push @newcol, 'md_content';
    }
    push @newcol, 'References';
    $col = \@newcol;
    $c->stash(columns => $col);
    my $wholetable = build_wholetable($c,"/admin/viewtable",$col,$tbl,$sth,$dbh,1);
    $c->stash(wholetable => $wholetable);
}

=head2 viewdataset

Prepare for presenting table rows from the 'dataset' SQL Metadatabase table.
Level 2 datasets where the parent dataset has ds_id == $dsid are fetched from the
database.

Activated by URLs like:

   http://.../admin/viewtable/dataset/<ds_id>

where <ds_id> is the unique identifier of the parent dataset table row. This identifier
is available as the third argument ($dsid) to this routine. The URL may also contain
parameters like:

   ?refcol=<colname>&refval=<colval>

If this is the case, only table rows with <colname> values equal to <colval> are
fetched from the database and presented to the user.

Build an array (referenced by $wholetable). Each array element represents one table
row in the SQL Metadatabase table. The array element is a reference to an array with
column values from this row.

Stash the $wholetable reference.

=cut

sub viewdataset : Path("/admin/viewtable/dataset") :Args(1) {
    my ( $self, $c, $dsid ) = @_;
    $c->stash(template => 'admin/viewtbl.tt');
    $c->stash(current_view => 'Raw');
    $c->stash(name => 'Metadata table: dataset');
    my $params = $c->req->parameters;
    my $dbh = $c->model('Metabase')->storage()->dbh();
    my $col = DbTableinfo::get_columnnames($dbh,'dataset');
    my $sth = compose_sql($dbh,$col,'dataset',$params,0,$dsid);
    $sth->execute();
    push @$col, 'References';
    $c->stash(columns => $col);
    my $wholetable = build_wholetable($c,"/admin/viewtable",$col,'dataset',$sth,$dbh,0);
    $c->stash(wholetable => $wholetable);
}

=head2 viewusertable

Build array @table_desc. Each array element is a reference to a hash with the following
entries:

   name      Table name in SQL User database
   columns   Sting with column names for the table (blank separated)
   url       Url used to view the table content

Stash a reference to @table_desc under the name 'table_desc'.

=cut

sub viewusertable : Path("/admin/viewusertable") :Args(0) {
    my ( $self, $c ) = @_;

    $c->stash(template => 'admin/viewtable.tt');
    $c->stash(current_view => 'Raw');
    my $dbh            = $c->model('Userbase')->storage()->dbh();
    my $tables_ref     = DbTableinfo::get_tablenames($dbh);
    my @table_desc = ();
    foreach my $tbl (@$tables_ref) {
       my $col_string = "";
       my $col = DbTableinfo::get_columnnames($dbh,$tbl);
       foreach my $column_name (@$col) {
           $col_string .= " " . $column_name;
       }
       my $url = $c->uri_for('/admin/viewusertable/' . $tbl);
       push @table_desc, {name => $tbl, columns => $col_string, url => $url};
    }
    $c->stash(table_desc => \@table_desc);
}

=head2 viewusertbl

Prepare for presenting table rows from a SQL User database table.

Activated by URLs like:

   http://.../admin/viewusertable/<tablename>

where <tablename> is the name of a table in the SQL User database. This table name
is available as the third argument ($tbl) to this routine. The URL may also contain
parameters like:

   ?refcol=<colname>&refval=<colval>

If this is the case, only table rows with <colname> values equal to <colval> are
fetched from the database and presented to the user.

Build an array (referenced by $wholetable). Each array element represents one table
row in the SQL User database table given by the $tbl argument. The array element is
a reference to an array with column values from this row.

Stash the $wholetable reference.

=cut

sub viewusertbl : Path("/admin/viewusertable") :Args(1) {
    my ( $self, $c, $tbl ) = @_;
    $c->stash(template => 'admin/viewtbl.tt');
    $c->stash(current_view => 'Raw');
    $c->stash(name => "User Database table: $tbl");
    my $params = $c->req->parameters;
    my $dbh = $c->model('Userbase')->storage()->dbh();
    my $col = DbTableinfo::get_columnnames($dbh,$tbl);
    my $sth = compose_sql($dbh,$col,$tbl,$params,1,0);
    $sth->execute();
    my @newcol = @$col;
    push @newcol, 'References';
    $col = \@newcol;
    $c->stash(columns => $col);
    my %colindex;
    my $ix = 0;
    foreach my $col1 (@$col) {
       $colindex{$col1} = $ix;
       $ix++;
    }
    my $wholetable = build_wholetable($c,"/admin/viewusertable",$col,$tbl,$sth,$dbh,0);
    $c->stash(wholetable => $wholetable);
}

=head2 compose_sql

Build and prepare an SQL statement for execution. This routine takes the following
arguments:

   $dbh                Database handle
   $col                Reference to array with column names that represents the columns
                       to be fetched
   $tbl                Name of SQL table. Note: The 'ds_has_md' table is treated specially:
                       Some columns are taken from the metadata table.
   $params             Reference to hash with parameter key - value pairs taken from the
                       activating URL
   $no_parent_filter   Used for the Metadatabase if the table name is 'dataset'. For such
                       tables, this variable may be set to a false value (i.e == 0). Then
                       filtering according to the ds_parent column values are activated.
                       Otherwise, this value will be true (i.e == 1), and no filtering on
                       ds_parent values are done.
   $dsparent           The value that the ds_parent column must match if such parent
                       filtering is activated.

Return the SQL statement handle, ready for execution.

=cut

sub compose_sql {
    my ($dbh,$col,$tbl,$params,$no_parent_filter,$dsparent) = @_;
    my $sql = 'SELECT ' . join(',',@$col) . ' FROM ' . $tbl;
    my $where_is_used = 0;
    if ($tbl eq 'dataset' and !$no_parent_filter) {
       $sql .= ' WHERE ds_parent = ' . $dsparent;
       $where_is_used = 1;
    }
    if ($tbl eq 'ds_has_md') {
       $sql = "SELECT ds_has_md.ds_id, ds_has_md.md_id, mt_name, md_content" .
              " FROM ds_has_md, metadata WHERE ds_has_md.md_id = metadata.md_id";
       $where_is_used = 1;
    }
    if (exists($params->{'refcol'})) {
        my $refcol = $params->{'refcol'};
        my $refval = $params->{'refval'};
        if ($where_is_used) {
            $sql .= ' AND ';
        } else {
            $sql .= ' WHERE ';
        }
        if ($tbl eq 'ds_has_md') {
           $refcol = 'ds_has_md.' . $refcol;
        }
        if ($refval !~ /^-?[0-9.]+$/) {
           $refval = "'" . $refval . "'";
        }
        $sql .= $refcol . ' = ' . $refval;
    }
    my $sth = $dbh->prepare($sql);
    return $sth;
}

=head2 build_wholetable

Create table to be presented to the user.

The table will be set up as an array containing references to arrays with row
values.

Return value: A ref to this table array.

This routine takes the following arguments:

   $c                 Context
   $baseurl           Initial part of URL used to link to other tables
   $col               Ref to array containing column names for the current table
   $tbl               Name of SQL table to access
   $sth               DBI statement handle for an SQL object that has been executed
                      and now used to fetch rows from the SQL result
   $dbh               DBI database handle
   $children_column   True (== 1) if the first column in the table presented to the
                      user should contain links to children dataset

=cut

sub build_wholetable {
    my ($c,$baseurl,$col,$tbl,$sth,$dbh,$children_column) = @_;
    my %colindex;
    my $ix = 0;
    foreach my $col1 (@$col) {
       $colindex{$col1} = $ix;
       $ix++;
    }
    my $foreignref = DbTableinfo::get_foreignkeys($dbh,$tbl);
    my $wholetable = [];
    while (1) {
       my @result = $sth->fetchrow_array;
       if (scalar @result == 0) {
          last;
       }
       if ($tbl eq 'dataset' and $children_column) {
           my $dsid = $result[0];
           my $childrenlink = "";
           unshift @result, $childrenlink;
           my $dsparent = $result[$colindex{'ds_parent'}];
           if ($dsparent == 0) {
              $childrenlink = '<a href="' . $c->uri_for($baseurl . '/' . $tbl . '/' . $dsid) . '">Children</a>';
           }
#           print "dsparent, Childrenlink = " . $dsparent . ", " . $childrenlink . "\n";
           $result[0] = $childrenlink;
       }
       my $references = "";
       foreach my $foreign (@$foreignref) {
           my $column_name = $foreign->{'COLUMN'};
           my $foreign_table_name = $foreign->{'FOREIGN_TABLE'};
           my $foreign_column_name = $foreign->{'FOREIGN_COLUMN'};
#           print "foreign_table_name = $foreign_table_name, foreign_column_name = $foreign_column_name\n";
           my $refval1;
           if (exists($colindex{$column_name})) {
              my $colix = $colindex{$column_name};
              $refval1 = $result[$colix];
           }
           $references .= '<a href="' .
                 $c->uri_for($baseurl . '/' . $foreign_table_name,
                     {refcol => $foreign_column_name,
                      refval => $refval1}
                 ) .
                 '">' . $foreign_table_name . '</a><br />';
       }
       push @result, $references;
       push @$wholetable, \@result;
    }
    return $wholetable;
 }


#
# Remove comment if you want a controller specific begin(). This
# will override the less specific begin()
#
#sub begin {
#    my ( $self, $c ) = @_;
#}

#
# Remove comment if you want a controller specific end(). This
# will override the less specific end()
#
#sub end {
#    my ( $self, $c ) = @_;
#}


__PACKAGE__->meta->make_immutable;

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
