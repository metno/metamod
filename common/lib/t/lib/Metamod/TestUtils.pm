package Metamod::TestUtils;

use strict;
use warnings;

use FindBin;

use base 'Exporter';

use DBI;

use Metamod::Config;

our @EXPORT_OK = qw( populate_database empty_metadb empty_userdb init_metadb_test init_userdb_test );

=head1 NAME

Metamod::TestUtils - Utility functions for testing.

=head1 DESCRIPTION

This module contains some utility functions for performing automatic testing.

=head1 FUNCTIONS

=cut

=head2 init_metadb_test( $dump_file )

Initialise a test script by connecting to the metadata database and populating
it with data.

=over

=item return

Returns undef on error. On error it returns an error message.

=back

=cut

sub init_metadb_test {
    my ($dump_file) = @_;

    my $config = Metamod::Config->new();
    $config->initLogger();

    my $dbh;
    eval { $dbh = $config->getDBH(); };

    if ($@) {
        return 'Cannot connect to the database: ' . $@;
    }

    my $user    = 'admin';
    my $db_name = 'metamod_unittest';
    my $result  = populate_database( $dump_file, $user, $db_name );
    return $result;

}

=head2 init_userdb_test( $dump_file )

Initialise a test script by connecting to the user database and populating
it with data.

=over

=item return

Returns undef on error. On error it returns an error message.

=back

=cut

sub init_userdb_test {
    my ($dump_file) = @_;

    my $config = Metamod::Config->new();
    $config->initLogger();

    my $user    = 'admin';
    my $db_name = 'metamod_unittest_userbase';

    my $result  = populate_database( $dump_file, $user, $db_name );
    return $result;

}

=head2 populate_database( $dump_file, $config )

Populate the database based on a PostgreSQL dump file.

=item $dump_file

A PostgreSQL dump file that is used to populate the database. This dump file
should B<NOT> contain any structure commands (DDL), only data.

=item $user

The name of the user that is connecting to the database.

=item $db_name

The name of the database.

=item return

Returns false on success and an error message otherwise.

=cut

sub populate_database {
    my ( $dump_file, $user, $db_name ) = @_;

    my $output_file = "$FindBin::Bin/postgresql.out";

    my $command = "psql -U $user --dbname $db_name --file $dump_file -o $output_file";
    my $success = system $command;


    if ( $? == -1 ) {
        return "Failed to execute '$command': $!\n";
    } elsif ( $? & 127 ) {
        return "PostgreSQL command died with a signal\n";
    } else {
        return;
    }
}

=head2 empty_metadb( $dbh )

Empty the metadata database completely by deleting all the data in tables and
resetting all sequences back to 1.

=over

=item return

Always returns false.

=back

=cut

sub empty_metadb {
    my $config = Metamod::Config->new();
    my $dbh    = $config->getDBH();

    my @tables = qw(
        bk_describes_ds
        dataset
        dataset_location
        ds_has_md
        ga_contains_gd
        ga_describes_ds
        hk_represents_bk
        metadata
        metadatatype
        numberitem
        projectioninfo
        sessions
        wmsinfo
    );

    my @sequences = qw(
        basickey_bk_id_seq
        dataset_ds_id_seq
        geographicalarea_ga_id_seq
        hierarchicalkey_hk_id_seq
        metadata_md_id_seq
    );

    foreach my $table (@tables) {
        $dbh->do("DELETE FROM $table")
            or print STDERR $dbh->errstr();
    }

    foreach my $sequences (@sequences) {
        $dbh->do("SELECT setval('$sequences', 1, false)") or print STDERR $dbh->errstr();
    }
    $dbh->commit();

    return;
}

=head2 empty_userdb( $dbh )

Empty the metadata database completely by deleting all the data in tables and
resetting all sequences back to 1.

=over

=item return

Always returns false.

=back

=cut

sub empty_userdb {
    my $config = Metamod::Config->new();

    my $dbname  = 'metamod_unittest_userbase';
    my $user    = 'admin';
    my $connect = "dbi:Pg:dbname=" . $dbname . " " . $config->get("PG_CONNECTSTRING_PERL");
    my $dbh     = DBI->connect_cached(
        $connect, $user, "",
        {
            AutoCommit       => 0,
            RaiseError       => 1,
            FetchHashKeyName => 'NAME_lc',
        }
    );

    my @tables = qw(
        file
        infods
        infouds
        dataset
        usertable
    );

    my @sequences = qw(
        dataset_ds_id_seq
        infods_i_id_seq
        infouds_i_id_seq
        usertable_u_id_seq
    );

    foreach my $table (@tables) {
        $dbh->do("DELETE FROM $table")
            or print STDERR $dbh->errstr();
    }

    foreach my $sequence (@sequences) {
        $dbh->do("SELECT setval('$sequence', 1, false)") or print STDERR $dbh->errstr();
    }
    $dbh->commit();

    print "Done\n";
    return;

}

1;
