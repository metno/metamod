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

MetamodWeb::Utils::AdminUtils

=head1 DESCRIPTION

Various utility methods for sysadmin interface

=head1 METHODS

=cut

use Moose;
use namespace::autoclean;
use warnings;
use Carp;
use XML::LibXML;
use Data::FormValidator::Constraints qw( FV_max_length );
use MetamodWeb::Utils::FormValidator;

=head2 list_files($dir, $path, $maxfiles)

Counts and lists the files belonging to a dataset. B<NB:> Does not (yet) support
multiple hierarchies of directories (like used in OSI SAF).

Returns a ref to an array [$count, \@files], where $count is the total number
of files and @files contains the names of the first $maxfiles files (without extensions).

=over

=item $dir

The path to the xml file directory (metadata)

=item $path

The dataset name

=item $maxfiles

Only return this many filenames. If undef, returns all.

=back

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
            if ( $maxfiles && ($count > $maxfiles) ) {
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

=head2 read_file($file)

Read the contents of a file and return as string.

=over

=item $file

The complete pathname to the file

=back

=cut

sub read_file {
    my ($self, $file) = @_;

    #printf STDERR "Opening file %s for reading...\n", $file;
    open FH, $file or croak("Couldn't open file $file");
    local $/ = undef;
    my $content = <FH>;
    close(FH);
    return $content;
}

=head2 write_file($file, $content)

Write $content data to $file (via tempfile so won't clobber if aborted).

=over

=item $file

The complete pathname to the file

=item $content

Data string to be written

=item $charset

I<(Optional)> Write file using specified encoding (using Perl-specific names, e.g. 'UTF-8')

=back

=cut

sub write_file {
    my ($self, $file, $content, $charset) = @_;

    #printf STDERR "Opening file %s for writing...\n", $file;
    croak "No permission to write file '$file'" unless -w $file;
    open FH, ">", "$file._" or croak("Couldn't write to disk");
    binmode FH, ":encoding($charset)" if $charset;
    print FH $content;
    close(FH) && rename("$file._", $file);
}

=head2 validate($xml, $schema)

Validate XML string against XML Schema file

=over

=item $xml

XML string to check

=item $schema

Full path to XML Schema file

=back

=cut

sub validate {
    my ($self, $xml, $schema) = @_;
    my $xsd_validator = XML::LibXML::Schema->new( location => $schema );
    my $parser        = XML::LibXML->new();

    my $dom = eval { $parser->parse_string($xml); } or return $@;
    #print STDERR "..XML is well-formed\n";
    if ( eval { $xsd_validator->validate($dom) == 0 } ) {
        #print STDERR "..XML is valid\n";
        return undef;
    } else {
        #print STDERR "..XML is invalid\n";
        return $@;
    }
}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
