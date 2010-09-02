#! /usr/bin/perl
use strict;
use warnings;

use FindBin;

use lib "$FindBin::Bin/../../lib";
use lib "$FindBin::Bin/../../..";

use Test::More;
use Test::LongString;

# must override the master config file to use here before use import modules that use the config file.
BEGIN {
     my $config_file = "$FindBin::Bin/../../master_config.txt";
     $ENV{ METAMOD_MASTER_CONFIG } = $config_file unless exists $ENV{METAMOD_MASTER_CONFIG };
}

use Metamod::Config qw( :init_logger );
use Metamod::Search::Feed;
use Metamod::TestUtils qw( populate_database empty_metadb init_metadb_test );

my $error = init_metadb_test( "$FindBin::Bin/feed_test_data.sql" );
if( $error ){
    plan skip_all => $error;
} else {
    plan tests => 8;
}

my $feed = Metamod::Search::Feed->new();

# No dataset give, no URL rewriting
{
    my $expected_header = "Content-Type: text/html; charset=ISO-8859-1\r\n\r\n";

    my $expected_content = <<END_HTML;
<html>
<head>
<title>Available feeds</title>
</head>
<body>
<ul>
<li><a href="DTU">DTU</a></li>
<li><a href="AWI_1">AWI_1</a></li>
<li><a href="itp04">itp04</a></li>
</ul>
</body>
</html>
END_HTML

    my ($header, $content) = $feed->process_request('');
    
    is_string( $header, $expected_header, 'Header for RSS list.' );
    is_string( $content, $expected_content, 'Content for RSS list.' );

}

# dataset that is not in the database
{
    my $dummy_name = 'DUMMYSET';
    
    my $expected_header = "Status: 404 Not Found\r\nContent-Type: text/html; charset=ISO-8859-1\r\n\r\n";

    my $expected_content = <<END_RSS;
<html>
<head>
<title>Dataset not found</title>
</head>
<body>

<h1>No match where found for the dataset '$dummy_name'</h1>
</body>
</html>

END_RSS

    my ($header, $content) = $feed->process_request($dummy_name);
    
    is_string( $header, $expected_header, 'Header for missing dataset.' );
    is_string( $content, $expected_content, 'Content for missing dataset.' );

}

# test a dataset that is in the database, but has no files
{
    my $expected_header = "Content-Type: application/rss+xml\r\n\r\n";

    my $expected_content = <<END_RSS;
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <generator>METAMOD</generator>
    <link>Link to the METAMOD instance</link>
    <description>METAMOD dataset feed for DTU. Provides updates when new files are available in the dataset.</description>
    <title>METAMOD Dataset feed for DTU</title>
  </channel>
</rss>
END_RSS

    my ($header, $content) = $feed->process_request('DTU');
    
    is_string( $header, $expected_header, 'Header for empty RSS feed' );
    is_string( $content, $expected_content, 'Content for empty RSS feed' );

}

# test a dataset that is in the database and has several files.
{
    my $expected_header = "Content-Type: application/rss+xml\r\n\r\n";

    my $expected_content = <<END_RSS;
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <generator>METAMOD</generator>
    <link>Link to the METAMOD instance</link>
    <description>METAMOD dataset feed for itp04. Provides updates when new files are available in the dataset.</description>
    <title>METAMOD Dataset feed for itp04</title>
    <item>
      <link>http://example.com/somefile1</link>
      <description>Abstract 1</description>
      <title>Title 1</title>
    </item>
    <item>
      <link>http://example.com/somefile2</link>
      <description>Abstract 2</description>
      <title>Title 2</title>
    </item>
  </channel>
</rss>
END_RSS

    my ($header, $content) = $feed->process_request('itp04');
    
    is_string( $header, $expected_header, 'Header for RSS feed' );
    is_string( $content, $expected_content, 'Content for RSS feed' );

}

END {
    empty_metadb();
}
 

