package MetamodWeb::Utils::AdminUtils;

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

blah blah blah

=head1 DESCRIPTION

blah blah blah

=head1 METHODS

blah blah blah

=cut

use Moose;
use namespace::autoclean;
use warnings;
use Carp;
use XML::LibXML;
use Data::FormValidator::Constraints qw( FV_max_length );
use MetamodWeb::Utils::FormValidator;

#has 'config' => ( is => 'ro', default => sub { Metamod::Config->new() } );

=head1 NAME

blah blah blah

=head1 DESCRIPTION

blah blah blah

=head1 METHODS

blah blah blah

=cut

sub list_files {
    my ($self, $dir, $path, $maxfiles) = @_;
    my $list = {};
    chdir "$dir/$path";
    foreach (<*.xml>) { # find dataset metadata files
        my ($base) = /(.+)\.xml$/;
        if (-d $base) { # check if level 2
            my @files = map /$base\/(.+)\.xml$/, <$base/*.xml>; # strip file ext
            my $count = @files;
            if ($count > $maxfiles) {
                my @short = splice @files, 0, $maxfiles;
                $$list{$base} = [$maxfiles, \@short];
            }
            $$list{$base} = [$count, \@files];
        } else {
            $$list{$base} = [0];
        }
    }
    return $list;
}

sub read_file {
    my ($self, $file) = @_;

    printf STDERR "Opening file %s for reading...\n", $file;
    open FH, $file or croak("Couldn't open file $file");
    local $/ = undef;
    my $content = <FH>;
    close(FH);
    return $content;
}

sub write_file {
    my ($self, $file, $content) = @_;

    printf STDERR "Opening file %s for writing...\n", $file;
    open FH, ">", "$file._" or croak("Couldn't open file $file");
    print FH $content;
    close(FH) && rename("$file._", $file);
}

sub validate {
    my ($self, $xml, $schema) = @_;
    my $xsd_validator = XML::LibXML::Schema->new( location => $schema );
    my $parser        = XML::LibXML->new();

    my $dom = eval { $parser->parse_string($xml); } or return $@;
    print STDERR "..XML is well-formed\n";
    if ( eval { $xsd_validator->validate($dom) == 0 } ) {
        print STDERR "..XML is valid\n";
        return undef;
    } else {
        print STDERR "..XML is invalid\n";
        return $@;
    }
}


=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
