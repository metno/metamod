package MetamodWeb::Utils::XML;

=begin LICENSE

METAMOD is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

METAMOD is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with METAMOD; if not, write to the Free Software
Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

=end LICENSE

=cut



use warnings;

use Moose;
use namespace::autoclean;
use XML::LibXML;
#use XML::LibXML::XPathContext;
use LWP::UserAgent;
use Carp;
use Data::Dumper;
use Log::Log4perl qw(get_logger);


# The Log::Log4perl logger to use in the this class
#
has 'logger' => ( is => 'ro', isa => 'Log::Log4perl::Logger', default => sub { get_logger('metamodweb') } );

has 'parser' => ( is => 'ro', isa => 'XML::LibXML', default => sub { XML::LibXML->new(load_ext_dtd => 0) } );

=head2 getXML()

Fetch XML document from URL and parse as libxml DOM object

=cut

sub getXML {
    my $self = shift;
    my $url = shift or die "Missing URL";
    $self->logger->debug('GET ' . $url);
    my $ua = LWP::UserAgent->new;
    $ua->timeout(100);
    #$ua->env_proxy;

    my $response = $ua->get($url);

    if (!$response->is_success) {
        #abandon($response->status_line . ': ' . $url, 502);
		$self->logger->info("getXML failed for for $url: " . $response->status_line);
		croak($response->status_line);
    }

    #print STDERR $response->content;
    my $dom;
    #eval { $dom = $parser->parse_string($response->content) } or abandon($@, 502);
    eval { $dom = $self->parser->parse_string($response->content) } or croak($@);
    return $dom;

}



=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
