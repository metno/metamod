package MetamodWeb::Utils::XML::Generator;

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

#use Moose;
use namespace::autoclean;

use strict;
use warnings;

#use base 'XML::LibXML::Document';
our @ISA = ('XML::LibXML::Document');

sub new {
    my $self = new XML::LibXML::Document;
    bless $self, 'MetamodWeb::Utils::XML::Generator';
    return $self;
}

=head1 NAME

MetamodWeb::Utils::XML::Generator - Create an XML DOM tree programmatically

=head1 SYNOPSIS

    my $dom = new MetamodWeb::Utils::XML::Generator;

    $dom->setDocumentElement(
        $dom->tag('html', { xmlns => "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd" } , [
            $dom->tag('head', [
                $dom->tag('meta', {
                    HTTP-EQUIV => "REFRESH",
                    content    => "0; url=http://www.example.com/index.html"
                })
            ])
        ])
    );

    print $dom->toString;

=head1 DESCRIPTION

Convenience methods for generating XML... not in production use... expect changes

=head1 FUNCTIONS/METHODS

=head2 tag

Generates a LibXML::Element node with a given name (string), attributes (hashref) and children nodes (arrayref).
Namespace is set

=cut

sub tag {
    # create a new element, optionally with given attributes (hash ref),
    # childnodes (array ref) and/or text content (string)
    my $self = shift;

    my $name = shift() or die "Missing tag name";
    #printf STDERR "<%s>\n", $name;
    my $node = $self->createElement($name);

    foreach my $param(@_) {
        if (ref($param) eq 'HASH') { # attributes
            foreach my $attr (keys %$param) {
                #printf STDERR "  \@%s = '%s'\n", $attr, $$param{$attr};
                my $value = $$param{$attr};
                if ($attr =~ /^xmlns$|^xmlns:(\w+)$/) {
                    # now actually namespace-aware
                    $node->setNamespace( $value , $1, 0 );
                } else {
                    $node->setAttribute($attr, $value) if defined $value # skip empty attrs
                }
            }
        } elsif (ref($param) eq 'ARRAY') { # child elements
            foreach (@$param) {
                #printf STDERR "  <%s>\n", $_->nodeName;
                $node->addChild($_);
            }
        } elsif ( ! ref($param) ) { # text content
            #printf STDERR "  '%s'\n", $param;
            $node->appendText($param);
        }
    }

    return $node;
}

sub com {
    # generate a comment node with the string supplied as argument
    my $self = shift;
    return XML::LibXML::Comment->new( ' '.shift().' ' );
}

#sub root {
#    # set root element
#    my $self = shift;
#    my $root = shift or die "Mussing root element";
#    return $self->{dom}->setDocumentElement($root);
#}
#
#sub toString {
#    # set root element
#    my $self = shift;
#    return $self->{dom}->toString(1);
#}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
