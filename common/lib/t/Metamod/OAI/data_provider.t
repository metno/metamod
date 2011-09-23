#!/usr/bin/perl -w

use strict;

use FindBin;

use lib "$FindBin::Bin/../../..";
use lib "$FindBin::Bin";

use Test::More;
use Test::Exception;

use Metamod::Dataset;
use Metamod::OAI::DataProvider;
use Metamod::Test::Setup;

my $num_tests = 0;

my $config_file = "$FindBin::Bin/../../master_config.txt";
my $test_setup  = Metamod::Test::Setup->new( master_config_file => $config_file );
my $config      = $test_setup->mm_config();
my $metabase    = $test_setup->metabase();

# Initialise the database with some simple datasets
my @dataset_files = qw(
    data_provider1
    data_provider_deleted
    data_provider_different_tag
    data_provider_excluded_tag
    data_provider_invalid_metadata
);

foreach my $dataset_file (@dataset_files) {
    my $ds = Metamod::Dataset->newFromFile("$FindBin::Bin/../../data/Metamod/OAI/$dataset_file");
    $ds->writeToFile("$FindBin::Bin/../../data/Metamod/OAI/$dataset_file");
}

#
# Test for get_identifiers when sets are not turned on
#
{
    $ENV{METAMOD_PMH_VALIDATION} = 'off';
    $ENV{METAMOD_PMH_SETCONFIG}  = '';
    my $dp = Metamod::OAI::DataProvider->new();

    #
    # Testing without any conditions
    #
    my $identifiers = $dp->get_identifiers( 'dif', '', '', '', '' );
    my $expected_identifiers = [
        { identifier => 'oai:met.no:metamod/OTHER/data_provider1', datestamp => '2009-03-20T11:08:29Z' },
        {
            identifier => 'oai:met.no:metamod/OTHER/data_provider_deleted',
            datestamp  => '2010-01-01T00:00:00Z',
            status     => 'deleted'
        },
        { identifier => 'oai:met.no:metamod/OTHER/data_provider_different_tag', datestamp => '2011-01-01T00:00:00Z' },
        {
            identifier => 'oai:met.no:metamod/OTHER/data_provider_invalid_metadata',
            datestamp  => '2009-01-01T00:00:00Z'
        },
    ];

    is_deeply( $identifiers, $expected_identifiers, "get_identifiers: No conditions. Sets not supported" );

    #
    # Testing from condition
    #
    $identifiers = $dp->get_identifiers( 'dif', '2010-01-01T00:00:00Z', '', '', '' );
    $expected_identifiers = [
        {
            identifier => 'oai:met.no:metamod/OTHER/data_provider_deleted',
            datestamp  => '2010-01-01T00:00:00Z',
            status     => 'deleted'
        },
        { identifier => 'oai:met.no:metamod/OTHER/data_provider_different_tag', datestamp => '2011-01-01T00:00:00Z' },
    ];

    is_deeply( $identifiers, $expected_identifiers, "get_identifiers: From condition. Sets not supported" );

    #
    # Testing until condition
    #
    $identifiers = $dp->get_identifiers( 'dif', '', '2009-12-31T00:00:00Z', '', '' );
    $expected_identifiers = [
        { identifier => 'oai:met.no:metamod/OTHER/data_provider1', datestamp => '2009-03-20T11:08:29Z' },
        {
            identifier => 'oai:met.no:metamod/OTHER/data_provider_invalid_metadata',
            datestamp  => '2009-01-01T00:00:00Z'
        },
    ];

    is_deeply( $identifiers, $expected_identifiers, "get_identifiers: Until condition. Sets not supported" );

    #
    # Testing until and from condition
    #
    $identifiers = $dp->get_identifiers( 'dif', '2009-12-31T00:00:00Z', '2010-12-31T00:00:00Z', '', '' );
    $expected_identifiers = [
        {
            identifier => 'oai:met.no:metamod/OTHER/data_provider_deleted',
            datestamp  => '2010-01-01T00:00:00Z',
            status     => 'deleted'
        },
    ];

    is_deeply( $identifiers, $expected_identifiers, "get_identifiers: Until condition. Sets not supported" );

    #
    # Testing sets condition
    #
    dies_ok { $identifiers = $dp->get_identifiers( 'dif', '', '', 'DAM', '' ) }
    'Cannot use set condition if sets not suppored';

    #
    #
    # Testing of metadata validation
    $ENV{METAMOD_PMH_VALIDATION} = 'on';
    $identifiers = $dp->get_identifiers( 'dif', '', '', '', '' );
    $expected_identifiers = [
        { identifier => 'oai:met.no:metamod/OTHER/data_provider1', datestamp => '2009-03-20T11:08:29Z' },
        {
            identifier => 'oai:met.no:metamod/OTHER/data_provider_deleted',
            datestamp  => '2010-01-01T00:00:00Z',
            status     => 'deleted'
        },
        { identifier => 'oai:met.no:metamod/OTHER/data_provider_different_tag', datestamp => '2011-01-01T00:00:00Z' },
        {
            identifier => 'oai:met.no:metamod/OTHER/data_provider_invalid_metadata',
            datestamp  => '2009-01-01T00:00:00Z',
            status     => 'deleted'
        },
    ];

    is_deeply( $identifiers, $expected_identifiers,
        "get_identifiers: No conditions. Invalid metadata marks dataset as deleted" );
    $ENV{METAMOD_PMH_VALIDATION} = 'off';

    #
    # Test for not matchin records
    #
    $identifiers = $dp->get_identifiers( 'dif', '', '2008-01-01T00:00:00Z', '', '' );
    $expected_identifiers = [];

    is_deeply( $identifiers, $expected_identifiers, "get_identifiers: No matching datasets" );

    #
    # Testing no conditions when sets are not turned on.
    #
    $ENV{METAMOD_PMH_SETCONFIG} = 'DAM|dummy|dummy\nNDAM|dummy|dummy';
    my $dp2 = Metamod::OAI::DataProvider->new();
    $identifiers = $dp2->get_identifiers( 'dif', '', '', '', '' );
    $expected_identifiers = [
        {
            identifier => 'oai:met.no:metamod/OTHER/data_provider1',
            datestamp  => '2009-03-20T11:08:29Z',
            setSpec    => 'DAM'
        },
        {
            identifier => 'oai:met.no:metamod/OTHER/data_provider_deleted',
            datestamp  => '2010-01-01T00:00:00Z',
            status     => 'deleted',
            setSpec    => 'DAM'
        },
        {
            identifier => 'oai:met.no:metamod/OTHER/data_provider_different_tag',
            datestamp  => '2011-01-01T00:00:00Z',
            setSpec    => 'NDAM'
        },
        {
            identifier => 'oai:met.no:metamod/OTHER/data_provider_invalid_metadata',
            datestamp  => '2009-01-01T00:00:00Z',
            setSpec    => 'DAM'
        },
    ];

    is_deeply( $identifiers, $expected_identifiers, "get_identifiers: No conditions. Sets supported" );

    $identifiers = $dp2->get_identifiers( 'dif', '', '', 'NDAM', '' );
    $expected_identifiers = [
        {
            identifier => 'oai:met.no:metamod/OTHER/data_provider_different_tag',
            datestamp  => '2011-01-01T00:00:00Z',
            setSpec    => 'NDAM'
        },
    ];

    is_deeply( $identifiers, $expected_identifiers, "get_identifiers: Set condition. Sets supported" );

    BEGIN { $num_tests += 9 }

}

{
    $ENV{METAMOD_PMH_VALIDATION} = 'off';
    $ENV{METAMOD_PMH_SETCONFIG}  = '';
    my $dp = Metamod::OAI::DataProvider->new();

    #
    # Testing without any conditions
    #
    my $records = $dp->get_records( 'dif', '', '', '', '' );
    my $expected_records = [
        {
            identifier => 'oai:met.no:metamod/OTHER/data_provider1',
            datestamp  => '2009-03-20T11:08:29Z',
            metadata   => ''
        },
        {
            identifier => 'oai:met.no:metamod/OTHER/data_provider_deleted',
            datestamp  => '2010-01-01T00:00:00Z',
            status     => 'deleted',
        },
        {
            identifier => 'oai:met.no:metamod/OTHER/data_provider_different_tag',
            datestamp  => '2011-01-01T00:00:00Z',
            metadata   => '',
        },
        {
            identifier => 'oai:met.no:metamod/OTHER/data_provider_invalid_metadata',
            datestamp  => '2009-01-01T00:00:00Z',
            metadata   => '',
        },
    ];

    compare_records( $records, $expected_records, "get_records: No conditions" );

    #
    # Test with metadata validation turned on
    #
    $ENV{METAMOD_PMH_VALIDATION} = 'on';
    $records = $dp->get_records( 'dif', '', '', '', '' );
    $expected_records = [
        {
            identifier => 'oai:met.no:metamod/OTHER/data_provider1',
            datestamp  => '2009-03-20T11:08:29Z',
            metadata   => ''
        },
        {
            identifier => 'oai:met.no:metamod/OTHER/data_provider_deleted',
            datestamp  => '2010-01-01T00:00:00Z',
            status     => 'deleted',
        },
        {
            identifier => 'oai:met.no:metamod/OTHER/data_provider_different_tag',
            datestamp  => '2011-01-01T00:00:00Z',
            metadata   => '',
        },
        {
            identifier => 'oai:met.no:metamod/OTHER/data_provider_invalid_metadata',
            datestamp  => '2009-01-01T00:00:00Z',
            status   => 'deleted',
        },
    ];

    compare_records( $records, $expected_records, "get_records: With validation" );
    $ENV{METAMOD_PMH_VALIDATION} = 'off';

    #
    # Test for no matching records
    #
    $records = $dp->get_records( 'dif', '', '2008-03-20T11:08:29Z', '', '' );
    $expected_records = [];

    compare_records( $records, $expected_records, "get_records: No records match" );

    BEGIN { $num_tests += 11 }
}

#
# Tests for get_record
#
{

    $ENV{METAMOD_PMH_VALIDATION} = 'on';
    $ENV{METAMOD_PMH_SETCONFIG}  = '';
    my $dp = Metamod::OAI::DataProvider->new();

    #
    # Testing valid identifier and metadata
    #
    my $record = $dp->get_record('dif', 'oai:met.no:metamod/OTHER/data_provider1' );
    my $expected_record = {
            identifier => 'oai:met.no:metamod/OTHER/data_provider1',
            datestamp  => '2009-03-20T11:08:29Z',
            metadata   => ''
        };

    is( exists $record->{metadata}, exists $expected_record->{metadata}, "get_record: Valid identifier and valid metadata, metadata check" );
    delete $record->{metadata};
    delete $expected_record->{metadata};
    is_deeply( $record, $expected_record, "get_record: Valid identifier and valid metadata" );

    #
    # Invalid identifier
    #
    $record = $dp->get_record('dif', 'blabla');
    $expected_record = undef;
    is_deeply( $record, $expected_record, "get_record: Invalid identifier" );

    #
    # Invalid metadata
    #
    $record = $dp->get_record('dif', 'oai:met.no:metamod/OTHER/data_provider_invalid_metadata' );
    $expected_record = {
            identifier => 'oai:met.no:metamod/OTHER/data_provider_invalid_metadata',
            datestamp  => '2009-01-01T00:00:00Z',
            status => 'deleted',
        };

    is( exists $record->{metadata}, exists $expected_record->{metadata}, "get_record: Valid identifier and invalid metadata, metadata check" );
    delete $record->{metadata};
    delete $expected_record->{metadata};
    is_deeply( $record, $expected_record, "get_record: Valid identifier and invalid metadata" );

    $ENV{METAMOD_PMH_SETCONFIG} = 'DAM|dummy|dummy\nNDAM|dummy|dummy';
    my $dp2 = Metamod::OAI::DataProvider->new();

    $record = $dp2->get_record('dif', 'oai:met.no:metamod/OTHER/data_provider1' );
    $expected_record = {
            identifier => 'oai:met.no:metamod/OTHER/data_provider1',
            datestamp  => '2009-03-20T11:08:29Z',
            metadata => '',
            setSpec => 'DAM',
        };
    is( exists $record->{metadata}, exists $expected_record->{metadata}, "get_record: Valid identifier and valid metadata, metadata check. Sets turned on" );
    delete $record->{metadata};
    delete $expected_record->{metadata};
    is_deeply( $record, $expected_record, "get_record: Valid identifier and valid metadata. Sets turned on" );

    BEGIN { $num_tests += 7 }

}

BEGIN { plan tests => $num_tests }


sub compare_records {
    my ($records, $expected_records, $testname) = @_;

    my %expected_has_metadata = ();
    foreach my $record (@$expected_records){
        $expected_has_metadata{$record->{identifier}} = 1 if exists $record->{metadata};
        delete $record->{metadata};
    }

    foreach my $record (@$records) {

        my $id = $record->{identifier};
        is( exists $record->{metadata}, exists $expected_has_metadata{$id}, "$testname: Metadata exits for record '$id'" );
        delete $record->{metadata};
    }

    is_deeply($records, $expected_records, $testname);
}