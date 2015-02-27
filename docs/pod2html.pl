#!/usr/bin/perl

use strict;
use warnings;
use File::Spec;
use Data::Dumper;
use Pod::Simple 3.30;

my $verbose = 0;
my $pod = Metamod::Pod::Simple::HTML->new;
$pod->index(1);

foreach (@ARGV) {
    if (/^-v$/) {
        $verbose = 1;
        next;
    }

    # compute relative path to top dir
    my ($volume, $directories, $file) = File::Spec->splitpath( $_ );
    $directories =~ s|/$||;
    my @dirs = File::Spec->splitdir( $directories );
    my $topdirpath = File::Spec->catdir( map { '..' if $_ } @dirs );
    print STDERR Dumper \$directories, \$topdirpath, \@dirs if $verbose;
    $topdirpath .= '/' if $topdirpath;

    $pod->html_css( "${topdirpath}mmdocs.css?view=co" );
    print STDERR "Parsing file $_:\n" if $verbose;
    $pod->top_anchor("<div id='banner'>METAMOD Documentation | "
                     . "<a name='___top' href='${topdirpath}index.html'>main menu</a>"
                     . ($topdirpath ? " | <a href='index.html'>$directories</a>" : '')
                     ."</div>");
    $pod->parse_from_file($_);
}


#######################################
# move below to lib later
# also add Pod::Simple 3.30 to cpanfile

package Metamod::Pod::Simple::HTML;
use base qw( Pod::Simple::HTML  );

use Data::Dumper;
#$Data::Dumper::Deparse = 1;
$Data::Dumper::Useqq=1;

=head3 Linking to source files

Thus:

  L<"debianE<sol>control"|debian/control>

=cut

sub do_pod_link {
    my ( $self, $token ) = @_;
    #print STDERR Dumper($token) if $verbose;
    my $link = $token->attr('to');
    my $type = $token->attr('type');
    my $section = $token->attr('section');

    if ($section) {
        if ($link) {
            if ($$link[2] =~ /^\.\./ or -d $$link[2]) {
                # link to POD in parent dir
                # relative link to file outside docs in source tree
                printf STDERR "--- %s\n", $token->dump if $verbose;
                return "./$$link[2]/$$section[2].html?view=co";
            } else {
                # relative from source root instead of docs/html
                printf STDERR ">>> %s\n", $token->dump if $verbose;
                return "../../$$link[2]/$$section[2]?view=co";
             }
        } else {
            # internal anchor links
            # stole this part from Marcus Ramberg... seems to work
            #$section = "#$section"
                #if defined $section and length $section;
            #$self->{base} . "$link$section";
            printf STDERR "### %s\n", $token->dump if $verbose;
            return $self->{base}||'' . "#$section";
            # TODO - make anchors for head2
        }
    } elsif ($link) {
        # link to POD in same dir (?)
        printf STDERR "??? %s\n", $token->dump if $verbose;
        return "./$$link[2].html?view=co";
    }
}

1;
