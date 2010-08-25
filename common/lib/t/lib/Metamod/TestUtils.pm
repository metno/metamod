package Metamod::TestUtils;

use strict;
use warnings;

use FindBin;

use base 'Exporter';

use Metamod::Config;

our @EXPORT_OK = qw( populate_database empty_database init_test );

=head1 NAME

Metamod::TestUtils - Utility functions for testing.

=head1 DESCRIPTION

This module contains some utility functions for performing automatic testing.

=head1 FUNCTIONS

=cut

=head2 init_test( $dump_file )

Initialise a test script by connecting to the database and populating it with
data.

=over

=item return

=back

=cut
sub init_test {
	my ( $dump_file ) = @_;
	
    my $config = Metamod::Config->new();
    $config->initLogger();
    
    my $dbh;
    eval {
      $dbh = $config->getDBH();      
    };
    
    if( $@ ) {
        return 'Cannot connect to the database: ' . $@;    
    }
    
    my $result = populate_database($dump_file, $config);
    return $result;	
	   
}


=head2 populate_database( $dump_file, $config )

Populate the database based on a PostgreSQL dump file.

=item $dump_file

A PostgreSQL dump file that is used to populate the database. This dump file
should B<NOT> contain any structure commands (DDL), only data.

=item $config

A reference to a L<Metamod::Config> object.

=item return

Returns false on success and an error message otherwise.

=cut
sub populate_database {
    my ( $dump_file, $config ) = @_;

    my $user = $config->get('PG_ADMIN_USER');
    my $db_name = $config->get('DATABASE_NAME');
    my $output_file = "$FindBin::Bin/postgresql.out";

    my $command = "psql -U $user --dbname $db_name --file $dump_file -o $output_file";
    my $success = system $command;

    if ($? == -1) {
        return "Failed to execute '$command': $!\n";
    } elsif ($? & 127) {
        return "PostgreSQL command died with a signal\n";
    } else {
        return;
    }
}


=head2 empty_database( $dbh )

Empty the database completely by deleting all the data in tables and resetting
all sequences back to 1.

=over

=item return

Always returns false.

=back

=cut
sub empty_database {
    my $config = Metamod::Config->new();
    my $dbh = $config->getDBH();

    my @tables = qw(
        basickey
        bk_describes_ds
        dataset
        dataset_location
        ds_has_md
        ga_contains_gd
        ga_describes_ds
        geographicalarea
        hierarchicalkey
        hk_represents_bk
        metadata
        metadatatype
        numberitem
        projectioninfo
        searchcategory
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

1;
