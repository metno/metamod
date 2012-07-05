#!/usr/bin/perl

use strict;
use warnings;

my $pod = Metamod::Pod::Simple::HTML->new;
$pod->index(1);

foreach (@ARGV) {
    if (/upgrade/) {
        $pod->html_css( '../mmdocs.css?view=co' );
    } else {
        $pod->html_css( 'mmdocs.css?view=co' );
    }
    $pod->parse_from_file($_);
}

# move this to lib later

package Metamod::Pod::Simple::HTML;
use base qw( Pod::Simple::HTML  );

use Data::Dumper;
#$Data::Dumper::Deparse = 1;
$Data::Dumper::Useqq=1;

sub do_link {
    my ( $self, $token ) = @_;
    #print STDERR Dumper($token);
    my $link = $token->attr('to');
    my $type = $token->attr('type');
    my $section = $token->attr('section');

    return $self->SUPER::do_link($token) unless $type eq 'pod';

    if ($section) {
        if ($link) {
            return "./" . $$link[2] . '/' . $$section[2] . ".html?view=co";
        } else {
            # stole this part from Marcus Ramberg... seems to work
            #$section = "#$section"
                #if defined $section and length $section;
            #$self->{base} . "$link$section";
            return $self->{base}||'' . "#$section";
            # TODO - make anchors for head2
        }
    } elsif ($link) {
        return "./" . $$link[2] . ".html?view=co";
    }
}

1;
