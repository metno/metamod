#!/usr/bin/perl -w

use strict;

use FindBin;

use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../..";
use lib "$FindBin::Bin";

use Test::More;

my $config_file = "$FindBin::Bin/../master_config.txt";
$ENV{METAMOD_MASTER_CONFIG}   = $config_file;
$ENV{METAMOD_LOG4PERL_CONFIG} = "$FindBin::Bin/../log4perl_config.ini";

# We need to set this for SRU insert to work
BEGIN {
    $ENV{METAMOD_XSLT_DIR} = "$FindBin::Bin/../../../schema/";
}

use DatasetImporterFailer;
use Metamod::DatasetImporter;
use Metamod::DBIxSchema::Metabase;
use Metamod::Subscription;
use Metamod::Test::Setup;

my $num_tests = 0;

my $test_setup = Metamod::Test::Setup->new( master_config_file => $config_file );
$test_setup->mm_config->initLogger();
my $metabase = $test_setup->metabase();

my $importer = Metamod::DatasetImporter->new();


#
# Test that the dataset is imported into the base ok
#
{

    $importer->write_to_database("$FindBin::Bin/../data/Metamod/dataset_importer1.xml");
    test_dataset_row(
        $metabase,
        'OTHER/dataset_importer1',
        {
            ds_id             => 1,
            ds_name           => 'OTHER/dataset_importer1',
            ds_parent         => 0,
            ds_status         => 1,
            ds_ownertag       => 'DAM',
            ds_metadataformat => 'MM2',
            ds_filepath       => "$FindBin::Bin/../data/Metamod/dataset_importer1.xml",
            ds_creationdate   => '2011-01-01 01:01:01',
        },
        "Importing level 1 dataset for the first time"
    );

    test_metadata( $metabase, 1, 'abstract', ['Short test abstract'], 'Metadata for inserted ok: abstract' );

    test_metadata(
        $metabase, 1, 'datacollection_period',
        ['2010-01-01 to 2011-01-01'],
        'Metadata for inserted ok: datacollection_period'
    );

    test_metadata( $metabase, 1, 'area', [ 'Kara Sea', 'Nordic Seas' ], 'Metadata for inserted ok: area' );

    test_metadata(
        $metabase,
        1,
        'variable',
        [
            'Oceans > Ocean Temperature > Water Temperature > HIDDEN',
            'Oceans > Salinity/Density > Salinity > HIDDEN',
            'sea_water_pressure',
        ],
        'Metadata for inserted ok: variable'
    );

    test_basickey( $metabase, 1, [ 451, 805, 988, 1616, 1623 ], 'Connection between dataset and basickey');

    test_numberitem( $metabase, 1, [ { sc_id => 8, ni_from => '20100101', ni_to => '20110101', ds_id => 1 } ], 'Datacollection period in numberitem' );

    my $sru_row = {
        id_product => 1,
        dataset_name => 'OTHER/dataset_importer1',
        ownertag => 'DAM',
        created => '2011-01-01',
        title => "TEST TITLE\tGLOBAL CHANGE MASTER DIRECTORY (GCMD) SCIENTIFIC KEYWORDS, VERSION\n6.0.0.0.0\tMETAMOD DATASET IMPORT CONFORMANCE RULES",
        abstract => 'SHORT TEST ABSTRACT',
        subject => '',
        search_strings => "HYDROSPHERE > SURFACE WATER > WATER PRESSURE\tOCEANS > OCEAN TEMPERATURE > WATER TEMPERATURE\tOCEANS > SALINITY/DENSITY > SALINITY",
        west => '-146.8899',
        east => '78.4615',
        south => '-146.8899',
        north => '78.4615',
        id_contact => 1,
        enddate => undef,
        begindate => undef,
        updated => '2009-03-20',
    };

    test_sru($metabase, 1, $sru_row, "SRU information for active dataset");

    test_dataset_location( $metabase, 1, [{ geom_93995 => 'POINT(-687144.005276686 1053674.74291244)', }], 'Dataset location for level 1 dataset' );

    BEGIN { $num_tests += 10 }
}

#
# Test that re-importing the dataset does not cause duplication
#
{
    my @affected_tables = qw(
        BkDescribesDs
        Dataset
        DatasetLocation
        DsHasMd
        Metadata
        Numberitem
        Projectioninfo
        Wmsinfo );
    my @previous_counts = ();

    foreach my $table (@affected_tables) {
        my $count = $metabase->resultset($table)->count();
        push @previous_counts, $count;
    }

    $importer->write_to_database("$FindBin::Bin/../data/Metamod/dataset_importer1.xml");

    foreach my $table (@affected_tables) {
        my $now_count  = $metabase->resultset($table)->count();
        my $prev_count = shift @previous_counts;

        # temporary use a TODO block since we have a known bug with cleaning of Metadata
        # this can be fixed later when we remove shared metadata
    TODO: {
            local $TODO = 'Metadata not deleted because of shared metadata rows' if $table eq 'Metadata';

            is( $now_count, $prev_count, "Re-import of dataset does not cause duplication: $table" );
        }
    }

    BEGIN { $num_tests += 8 }
}

#
# Inserting of level 2 metadata set
#
{

    $importer->write_to_database("$FindBin::Bin/../data/Metamod/dataset_importer1/dataset_importer1_1.xml");

    test_dataset_row(
        $metabase,
        'OTHER/dataset_importer1/dataset_importer1_1',
        {
            ds_id             => 2,
            ds_name           => 'OTHER/dataset_importer1/dataset_importer1_1',
            ds_parent         => 1,
            ds_status         => 1,
            ds_ownertag       => 'DAM',
            ds_metadataformat => 'MM2',
            ds_filepath       => "$FindBin::Bin/../data/Metamod/dataset_importer1/dataset_importer1_1.xml",
            ds_creationdate   => '2011-01-01 01:01:01',
        },
        "Importing level 2 dataset"
    );

    BEGIN { $num_tests += 2 }

}

#
# Insert of dataset that is deleted
#
{

    $importer->write_to_database("$FindBin::Bin/../data/Metamod/dataset_importer2.xml");

    test_dataset_row(
        $metabase,
        'OTHER/dataset_importer2',
        {
            ds_id             => 3,
            ds_name           => 'OTHER/dataset_importer2',
            ds_parent         => 0,
            ds_status         => 0,
            ds_ownertag       => 'DAM',
            ds_metadataformat => 'MM2',
            ds_filepath       => "$FindBin::Bin/../data/Metamod/dataset_importer2.xml",
            ds_creationdate   => '2011-01-01 01:01:01',
        },
        "Importing inactive dataset"
    );

    test_sru($metabase, 3, undef, "SRU information for deleted dataset");

    BEGIN { $num_tests += 3 }

}

#
# Test for the insert of OAI identifier.
#
{

    local $ENV{METAMOD_PMH_SYNCHRONIZE_ISO_IDENTIFIER} = 1;
    local $ENV{METAMOD_PMH_REPOSITORY_IDENTIFIER} = 'dummy';

    $importer->write_to_database("$FindBin::Bin/../data/Metamod/dataset_importer3.xml");

    my $dbh = $metabase->storage()->dbh();

    my $oai_select = 'SELECT oai_identifier FROM oaiinfo WHERE ds_id = 4';

    my $oai_row = $dbh->selectrow_hashref($oai_select);
    is( $oai_row->{oai_identifier}, 'urn:dummy:OTHER_dataset_importer3', "Synchronised OAI identifier");

    local $ENV{METAMOD_PMH_SYNCHRONIZE_ISO_IDENTIFIER} = 0;

    $importer->write_to_database("$FindBin::Bin/../data/Metamod/dataset_importer3.xml");

    my $oai_row2 = $dbh->selectrow_hashref($oai_select);
    is( $oai_row2->{oai_identifier}, 'oai:dummy:metamod/OTHER/dataset_importer3', "OAI identifier not synchronised");

    local $ENV{METAMOD_PMH_SYNCHRONIZE_ISO_IDENTIFIER} = 1;

    $importer->write_to_database("$FindBin::Bin/../data/Metamod/dataset_importer3.xml");

    my $oai_row3 = $dbh->selectrow_hashref($oai_select);
    is( $oai_row3->{oai_identifier}, 'urn:dummy:OTHER_dataset_importer3', "Synchronised OAI identifier after re-import");

    BEGIN { $num_tests += 3 }

}


#
# Test that a re-import failure does not cause changes in the number of rows.
#
{
    my $fail_importer = DatasetImporterFailer->new();


    my @affected_tables = qw(
        BkDescribesDs
        Dataset
        DatasetLocation
        DsHasMd
        Metadata
        Numberitem
        Projectioninfo
        Wmsinfo );
    my @previous_counts = ();

    foreach my $table (@affected_tables) {
        my $count = $metabase->resultset($table)->count();
        push @previous_counts, $count;
    }

    my $success = $fail_importer->write_to_database("$FindBin::Bin/../data/Metamod/dataset_importer1.xml");
    is($success, undef, "Re-import fails for DatasetImporterFailer" );

    foreach my $table (@affected_tables) {
        my $now_count  = $metabase->resultset($table)->count();
        my $prev_count = shift @previous_counts;

        is( $now_count, $prev_count, "Failed re-import does not affect number of rows in database: $table" );
    }

    BEGIN { $num_tests += 9 }

}

#
# Test that a new import failure does not cause changes in the number of rows.
#
{
    my $fail_importer = DatasetImporterFailer->new();


    my @affected_tables = qw(
        BkDescribesDs
        Dataset
        DatasetLocation
        DsHasMd
        Metadata
        Numberitem
        Projectioninfo
        Wmsinfo );
    my @previous_counts = ();

    foreach my $table (@affected_tables) {
        my $count = $metabase->resultset($table)->count();
        push @previous_counts, $count;
    }

    my $success = $fail_importer->write_to_database("$FindBin::Bin/../data/Metamod/dataset_importer4.xml");
    is($success, undef, "New import fails for DatasetImporterFailer" );


    foreach my $table (@affected_tables) {
        my $now_count  = $metabase->resultset($table)->count();
        my $prev_count = shift @previous_counts;

        is( $now_count, $prev_count, "Failed new import does not affect number of rows in database: $table" );
    }

    BEGIN { $num_tests += 9 }

}

BEGIN { plan tests => $num_tests }

sub test_dataset_row {
    my ( $metabase, $ds_name, $expected_columns, $test_name ) = @_;

    my $ds = $metabase->resultset('Dataset')->find( { ds_name => $ds_name } );
    isnt( $ds, undef, "$test_name. Dataset in database" );

SKIP: {
        skip "Dataset not inserted", 1 if !defined $ds;

        my %columns = $ds->get_columns();

        # we don't test ds_datestamp because the value becomes strange because
        # of TEST_IMPORT_SPEEDUP
        delete $columns{ds_datestamp};

        is_deeply( \%columns, $expected_columns, "$test_name. Columns as expected" );

    }
}

sub test_metadata {
    my ( $metabase, $ds_id, $mt_name, $expected_metadata, $test_name ) = @_;

    my $ds = $metabase->resultset('Dataset')->find($ds_id);

SKIP: {
        skip "Dataset with id '$ds_id' not found in database", 1 if !defined $ds;

        my $metadata = $ds->metadata( [$mt_name] );

        is_deeply( $metadata->{$mt_name}, $expected_metadata, $test_name );

    }

}

sub test_basickey {
    my ( $metabase, $ds_id, $expected_bkids, $test_name ) = @_;

    my $ds = $metabase->resultset('Dataset')->find($ds_id);

SKIP: {
        skip "Dataset with id '$ds_id' not found in database", 1 if !defined $ds;

        my @basickeys = $ds->bk_describes_ds()->all();
        my @bkids = map { $_->get_column('bk_id') } @basickeys;

        is_deeply( \@bkids, $expected_bkids, $test_name );

    }

}

sub test_numberitem {
    my ( $metabase, $ds_id, $expected_numberitems, $test_name ) = @_;

    my $ds = $metabase->resultset('Dataset')->find($ds_id);

SKIP: {
        skip "Dataset with id '$ds_id' not found in database", 1 if !defined $ds;

        my $numberitem_rs = $ds->numberitems();
        my @numberitems = ();
        while ( my $ni = $numberitem_rs->next() ){
            push @numberitems, { $ni->get_columns() };
        }

        is_deeply( \@numberitems, $expected_numberitems, $test_name );

    }

}

sub test_sru {
    my ($metabase, $ds_id, $expected_sru_row, $test_name ) = @_;

    my $dbh = $metabase->storage()->dbh();

    my $sru_select = 'SELECT * FROM sru.products WHERE id_product = ?';
    my $sru_row = $dbh->selectrow_hashref($sru_select, {}, $ds_id);

    if( defined $sru_row ){

        # we don't want to test these as it makes more sense to test the
        # generation of correct XML else where.
        delete $sru_row->{metaxml};
        delete $sru_row->{metatext};

        delete $sru_row->{metatext_vector};
    }

    is_deeply($sru_row, $expected_sru_row, $test_name);

}

sub test_dataset_location {
    my ( $metabase, $ds_id, $expected_locations, $test_name ) = @_;

    my $dbh = $metabase->storage()->dbh();

    my $dl_select = 'SELECT ST_AsText(geom_93995) AS geom_93995 FROM dataset_location WHERE ds_id = ?';
    my $dl_rows = $dbh->selectall_arrayref($dl_select, { Slice => {} }, $ds_id);

    is_deeply( $dl_rows, $expected_locations, $test_name );

}
