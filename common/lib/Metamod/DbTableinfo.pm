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

=head2 Usage: my $href = DbTableinfo::getinfo($dbh);

$dbh is the handler of an open database.

The return value, $href, is a reference to a hash with four elements:

$href->{'tables'}

    Contains an array of table names

$href->{'columns'}

    Contains a hash with keys equal to table names. Each hash value is a reference to an array
    containing all column names for the table.

$href->{'primarykeys'}

    Contains a hash with keys equal to table names. Each hash value is a reference to an array
    containing all primary key names for the table.

$href->{'foreignkeys'}

    Contains a hash with keys equal to table names. Each hash value is a reference to an array
    with text strings comprising four space separated elements:

        primarykey foreigntable foreignkey

=cut

sub getinfo {
#
    my $dbh = shift;
    my %infohash = ();
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
    $infohash{'tables'} = \@tablearr;
#
    my %columnhash = ();
    my $column ='%';
    foreach my $tbl (@tablearr) {
        $columnhash{$tbl} = [];
        my $sth = $dbh->column_info($catalog, $schema, $tbl, $column);
        while (1) {
            my $col = $sth->fetchrow_hashref;
            if (! defined($col)) {
                last;
            }
            push @{$columnhash{$tbl}}, $col->{'COLUMN_NAME'};
        }
    }
    $infohash{'columns'} = \%columnhash;
#
    my %primarykeyhash = ();
    foreach my $tbl (@tablearr) {
        $primarykeyhash{$tbl} = [];
        my $sth = $dbh->primary_key_info($catalog, $schema, $tbl);
        if (defined($sth)) {
            while (1) {
                my $col = $sth->fetchrow_hashref;
                if (! defined($col)) {
                    last;
                }
                push @{$primarykeyhash{$tbl}}, $col->{'COLUMN_NAME'};
            }
        }
    }
    $infohash{'primarykeys'} = \%primarykeyhash;
#
    my %foreignkeyhash = ();
    foreach my $tbl (@tablearr) {
        $foreignkeyhash{$tbl} = [];
        my $sth = $dbh->foreign_key_info($catalog, $schema, $tbl, undef, undef, undef);
        if (defined($sth)) {
            while (1) {
                my $fk = $sth->fetchrow_hashref;
                if (! defined($fk)) {
                    last;
                }
                push @{$foreignkeyhash{$tbl}},
                     $fk->{'UK_COLUMN_NAME'} . ' ' .
                     $fk->{'FK_TABLE_NAME'} . ' ' .
                     $fk->{'FK_COLUMN_NAME'};
            }
        }
    }
    $infohash{'foreignkeys'} = \%foreignkeyhash;
#
    return \%infohash;
}
1;
