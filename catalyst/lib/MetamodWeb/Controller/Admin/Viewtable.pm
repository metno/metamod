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

BEGIN {extends 'Catalyst::Controller'; }

use Metamod::Config;
use Metamod::DbTableinfo;
# use Data::Dump;
 
=head1 NAME
 
<package name> - <description>
 
=head1 DESCRIPTION
 
=head1 METHODS
 
=cut
 
=head2 auto
 
=cut
 
sub auto :Private {
    my ( $self, $c ) = @_;
 
    # Controller specific initialisation for each request.
}
 
=head2 index
 
=cut
 
sub index : Path("/admin/viewtable") :Args(0) {
    my ( $self, $c ) = @_;
 
    $c->stash(template => 'admin/viewtable.tt');
    $c->stash(current_view => 'Raw');
    my $config = $c->stash->{ mm_config };
    my $dbh            = $config->getDBH();
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

sub viewtbl : Path("/admin/viewtable") :Args(1) {
    my ( $self, $c, $tbl ) = @_;
    $c->stash(template => 'admin/viewtbl.tt');
    $c->stash(current_view => 'Raw');
    $c->stash(name => $tbl);
    my $params = $c->req->parameters;
    my $single_dataset = 0;
    if (exists($params->{'refcol'})) {
       $single_dataset = $params->{'refcol'} eq 'ds_id';
    }
    my $config = $c->stash->{ mm_config };
    my $dbh            = $config->getDBH();
    my $col = DbTableinfo::get_columnnames($dbh,$tbl);
    my $sth = compose_sql($dbh,$col,$tbl,$params,$single_dataset,0);
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
    my %colindex;
    my $ix = 0;
    foreach my $col1 (@$col) {
       $colindex{$col1} = $ix;
       $ix++;
    }
    my $wholetable = build_wholetable($c,$col,$tbl,$sth,$dbh,1);
    $c->stash(wholetable => $wholetable);
}

sub viewdataset : Path("/admin/viewtable/dataset") :Args(1) {
    my ( $self, $c, $dsid ) = @_;
    $c->stash(template => 'admin/viewtbl.tt');
    $c->stash(current_view => 'Raw');
    $c->stash(name => 'dataset');
    my $params = $c->req->parameters;
    my $config = $c->stash->{ mm_config };
    my $dbh            = $config->getDBH();
    my $col = DbTableinfo::get_columnnames($dbh,'dataset');
    my $sth = compose_sql($dbh,$col,'dataset',$params,0,$dsid);
    $sth->execute();
    push @$col, 'References';
    $c->stash(columns => $col);
    my $wholetable = build_wholetable($c,$col,'dataset',$sth,$dbh,0);
    $c->stash(wholetable => $wholetable);
}

sub compose_sql {
    my ($dbh,$col,$tbl,$params,$single_dataset,$dsparent) = @_;
    my $sql = 'SELECT ' . join(',',@$col) . ' FROM ' . $tbl;
    my $where_is_used = 0;
    if ($tbl eq 'dataset' and !$single_dataset) {
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

sub build_wholetable {
    my ($c,$col,$tbl,$sth,$dbh,$children_column) = @_;
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
           my $dsparent = $result[$colindex{'ds_parent'}];
           my $childrenlink = "";
           if ($dsparent == 0) {
              $childrenlink = '<a href="' . $c->uri_for('/admin/viewtable/' . $tbl . '/' . $dsid) . '">Children</a>';
           }
           unshift @result, $childrenlink;
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
                 $c->uri_for('/admin/viewtable/' . $foreign_table_name,
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
