#!/usr/bin/perl -w

use strict;

use FindBin;

use lib "$FindBin::Bin/../../..";
use lib "$FindBin::Bin";

use File::Copy;
use File::Path;
use Test::More;
use Test::Exception;
use Data::Dumper;

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
    data_provider_ongoing
);

# TODO: add some testing on data_provider_ongoing to check blank datacollection_period

foreach my $dataset_file (@dataset_files) {
    my $ds = Metamod::Dataset->newFromFile("$FindBin::Bin/../../data/Metamod/OAI/$dataset_file");
    $ds->writeToFile("$FindBin::Bin/../../data/Metamod/OAI/$dataset_file");
}

#
# Test for get_identifiers when sets are not turned on
#
{
    # cannot use ENV here since requires config to be reloaded
    #$ENV{METAMOD_PMH_VALIDATION} = 'off';
    $config->set('PMH_VALIDATION', 'off');
    is( $config->get('PMH_VALIDATION'), 'off', 'PMH_VALIDATION turned off' );
    #$ENV{METAMOD_PMH_SETCONFIG}  = '';
    $config->set('PMH_SETCONFIG', '');
    is( $config->get('PMH_SETCONFIG'), '', 'PMH_SETCONFIG is blank' );

    my $dp = Metamod::OAI::DataProvider->new();

    #
    # Testing without any conditions
    #
    my ($identifiers, $resumption_token) = $dp->get_identifiers( 'dif', '', '', '', '' );
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
        { identifier => 'oai:met.no:metamod/OTHER/data_provider_ongoing', datestamp => '2009-03-20T11:08:29Z' },
    ];

    is_deeply( $identifiers, $expected_identifiers, "get_identifiers: No conditions. Sets not supported" );
    is( $resumption_token, undef, "get_identifiers: No resumption token when not above max limit." );

    #
    # Testing from condition
    #
    ($identifiers, $resumption_token) = $dp->get_identifiers( 'dif', '2010-01-01T00:00:00Z', '', '', '' );
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
    ($identifiers, $resumption_token) = $dp->get_identifiers( 'dif', '', '2009-12-31T00:00:00Z', '', '' );
    $expected_identifiers = [
        { identifier => 'oai:met.no:metamod/OTHER/data_provider1', datestamp => '2009-03-20T11:08:29Z' },
        {
            identifier => 'oai:met.no:metamod/OTHER/data_provider_invalid_metadata',
            datestamp  => '2009-01-01T00:00:00Z'
        },
        { identifier => 'oai:met.no:metamod/OTHER/data_provider_ongoing', datestamp => '2009-03-20T11:08:29Z' },
    ];

    is_deeply( $identifiers, $expected_identifiers, "get_identifiers: Until condition. Sets not supported" );

    #
    # Testing until and from condition
    #
    ($identifiers, $resumption_token) = $dp->get_identifiers( 'dif', '2009-12-31T00:00:00Z', '2010-12-31T00:00:00Z', '', '' );
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
    #$ENV{METAMOD_PMH_VALIDATION} = 'on';
    $config->set('PMH_VALIDATION', 'on');
    is( $config->get('PMH_VALIDATION'), 'on', 'PMH_VALIDATION turned on' );

    ($identifiers, $resumption_token) = $dp->get_identifiers( 'dif', '', '', '', '' );
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
        { identifier => 'oai:met.no:metamod/OTHER/data_provider_ongoing', datestamp => '2009-03-20T11:08:29Z' },
    ];

    is_deeply( $identifiers, $expected_identifiers,
        "get_identifiers: No conditions. Invalid metadata marks dataset as deleted" );

    #$ENV{METAMOD_PMH_VALIDATION} = 'off';
    $config->set('PMH_VALIDATION', 'off');
    is( $config->get('PMH_VALIDATION'), 'off', 'PMH_VALIDATION turned off' );

    #
    # Test for not matchin records
    #
    ($identifiers, $resumption_token) = $dp->get_identifiers( 'dif', '', '2008-01-01T00:00:00Z', '', '' );
    $expected_identifiers = [];

    is_deeply( $identifiers, $expected_identifiers, "get_identifiers: No matching datasets" );

    #
    # Testing no conditions when sets are not turned on.
    #
    #$ENV{METAMOD_PMH_SETCONFIG} = 'DAM|DAM|dummy|dummy\nNDAM|NDAM|dummy|dummy';
    $config->set('PMH_SETCONFIG', 'DAM|DAM|dummy|dummy\nNDAM|NDAM|dummy|dummy');
    is( $config->get('PMH_SETCONFIG'), 'DAM|DAM|dummy|dummy\nNDAM|NDAM|dummy|dummy', 'PMH_SETCONFIG using DAM' );

    my $dp2 = Metamod::OAI::DataProvider->new();

    #### test 14 fixed
    ($identifiers, $resumption_token) = $dp2->get_identifiers( 'dif', '', '', '', '' );
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
            setSpec    => 'NDAM' # this is missing in result, causing test to fail... FIXME # Fixed itself?
        },
        {
            identifier => 'oai:met.no:metamod/OTHER/data_provider_invalid_metadata',
            datestamp  => '2009-01-01T00:00:00Z',
            setSpec    => 'DAM'
        },
        {
            identifier => 'oai:met.no:metamod/OTHER/data_provider_ongoing',
            datestamp  => '2009-03-20T11:08:29Z',
            setSpec    => 'DAM'
        },
    ];

    is_deeply( $identifiers, $expected_identifiers, "get_identifiers: No conditions. Sets supported" );
    #or print STDERR Dumper \$identifiers, \$expected_identifiers;

    #### test 15 fails - returns same set as 14
    ($identifiers, $resumption_token) = $dp2->get_identifiers( 'dif', '', '', 'NDAM', '' );
    $expected_identifiers = [
        {
            identifier => 'oai:met.no:metamod/OTHER/data_provider_different_tag',
            datestamp  => '2011-01-01T00:00:00Z',
            setSpec    => 'NDAM'
        },
    ];

    is_deeply( $identifiers, $expected_identifiers, "get_identifiers: Set condition. Sets supported" );
    #or print STDERR Dumper \$identifiers, \$expected_identifiers;

    BEGIN { $num_tests += 15 } # ok

}

{
    #$ENV{METAMOD_PMH_VALIDATION} = 'off';
    $config->set('PMH_VALIDATION', 'off');
    is( $config->get('PMH_VALIDATION'), 'off', 'PMH_VALIDATION turned off' );
    #$ENV{METAMOD_PMH_SETCONFIG}  = '';
    $config->set('PMH_SETCONFIG', '');
    is( $config->get('PMH_SETCONFIG'), '', 'PMH_SETCONFIG is blank' );
    my $dp = Metamod::OAI::DataProvider->new();

    #
    # Testing without any conditions
    #
    my ($records, $resumption_token) = $dp->get_records( 'dif', '', '', '', '' );
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
        {
            identifier => 'oai:met.no:metamod/OTHER/data_provider_ongoing',
            datestamp  => '2009-03-20T11:08:29Z',
            metadata   => ''
        },
    ];

    compare_records( $records, $expected_records, "get_records: No conditions" );
    is( $resumption_token, undef, 'get_records: No resumption token when not over max limit.');

    #
    # Test with metadata validation turned on
    #
    #$ENV{METAMOD_PMH_VALIDATION} = 'on';
    $config->set('PMH_VALIDATION', 'on');
    is( $config->get('PMH_VALIDATION'), 'on', 'PMH_VALIDATION turned on' );

    ($records, $resumption_token) = $dp->get_records( 'dif', '', '', '', '' );
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
        {
            identifier => 'oai:met.no:metamod/OTHER/data_provider_ongoing',
            datestamp  => '2009-03-20T11:08:29Z',
            metadata   => ''
        },
    ];

    compare_records( $records, $expected_records, "get_records: With validation" );
    #$ENV{METAMOD_PMH_VALIDATION} = 'off';
    $config->set('PMH_VALIDATION', 'off');
    is( $config->get('PMH_VALIDATION'), 'off', 'PMH_VALIDATION turned off' );

    #
    # Test for no matching records
    #
    ($records, $resumption_token) = $dp->get_records( 'dif', '', '2008-03-20T11:08:29Z', '', '' );
    $expected_records = [];

    compare_records( $records, $expected_records, "get_records: No records match" );

    BEGIN { $num_tests += 5 + ( 2*5 + 1 ) + 1 } # 2 calls to compare_records() on 5 elem array + one call to empty array
}

#
# Tests for get_record
#
{

    #$ENV{METAMOD_PMH_VALIDATION} = 'on';
    $config->set('PMH_VALIDATION', 'on');
    is( $config->get('PMH_VALIDATION'), 'on', 'PMH_VALIDATION turned on' );
    #$ENV{METAMOD_PMH_SETCONFIG}  = '';
    $config->set('PMH_SETCONFIG', '');
    is( $config->get('PMH_SETCONFIG'), '', 'PMH_SETCONFIG is blank' );

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

    #$ENV{METAMOD_PMH_SETCONFIG} = 'DAM|DAM|dummy|dummy\nNDAM|NDAM|dummy|dummy';
    $config->set('PMH_SETCONFIG', 'DAM|DAM|dummy|dummy\nNDAM|NDAM|dummy|dummy');
    is( $config->get('PMH_SETCONFIG'), 'DAM|DAM|dummy|dummy\nNDAM|NDAM|dummy|dummy', 'PMH_SETCONFIG using DAM' );

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
    #### fixed
    is_deeply( $record, $expected_record, "get_record: Valid identifier and valid metadata. Sets turned on" ) or
    print STDERR Dumper \$record, \$expected_record;

    BEGIN { $num_tests += 10 } # ok

}

# tests including resumption tokens
{

    #$ENV{METAMOD_PMH_VALIDATION} = 'off';
    $config->set('PMH_VALIDATION', 'off');
    is( $config->get('PMH_VALIDATION'), 'off', 'PMH_VALIDATION turned off' );
    #$ENV{METAMOD_PMH_SETCONFIG}  = '';
    $config->set('PMH_SETCONFIG', '');
    is( $config->get('PMH_SETCONFIG'), '', 'PMH_SETCONFIG is blank' );
    #$ENV{METAMOD_PMH_MAXRECORDS} = '1';
    $config->set('PMH_MAXRECORDS', '1');
    is( $config->get('PMH_MAXRECORDS'), '1', 'PMH_MAXRECORDS is 1' );

    my $dp = Metamod::OAI::DataProvider->new( resumption_token_dir => "$FindBin::Bin/resumption_tokens");

    #
    # Testing without any conditions
    #
    my ($identifiers, $resumption_token) = $dp->get_identifiers( 'dif', '', '', '', '' );
    my $expected_identifiers = [
        { identifier => 'oai:met.no:metamod/OTHER/data_provider1', datestamp => '2009-03-20T11:08:29Z' },
    ];

    # First run
    my $token_id = delete $resumption_token->{token_id};
    delete $resumption_token->{expiration_date};
    my $expected_resumption_token = {
        from => '',
        until => '',
        set => '',
        cursor => 0,
        complete_list_size => 5,
    };

    is_deeply( $identifiers, $expected_identifiers, 'First identifiers with no conditions when resumption token is used.');
    is_deeply( $resumption_token, $expected_resumption_token, 'Resumption token without any conditions. First run');

    # Second run
    ($identifiers, $resumption_token) = $dp->get_identifiers( '', '', '', '', $token_id );
    $expected_identifiers = [
        {
            identifier => 'oai:met.no:metamod/OTHER/data_provider_deleted',
            datestamp  => '2010-01-01T00:00:00Z',
            status     => 'deleted'
        },
    ];

    $token_id = delete $resumption_token->{token_id};
    delete $resumption_token->{expiration_date};
    $expected_resumption_token = {
        from => '',
        until => '',
        set => '',
        cursor => 1,
        complete_list_size => 5,
    };

    is_deeply( $identifiers, $expected_identifiers, 'Second identifiers with no conditions when resumption token is used.');
    is_deeply( $resumption_token, $expected_resumption_token, 'Resumption token without any conditions. Second run');

    # Third run
    ($identifiers, $resumption_token) = $dp->get_identifiers( '', '', '', '', $token_id );
    $expected_identifiers = [
        { identifier => 'oai:met.no:metamod/OTHER/data_provider_different_tag', datestamp => '2011-01-01T00:00:00Z' },
    ];

    my ($identifiers2, $dummy) = $dp->get_identifiers( '', '', '', '', $token_id );

    $token_id = delete $resumption_token->{token_id};
    delete $resumption_token->{expiration_date};
    $expected_resumption_token = {
        from => '',
        until => '',
        set => '',
        cursor => 2,
        complete_list_size => 5,
    };

    is_deeply( $identifiers, $expected_identifiers, 'Third identifiers with no conditions when resumption token is used.');
    is_deeply( $resumption_token, $expected_resumption_token, 'Resumption token without any conditions. Third run');
    is_deeply( $identifiers2, $identifiers, 'Re-query with a resumption token gives the same result each time' );

    #  Fourth run
    ($identifiers, $resumption_token) = $dp->get_identifiers( '', '', '', '', $token_id );
    $expected_identifiers = [
        {
            identifier => 'oai:met.no:metamod/OTHER/data_provider_invalid_metadata',
            datestamp  => '2009-01-01T00:00:00Z'
        },
    ];

    $token_id = delete $resumption_token->{token_id};
    delete $resumption_token->{expiration_date};
    $expected_resumption_token = {
        from => '',
        until => '',
        set => '',
        cursor => 3,
        complete_list_size => 5,
        #token_id => undef,
    };
    is_deeply( $identifiers, $expected_identifiers, 'Fourth identifiers with no conditions when resumption token is used.');
    is_deeply( $resumption_token, $expected_resumption_token, 'Resumption token without any conditions. Fourth run');

    #  Fifth run
    ($identifiers, $resumption_token) = $dp->get_identifiers( '', '', '', '', $token_id );
    $expected_identifiers = [
        {
            identifier => 'oai:met.no:metamod/OTHER/data_provider_ongoing',
            datestamp  => '2009-03-20T11:08:29Z',
        },
    ];

    delete $resumption_token->{expiration_date};
    $expected_resumption_token = {
        from => '',
        until => '',
        set => '',
        cursor => 4,
        complete_list_size => 5,
        token_id => undef,
    };
    is_deeply( $identifiers, $expected_identifiers, 'Fifth identifiers with no conditions when resumption token is used.');
    is_deeply( $resumption_token, $expected_resumption_token, 'Resumption token without any conditions. Fifth run');

    #
    # Testing resumption token with condition from condition
    #
    ($identifiers, $resumption_token) = $dp->get_identifiers( 'dif', '2010-01-01T00:00:00Z', '', '', '' );
    $expected_identifiers = [
        {
            identifier => 'oai:met.no:metamod/OTHER/data_provider_deleted',
            datestamp  => '2010-01-01T00:00:00Z',
            status     => 'deleted'
        },

    ];

    $token_id = delete $resumption_token->{token_id};
    delete $resumption_token->{expiration_date};
    $expected_resumption_token = {
        from => '2010-01-01T00:00:00Z',
        until => '',
        set => '',
        cursor => 0,
        complete_list_size => 2,
    };
    is_deeply( $identifiers, $expected_identifiers, 'First identifiers when condition and resumption token is used');
    is_deeply( $resumption_token, $expected_resumption_token, 'Resumption token with conditions. First run');


    ($identifiers, $resumption_token) = $dp->get_identifiers( '', '', '', '', $token_id );

    $expected_identifiers = [
        { identifier => 'oai:met.no:metamod/OTHER/data_provider_different_tag', datestamp => '2011-01-01T00:00:00Z' },
    ];

    delete $resumption_token->{expiration_date};
    $expected_resumption_token = {
        from => '2010-01-01T00:00:00Z',
        until => '',
        set => '',
        cursor => 1,
        complete_list_size => 2,
        token_id => undef,
    };
    is_deeply( $identifiers, $expected_identifiers, 'Second identifiers when condition and resumption token is used');
    is_deeply( $resumption_token, $expected_resumption_token, 'Resumption token with conditions. Second run');

    #
    # Testing old resumption token.
    #
    copy("$FindBin::Bin/old_resumption_token", "$FindBin::Bin/resumption_tokens/old_resumption_token");

    ($identifiers, $resumption_token) = $dp->get_identifiers( '', '', '', '', 'old_resumption_token' );

    is_deeply($identifiers, undef, 'Old resumption token gives no result');
    is_deeply($resumption_token, undef, 'Old resumption token gives no new resumption token');

    BEGIN { $num_tests += 21 } # ok
}

BEGIN { plan tests => $num_tests }

#
# runs 1 test per existing record + 1 final
#
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

END {
    rmtree("$FindBin::Bin/resumption_tokens");
}
