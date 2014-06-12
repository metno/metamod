package MetamodWeb::Controller::Admin::Dosql;

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

use DBI;
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


sub sql_prepare_meta : Path("/admin/sql_prepare_meta") :Args(0) {
    my ( $self, $c ) = @_;

    $c->stash(action_url => $c->uri_for('/admin/sql_result_meta'));
    $c->stash(database_name => 'Metadatabase');
    my $config = $c->stash->{ mm_config };
    my $dbh = $c->model('Metabase')->storage()->dbh();
    prepare($c, $dbh);
}

sub sql_prepare_user : Path("/admin/sql_prepare_user") :Args(0) {
    my ( $self, $c ) = @_;

    $c->stash(action_url => $c->uri_for('/admin/sql_result_user'));
    $c->stash(database_name => 'User database');
    my $config = $c->stash->{ mm_config };
    my $dbh = $c->model('Userbase')->storage()->dbh();
    prepare($c, $dbh);
}

sub prepare {
    my ($c, $dbh) = @_;
    $c->stash(template => 'admin/sql_prepare.tt');
    my $tables_ref     = DbTableinfo::get_tablenames($dbh);
    my @table_desc = ();
    foreach my $tbl (@$tables_ref) {
       my $col_string = "";
       my $col = DbTableinfo::get_columnnames($dbh,$tbl);
       foreach my $column_name (@$col) {
           $col_string .= " " . $column_name;
       }
       push @table_desc, {name => $tbl, columns => $col_string};
    }
    $c->stash(table_desc => \@table_desc);
}

sub sql_result_meta : Path("/admin/sql_result_meta") :Args(0) {
    my ( $self, $c ) = @_;

    $c->stash(database_name => 'Metadatabase');
    my $dbh = $c->model('Metabase')->storage()->dbh();
    run_sql($c,$dbh);
}

sub sql_result_user : Path("/admin/sql_result_user") :Args(0) {
    my ( $self, $c ) = @_;

    $c->stash(database_name => 'User database');
    my $dbh = $c->model('Userbase')->storage()->dbh();
    run_sql($c,$dbh);
}

sub run_sql {
    my ($c, $dbh) = @_;
    $c->stash(template => 'admin/sql_result.tt');
    my $params = $c->req->parameters;
    my $sql = "";
    if (exists($params->{'sqlsentence'})) {
        $sql = $params->{'sqlsentence'};
    }
    $c->stash(sqlsentence => $sql);
    my $sth;
    eval {
        $sth = $dbh->prepare($sql);
        $sth->execute();
    };
    my $wholetable = [];
    if ($@) {
        push @$wholetable, [$@];
    } else {
        while (1) {
            my @resultarr = $sth->fetchrow_array;
            if (scalar @resultarr == 0) {
                last;
            }
            push @$wholetable, \@resultarr;
        }
    }
    $c->stash(wholetable => $wholetable);
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
