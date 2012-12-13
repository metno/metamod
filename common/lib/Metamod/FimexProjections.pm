package Metamod::FimexProjections;

=begin LICENSE

Copyright (C) 2010 met.no

This file is part of METAMOD

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

Metamod::FimexProjections - access-layer for fimexProjections xml-files

=head1 SYNOPSIS

=head1 DESCRIPTION

Class for hiding the xml-structure and giving easy access to the FimexSetup string.

Example of fimex-setup string:

 <fimexProjections xmlns="http://www.met.no/schema/metamod/fimexProjections">
 <dataset urlRegex="" urlReplace=""/>
 <!-- see fimex-interpolation for more info on options -->
 <projection name="Lat/Long" method="nearestghbor"
           projString="+proj=latlong +elips=sphere +a=6371000 +e=0"
           xAxis="0,1,...,x;relativeStart=0"
           yAxis="0,1,...,x;relativeStart=0"
           toDegree="true"/>
 <projection name="Stereo" method="coord_nearestneighbor"
           projString="+proj=stere +elips=sphere +lon_0=-32 +lat_0=90 +lat_ts=60 +a=6371000 +e=0"
           xAxis="0,50000,...,x;relativeStart=0"
           yAxis="0,50000,...,x;relativeStart=0"
           toDegree="false" />
 </fimexProjections>

=cut

our $VERSION = do { my @r = (q$LastChangedRevision$ =~ /\d+/g); sprintf "0.%d", @r };

our $DEBUG = 0;

use strict;
use warnings;
use Metamod::Config;
use XML::LibXML;
use Params::Validate qw();
use Log::Log4perl;

my $logger = Log::Log4perl::get_logger('metamod::common::'.__PACKAGE__);

=head1 METHODS

=head2 static getFimexProjectionsSchemaPath()

=over 4

=item returns the path to the schema for the fimex projections

=back

=cut

sub getFimexProjectionsSchemaPath {
    my $config = Metamod::Config->instance();
    return $config->get('INSTALLATION_DIR') . "/common/schema/fimexProjections.xsd";
}

=head2 constant FIMEX_PROJECTIONS_NS

=over 4

=item return the xml namespace of FimexProjections

=back

=cut

use constant FIMEX_PROJECTIONS_NS => "http://www.met.no/schema/metamod/fimexProjections";


=head2 new([$str, $validate])

=over 4

=item $str default "", xml-string to initialize the FimexProjections with

=item $validate default 0, check if $str should be validated

=back

Initialize a new instance of fimexProjections. This method dies if $str is not valid xml.

=cut

sub new {
    my ($class, $str, $validate) = Params::Validate::validate_pos(@_, 1, { default => "" }, { default => 0});

    my $self = bless {
        urlRegex => undef,
        urlReplace => undef,
        projections => {}, # hash of projections-hashes
    }, $class;

    if ($str) {
        my $doc = XML::LibXML->new()->parse_string($str)
            or $logger->error_die("Cannot xml-parse string $str");
        if ($validate) {
            my $xmlschema = XML::LibXML::Schema->new( location => $class->getFimexProjectionsSchemaPath() )
                or $logger->error_die("cannot parse schema at: ". $class->getFimexProjectionsSchemaPath() );
            eval { $xmlschema->validate($doc); };
            if ($@) {
                $logger->error_die("schema validation failed for $str: $@");
            }
        }

        $self->parseXmlDoc_($doc);
    }
    return $self;
}

# internal function to parse xml-dom information into the instance
sub parseXmlDoc_ {
    my ($self, $doc) = @_;

    my $xpc = XML::LibXML::XPathContext->new($doc);
    $xpc->registerNs('f', $self->FIMEX_PROJECTIONS_NS());

    # read urlRegex and urlReplace
    foreach my $node ( $xpc->findnodes('/f:fimexProjections/f:dataset') ) {
        foreach my $att ( $node->attributes ) {
            if ($att->name eq 'urlRegex') {
                $self->{urlRegex} = $att->value;
            } elsif ($att->name eq 'urlReplace') {
                $self->{urlReplace} = $att->value;
            }
        }
    }

    foreach my $node ( $xpc->findnodes('/f:fimexProjections/f:projection') ) {
        my %projHash;
        foreach my $att ( $node->attributes ) {
            $projHash{$att->name} = $att->value;
        }
        if ($projHash{name}) {
            $self->{projections}{$projHash{name}} = \%projHash;
        }
    }
}

=head2 listProjections

list the available projections

=cut

sub listProjections {
    my ($self) = @_;
    return keys %{ $self->{projections} };
}

=head2 getProjectionProperty($projName, $propName)

=over 4

=item $projName the name of the projection

=item $propName the name of the projections property

=item returns projection-string or undef if either projection or property not exist

=back

=cut

sub getProjectionProperty {
    my ($self, $projName, $propName) = Params::Validate::validate_pos(@_, 1, 1, 1);
    if ( exists $self->{projections}{$projName} &&
         exists $self->{projections}{$projName}{$propName} ) {
        return $self->{projections}{$projName}{$propName};
    }
    return undef;
}

=head2 getURLRegex

=over 4

=item return URLRegex string. The URLRegex string comes together with
      the regex-escape characters, so a regex like $var =~ s^/from/this/^/to/that/^
      would come like ^/from/this/^. This is inherited by php regex-behaviour.

=back

=cut

sub getURLRegex {
    my ($self) = @_;
    return $self->{urlRegex};
}

=head2 getURLReplace

=over 4

=item return URLReplace string

=back

=cut

sub getURLReplace {
    my ($self) = @_;
    return $self->{urlReplace};
}

1;
__END__


=head1 AUTHOR

Heiko Klein, E<lt>H.Klein@met.noE<gt>

=head1 SEE ALSO

=cut
