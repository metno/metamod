package DbTableinfo;

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

require 0.01;
use strict;
$DbTableinfo::VERSION = 0.01;
use DBI;

=head1 DbTableinfo

Get all tablenames, corresponding column names and primary keys, as well as all foreign
keys info from a database.

=head2 my $aref = DbTableinfo::get_tablenames($dbh);

    $dbh is the handler of an open database.

    The return value, $aref, is a reference to an array with names of all the tables in the database:

=head2 my $aref = DbTableinfo::get_columnnames($dbh,$tbl);

    $dbh is the handler of an open database, $tbl is the name of one of the tables.

    The return value, $aref, is a reference to an array with names of all the columns in the table.

=head2 my $aref = DbTableinfo::get_primarykeys($dbh,$tbl);

    $dbh is the handler of an open database, $tbl is the name of one of the tables.

    The return value, $aref, is a reference to an array with names of all the primary keys in the table.

=head2 my $aref = DbTableinfo::get_foreignkeys($dbh,$tbl);

    $dbh is the handler of an open database, $tbl is the name of one of the tables.

    The return value, $aref, is a reference to an array. Each array element is a reference to a hash
    with the following keys and corresponding text values:

    COLUMN         - The column name in $tbl corresponding to the foreign key.
    FOREIGN_TABLE  - The table name where the foreign key resides.
    FOREIGN_COLUMN - The column name of the foreign key in the foreign table.
    
=cut

sub get_tablenames {
#
    my $dbh = shift;
    my $catalog = '';
    my $schema = 'public';
    my $table = '%';
    my $type = "TABLE";
    my @tablearr = ();
    my $sth = $dbh->table_info($catalog, $schema, $table, $type);
    while (1) {
        my $tbl = $sth->fetchrow_hashref;
        if (! defined($tbl)) {
            last;
        }
        push @tablearr, $tbl->{'table_name'};
    }
    return \@tablearr;
}
#
sub get_columnnames {
    my $dbh = shift;
    my $tbl = shift;
    my $catalog = '';
    my $schema = 'public';
    my %columnhash = ();
    my $column ='%';
    my @colnames = ();
    my $sth = $dbh->column_info($catalog, $schema, $tbl, $column);
    while (1) {
        my $col = $sth->fetchrow_hashref;
        if (! defined($col)) {
            last;
        }
        push @colnames, $col->{'COLUMN_NAME'};
    }
    return \@colnames;
}
#
sub get_primarykeys {
    my $dbh = shift;
    my $tbl = shift;
    my $catalog = '';
    my $schema = 'public';
    my @primarykeys = ();
    my $sth = $dbh->primary_key_info($catalog, $schema, $tbl);
    if (defined($sth)) {
        while (1) {
            my $col = $sth->fetchrow_hashref;
            if (! defined($col)) {
                last;
            }
            push @primarykeys, $col->{'COLUMN_NAME'};
        }
    }
    return \@primarykeys;
}
#
sub get_foreignkeys {
    my $dbh = shift;
    my $tbl = shift;
    my $catalog = '';
    my $schema = 'public';
    my @foreignkeys = ();
    my $sth = $dbh->foreign_key_info($catalog, $schema, $tbl, undef, undef, undef);
    if (defined($sth)) {
        while (1) {
            my $fk = $sth->fetchrow_hashref;
            if (! defined($fk)) {
                last;
            }
            push @foreignkeys, {
                 COLUMN => $fk->{'UK_COLUMN_NAME'},
                 FOREIGN_TABLE => $fk->{'FK_TABLE_NAME'},
                 FOREIGN_COLUMN => $fk->{'FK_COLUMN_NAME'}
            };
        }
    }
    $sth = $dbh->foreign_key_info(undef, undef, undef, $catalog, $schema, $tbl);
    if (defined($sth)) {
        while (1) {
            my $fk = $sth->fetchrow_hashref;
            if (! defined($fk)) {
                last;
            }
            push @foreignkeys, {
                 COLUMN => $fk->{'FK_COLUMN_NAME'},
                 FOREIGN_TABLE => $fk->{'UK_TABLE_NAME'},
                 FOREIGN_COLUMN => $fk->{'UK_COLUMN_NAME'}
            };
        }
    }
#
    return \@foreignkeys;
}
1;
