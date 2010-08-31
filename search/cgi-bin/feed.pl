#!/usr/bin/perl -w

use strict;
use File::Spec;

=head1 NAME

B<feed.pl> - CGI script for generating RSS 2.0 feeds.

=head1 DESCRIPTION


=head1 USAGE

 http://hostname/app/feed/      - list of all dataset feeds
 http://hostname/app/feed/foo   - RSS feed for dataset foo

=head1 INSTALLATION

To work, this must be configured in Apache as follows

 # note slash after "feed"
 ScriptAlias     /app/sch/feed/    /path/to/target/cgi-bin/feed.pl/
 RedirectMatch   /app/sch/feed\$   http://hostname/app/sch/feed/

This is generated automatically from master_config.txt if you run
C<trunk/gen_httpd_conf.pl>.

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

my $tail = $query->path_info;
$tail =~ s|^/||;
my $dataset = $tail || $query->param( 'dataset' );

my $feed = Metamod::Search::Feed->new();
my ( $header, $content ) = $feed->process_request( $dataset );

print $header;
print $content if defined $content;
