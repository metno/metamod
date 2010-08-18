#!/usr/bin/env perl

package Metamod::Search::Feed;

use strict;
use warnings;

use CGI;
use Log::Log4perl qw( get_logger );
use XML::RSS::LibXML;

use Metamod::Search::FeedData;

=head1 NAME

Metamod::Search::Feed; - Module for generating a RSS feed.

=head1 DESCRIPTION

This process CGI requests and generates XML for dataset RSS feeds. 

=head1 FUNCTIONS/METHODS

=cut

sub new {
    my $class = shift;

    my $self = bless {}, $class;

    my $feed_data = Metamod::Search::FeedData->new();
    $self->{_feed_data} = $feed_data;

    return $self;

}

=head2 $self->process_request( $ds_name, $url_rewrite )

Process a HTTP request and generate a RSS feed if possible.

An RSS feed will be generated if the dataset can be found in the meta database. If the dataset cannot be found
a 404 header is returned.

If the dataset name is false a HTML page with a link to all available datasets will be created.

In case an exception occurs the error will be logged and 500 header generated.

=over

=item $ds_name

The name of the dataset to create a feed for.

=item $url_rewrite 

A boolean parameter used to indicate if mod_rewrite has been used on the URL.
This parameter is used to control the links on HTML page with links to all
available RSS feeds.

=item return

This function returns to scalar values. The first value is the HTTP header that
is returned to the browser. The  second value is the content that should be
returned to the browser.

=back

=cut

sub process_request {
    my $self = shift;

    my ( $ds_name, $url_rewrite ) = @_;

    my $header;
    my $content;
    eval {

        my $feed_data = $self->{_feed_data};
        if ($ds_name) {
            my $ds = $feed_data->find_dataset($ds_name);

            if ( !defined $ds ) {
                $content = $self->_create_not_found_page($ds_name);
                $header  = $self->_create_not_found_http();
            } else {
                $content = $self->_create_feed($ds);
                $header  = $self->_create_rss_http();
            }
        } else {
            $content = $self->_create_all_feeds_page($url_rewrite);
            $header  = $self->_create_std_http();
        }

        }
        or do {

        my $error_msg = $@;    #must store the error message since it is mangled by Log::Log4perl
        get_logger('metamod.search')->error( 'Failure in RSS feed generation: ' . $error_msg );
        $header = $self->_create_error_http();
        };

    return ( $header, $content );

}

sub _create_all_feeds_page {
    my $self = shift;

    my ($url_rewrite) = @_;

    my $feed_data = $self->{_feed_data};
    my $datasets  = $feed_data->get_datasets();

    my $feeds_html = $self->_create_html_header('Available feeds');
    $feeds_html = q{<ul>};
    foreach my $dataset (@$datasets) {
        my $name = $dataset->{name};

        my $link = $name;
        if ( !$url_rewrite ) {
            $link = "feed.pl?dataset=$name";
        }

        $feeds_html .= qq{<li><a href="$link">$name</a></li>};
    }
    $feeds_html .= q{</ul>};

    $feeds_html .= $self->_create_html_footer();
    return $feeds_html;

}

sub _create_feed {
    my $self = shift;

    my ($dataset) = @_;

    my $ds_name   = $dataset->{name};
    my $feed      = {};
    my $feed_data = $self->{_feed_data};
    my $files     = $feed_data->get_files( { ds_name => $ds_name } );

    my $rss = XML::RSS::LibXML->new( version => '2.0' );
    $rss->channel(
        title       => "METAMOD Dataset feed for $ds_name",
        description => "METAMOD dataset feed for $ds_name. Provides updates when new files are available in the feed.",
        link        => 'Link to the METAMOD instance',
        generator   => 'METAMOD',
    );

    foreach my $file (@$files) {
        $rss->add_item(
            title       => $file->{title},
            link        => $file->{url},
            description => $file->{abstract},
        );
    }

    return $rss->as_string();

}

sub _create_not_found_page {
    my $self = shift;

    my ($ds_name) = @_;

    my $header = $self->_create_html_header('Dataset not found');
    my $footer = $self->_create_html_footer();
    my $html   = <<"END_HTML";
$header
<h1>No match where found for the dataset '$ds_name'</h1>
$footer
END_HTML

}

sub _create_not_found_http {
    my $self = shift;

    my $cgi = CGI->new();
    return $cgi->header( '-type' => 'text/html', '-status' => '404 Not Found' );

}

sub _create_error_http {
    my $self = shift;

    my $cgi = CGI->new();
    return $cgi->header( '-type' => 'text/html', '-status' => '500 Internal Server Error' );
}

sub _create_rss_http {
    my $self = shift;

    my $cgi = CGI->new();
    return $cgi->header( '-type' => 'application/rss+xml' );

}

sub _create_std_http {
    my $self = shift;

    my $cgi = CGI->new();
    return $cgi->header('text/html');
}

sub _create_html_header {
    my $self = shift;

    my ($title) = @_;

    my $html = <<"END_HTML";
<html>
<head>
<title>$title</title>
</head>
<body>
END_HTML

    return $html;

}

sub _create_html_footer {
    my $self = shift;

    my $html = <<END_HTML;
</body>
</html>
END_HTML

}

1;
