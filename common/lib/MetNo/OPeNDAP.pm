package MetNo::OPeNDAP;

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

=head1 NAME

MetNo::OPeNDAP

=head1 DESCRIPTION

Tools for reading OPeNDAP streams (experimental)

=head1 SYNOPSIS

  use MetNo::OPeNDAP;
  my $server = MetNo::OPeNDAP->new($url) or die $@;
  print $server->ddx;
  print $server->das;

=head1 METHODS

=cut


use strict;
use warnings;
use LWP::Simple qw();
use XML::LibXML;
use XML::LibXML::XPathContext;

my $parser = XML::LibXML->new();

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    $$self{'url'} = shift or die "Missing URL param";
    return $self;
}

=head2 getdata

Download data via OPeNDAP

=cut

sub getdata {
    my $self = shift;
    my $type = shift or die;
    my $url = $self->{url} . ".$type";
    my $content = LWP::Simple::get( $url );
    die "Couldn't get it from $url" unless defined $content;
    #print STDERR $content;
    return $content;
}

=head2 das

Get the DAS metadata

=cut

sub das { # should probably be implemented as a subclass
    my $self = shift;
    my $das = $self->getdata('das');
    return $das;
}

=head2 ddx

Get XML representation of metadata

=cut

sub ddx { # should probably be implemented as a subclass
    my $self = shift;
    my $ddx = $self->getdata('ddx');
    return $parser->parse_string($ddx);
}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=head1 AUTHOR

Geir Aalberg, E<lt>geira@met.noE<gt>

=cut

1;
