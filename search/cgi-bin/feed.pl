#!/usr/bin/perl -w

use strict;
use File::Spec;

=head1

CGI script for generating RSS 2.0 feeds.

The script can be reached both as a CGI script and from the feed/ adress using
mod_rewrite

=head2 Parameters

=over

=item dataset

The dataset to create a feed for.

=item url_rewrite

A boolean parameter used to tell the script that mod_rewrite has been used and
it was access via the feed/ URL

=back

=cut

# small routine to get lib-directories relative to the installed file
sub getTargetDir {
    my ($finalDir) = @_;
    my ($vol, $dir, $file) = File::Spec->splitpath(__FILE__);
    $dir = $dir ? File::Spec->catdir($dir, "..") : File::Spec->updir();
    $dir = File::Spec->catdir($dir, $finalDir);
    return File::Spec->catpath($vol, $dir, "");
}

use lib ('../common/lib', getTargetDir('lib'));

use CGI;

use Metamod::Config qw( :init_logger );
use Metamod::Search::Feed;

my $query = CGI->new();

my $dataset = $query->param( 'dataset' );
my $url_rewrite = $query->param( 'url_rewrite' );

my $feed = Metamod::Search::Feed->new();
my ( $header, $content ) = $feed->process_request( $dataset, $url_rewrite );

print $header;
print $content if defined $content;