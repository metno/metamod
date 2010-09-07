#!/usr/bin/perl -w

use strict;

use FindBin;

use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../..";

use Test::More;

# must override the master config file to use here before use import modules that use the config file.
BEGIN {
    my $config_file = "$FindBin::Bin/../master_config.txt";
    $ENV{METAMOD_MASTER_CONFIG} = $config_file unless exists $ENV{METAMOD_MASTER_CONFIG};
}

use Metamod::Config qw( :init_logger );
use Metamod::Dataset;
use Metamod::Subscription;
use Metamod::TestUtils qw( init_userdb_test empty_userdb );

my $num_tests = 0;

init_userdb_test("$FindBin::Bin/subscription_test_data.sql");

my $ms = Metamod::Subscription->new();

{

    isa_ok( $ms, 'Metamod::Subscription', 'Metamod::Subscription object created ok' );

    BEGIN { $num_tests += 1 }
}

# tests for _parse_subscription_xml
{

    my $xml1 = <<'END_XML';
<subscription type="email" xmlns="http://www.met.no/schema/metamod/subscription">
<param name="address" value="metamod@met.no" />
</subscription>
END_XML

    my $expected1 = {
        type    => 'email',
        address => 'metamod@met.no',
    };

    my $result1 = $ms->_parse_subscription_xml($xml1);
    is_deeply( $result1, $expected1, '_parse_subscription_xml: email subscription' );

    my $xml2 = <<END_XML;
<subscription type="sms" xmlns="http://www.met.no/schema/metamod/subscription">
<param name="server" value="ftp.met.no" />
<param name="user" value="metamod" />
<param name="password" value="secret" />
</subscription>
END_XML

    my $expected2 = {
        type     => 'sms',
        server   => 'ftp.met.no',
        user     => 'metamod',
        password => 'secret',
    };

    my $result2 = $ms->_parse_subscription_xml($xml2);
    is_deeply( $result2, $expected2, '_parse_subscription_xml: sms subscription' );

    my $xml3 = <<END_XML;
<subscription type="sms" xmlns="http://www.met.no/schema/metamod/subscription">
<param name="server" value="ftp.met.no" />
END_XML

    my $expected3 = undef;
    my $result3   = $ms->_parse_subscription_xml($xml3);
    is( $result3, $expected3, '_parse_subscription_xml: Not well formed XML' );

    my $xml4 = <<END_XML;
<subscription type="does not exist" xmlns="http://www.met.no/schema/metamod/subscription">
<param name="server" value="ftp.met.no" />
<param name="user" value="metamod" />
<param name="password" value="secret" />
</subscription>
END_XML

    my $expected4 = undef;
    my $result4   = $ms->_parse_subscription_xml($xml4);
    is( $result4, $expected4, '_parse_subscription_xml: XML does not conform to schema' );

    BEGIN { $num_tests += 4 }

}

# tests for _get_subscriptions
{

    my $data_files_base = "$FindBin::Bin/../data/Metamod";

    my $dataset_file = "$data_files_base/itp07_itp7grd0022";
    my $ds           = Metamod::Dataset->newFromFile($dataset_file);
    my $result       = $ms->_get_subscriptions($ds);
    is_deeply( $result, {}, 'Dataset is not in user database' );

    $dataset_file = "$data_files_base/itp04_itp4grd0013";
    $ds           = Metamod::Dataset->newFromFile($dataset_file);
    $result       = $ms->_get_subscriptions($ds);
    is_deeply( $result, {}, 'Dataset is in user database but for different application.' );

    $dataset_file = "$data_files_base/itp05_itp5grd0236";
    $ds           = Metamod::Dataset->newFromFile($dataset_file);
    $result       = $ms->_get_subscriptions($ds);
    is_deeply( $result, {}, 'Dataset is in user database but has not subscriptions.' );

    $dataset_file = "$data_files_base/hirlam12_sf_1h_2008-07-03_06";
    $ds           = Metamod::Dataset->newFromFile($dataset_file);
    $result       = $ms->_get_subscriptions($ds);
    my $expected = {
        email => [ { address => 'metamod@met.no', U_email => 'metamod@met.no', } ],
        sms   => [
            { server => 'ftp2.met.no', username => 'metamod2', password => 'secret2', U_email => 'metamod@met.no', },
            { server => 'ftp.met.no',  username => 'metamod',  password => 'secret',  U_email => 'metamod@met.no', },
        ],
    };

    is_deeply( $result, $expected, 'Dataset is in user database and has subscriptions.' );
    
    BEGIN { $num_tests += 4 };
}

BEGIN { plan tests => $num_tests }

END {
    empty_userdb();
}
