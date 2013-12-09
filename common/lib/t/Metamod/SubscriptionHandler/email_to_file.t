#!/usr/bin/perl -w

use strict;

use FindBin;

use lib "$FindBin::Bin/../../lib";
use lib "$FindBin::Bin/../../..";

use Mail::Mailer;
use Test::More;
use Test::Files;

use Metamod::Config;
use Metamod::Dataset;
use Metamod::SubscriptionHandler::EmailToFile;

no warnings 'once';

my $num_tests = 0;

my $config = Metamod::Config->new("$FindBin::Bin/../../master_config.txt");
$config->initLogger();
my $from_address = $config->get('FROM_ADDRESS');

# We must set this so Mail::Util::mailaddress() gives a consistent address;
$ENV{MAILADDRESS} = $from_address;

# file that will store sent email
my $mail_file = "$FindBin::Bin/mail.out";

$Mail::Mailer::testfile::config{outfile} = $mail_file;
my $handler = Metamod::SubscriptionHandler::EmailToFile->new();

{

    isa_ok( $handler, 'Metamod::SubscriptionHandler::EmailToFile', 'Object created ok' );

    BEGIN { $num_tests += 1 }
}

my $dataset_file = "$FindBin::Bin/../../data/Metamod/SubscriptionHandler/itp04_itp4grd0013";
my $ds = Metamod::Dataset->newFromFile( $dataset_file );

{
    my $subscriptions1 = [ # FIXME must be customizable
        { address => 'geira@met.no' },
        { address => 'geir.aalberg@met.no' },
    ];

    $handler->push_to_subscribers( $ds, $subscriptions1 );

    my $expected_mail = <<"END_MAIL";

===
test 1 TIMESTAMP
from: ${from_address}
to:  geira\@met.no, geir.aalberg\@met.no

Subject: [METAMOD] New dataset available for TEST/itp04
From: ${from_address}
Bcc: geira\@met.no, geir.aalberg\@met.no



A new data file has just become available for the dataset TEST/itp04

You can download it here: http://thredds.met.no/thredds/catalog/data/met.no/itp04/catalog.html?dataset=data/Metamod/SubscriptionHandler/subdir/subdir2/itp04_itp4grd0013.nc

If you wish to cancel your subscription go to the following address:

http://somecomputer.somedomain.com:8080/example/htdocs/subscription
END_MAIL

    file_filter_ok( $mail_file, $expected_mail, \&remove_timestamp, 'Email to multiple recipients' );

    BEGIN { $num_tests += 1 };

}

BEGIN { plan tests => $num_tests };

sub remove_timestamp {
    my ($content) = @_;

    $content =~ s/^(test\s1\s).*$/$1TIMESTAMP/g;

    return $content;

}

END {
    unlink $mail_file or print $!;
}
