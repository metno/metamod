#!/usr/bin/env perl

package Metamod::Search::Feed;

use strict;
use warnings;

use CGI;
use Log::Log4perl qw( get_logger );
use XML::RSS::LibXML;
use Data::Dumper;
use Metamod::Config;
use Metamod::DatasetDb;

=head1 NAME

Metamod::Search::Feed; - Module for generating a RSS feed.

=head1 DESCRIPTION

This process CGI requests and generates XML for dataset RSS feeds.

=head1 FUNCTIONS/METHODS

=cut

sub new {
    my $class = shift;

    my $self = bless {}, $class;
    $self->{_dataset_db} = Metamod::DatasetDb->new();

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

=item return

This function returns to scalar values. The first value is the HTTP header that
is returned to the browser. The  second value is the content that should be
returned to the browser.

=back

=cut

sub process_request {
    my $self = shift;

    my ( $ds_name ) = @_;

    my $header;
    my $content;
    eval {

        my $dataset_db = $self->{_dataset_db};
        if ($ds_name) {
            my $ds = $dataset_db->find_dataset($ds_name);

            if ( !defined $ds ) {
                $content = $self->_create_not_found_page($ds_name);
                $header  = $self->_create_not_found_http();
            } else {
                $content = $self->_create_feed($ds);
                $header  = $self->_create_rss_http();
            }
        } else {
            $content = $self->_create_all_feeds_page();
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

    my $dataset_db = $self->{_dataset_db};
    my $datasets   = $dataset_db->get_level1_datasets();

    my $feeds_html = $self->_create_html_header('Available feeds');
    $feeds_html .= qq{<ul>\n};
    foreach my $dataset (@$datasets) {
        my $ds_name = $dataset->{ds_name};

        my $unqualified_name = $self->_get_unqualified_name($ds_name);

        next if !$unqualified_name;

        my $link = "$unqualified_name";

        $feeds_html .= qq{<li><a href="$link">$unqualified_name</a></li>\n};
    }
    $feeds_html .= qq{</ul>\n};

    $feeds_html .= $self->_create_html_footer();
    return $feeds_html;

}

sub _create_feed {
    my $self = shift;

    my ($ds) = @_;

    my $ds_name          = $ds->{ds_name};
    my $unqualified_name = $self->_get_unqualified_name($ds_name);
    $unqualified_name = $ds_name if !$unqualified_name;

    my $config = Metamod::Config->new();
    my $application_name = $config->get('APPLICATION_NAME');
    my $base_url = $config->get('BASE_PART_OF_EXTERNAL_URL');
    my $local_url = $config->get('LOCAL_URL');

    my $rss = XML::RSS::LibXML->new( version => '2.0' );
    $rss->channel(
        title => "$application_name Dataset feed for $unqualified_name",
        description =>
            "$application_name dataset feed for $unqualified_name. Provides updates when new files are available in the dataset.",
        link      => $base_url . $local_url,
        generator => 'METAMOD',
    );

    my $dataset_db = $self->{_dataset_db};
    my $level2_datasets = $dataset_db->get_level2_datasets( { ds_id => $ds->{ds_id} } );

    # generate a RSS item for each of the level2 datasets that belongs to the level1 dataset.
    get_logger('metamod.search')->debug(Dumper $level2_datasets);
    my @level2_ids = map { $_->{ds_id} } @$level2_datasets;
    get_logger('metamod.search')->debug(Dumper \@level2_ids);
    if (@level2_ids) {
        my $metadata = $dataset_db->get_metadata( \@level2_ids, [qw( title abstract dataref )] );
        foreach my $sub_ds (@$level2_datasets) {
            my $md       = $metadata->{ $sub_ds->{ds_id} };
            my $title    = join " ", @{ $md->{title} };
            my $abstract = join " ", @{ $md->{abstract} };
            my $link     = $md->{dataref}->[0];               #assume one dataref. Concating links does not make sense.

            $rss->add_item(
                title       => $title,
                link        => $link,
                description => $abstract,
            );
        }
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

=head2 $self->_get_unqualified_name( $ds_name )

=over

=item return

Returns the unqualified name part of a ds_name. Returns false if $ds_name does
not have the expected format.

=cut

sub _get_unqualified_name {
    my ( $self, $ds_name ) = @_;

    my $unqualified_name;
    if ( $ds_name =~ /^.+\/(.+)$/ ) {
        $unqualified_name = $1;
    } else {
        get_logger('metamod.search')->warn("Dataset name $ds_name does not have correct format");
    }

    return $unqualified_name;

}

1;
