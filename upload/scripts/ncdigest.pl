#!/usr/bin/perl -w

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

ncdigest.pl

=head1 DESCRIPTION

Check and collect metadata in netCDF files.
The metadata are checked against a configuration file that define which metadata are expected.

This script replaces digest_nc.pl which has been deprecated.

=head1 USAGE

  digest_nc.pl <config> <inputfile> <ownertag> <xmlfile> [<ischild>]   # old format

  ncdigest.pl [--config=<config>] [--ischild] [--xmlfile=<xmlfile>] [--ownertag=<ownertag>] [--files ] <input>  # new format

=head1 OPTIONS

=over

=item --config

Path to etc directory containing configuration files [NOTE: Seems to be ignored?]

=item input

If --files flag is set, same as inputfile below.

If not set, either a URL or a path to a NetCDF file is expected. This is to be implemented later.

=item --files

Instead of a NetCDF file as input, it expects a text file with a list of paths.
The first line in this file is an URL that
points to where the data will be found by users B<[on investigating the code, this
seems not to be correct! FIXME]>.

This dataref URL will be
included as metadata in the XML file to be produced. The rest of the lines
comprise the paths to the files to be parsed, one on each line. These files all belongs
to one dataset.

=item --ownertag

Short keyword (e.g. "DAM") that will tag the data in the database
as owned by a specific project/organisation.
Defaults to UPLOAD_OWNERTAG in master_config (not implemented).

=item xmlfile

Path to an XML file that will receive the result of the netCDF parsing. If this
file already exists, it will contain  the metadata for a previous version
of the dataset. In this case, a new version of the file will be created,
comprising a merge of the old and new metadata.
Defaults to same basename as from NetCDF (not implemented).

=item ischild

(Optional) If true denotes is a child dataset

=back

=cut

use strict;
use warnings;
use File::Spec;
use Getopt::Long;
use Pod::Usage;
use File::Temp qw(tempfile);

# small routine to get lib-directories relative to the installed file
sub getTargetDir {
    my ($finalDir) = @_;
    my ($vol, $dir, $file) = File::Spec->splitpath(__FILE__);
    $dir = $dir ? File::Spec->catdir($dir, "..") : File::Spec->updir();
    $dir = File::Spec->catdir($dir, $finalDir);
    return File::Spec->catpath($vol, $dir, "");
}

use lib ('../../common/lib', getTargetDir('lib'), getTargetDir('scripts'), '.');
use encoding 'utf-8';
use Metamod::Config qw( :init_logger );
use MetNo::NcDigest qw( digest );


# Parse cmd line params
my ($ownertag, $xml_metadata_path, $etcdirectory, $is_child, $pathfilename, $readfromfile);

GetOptions ('ownertag|o=s'  => \$ownertag,
            'xmlfile|x=s'   => \$xml_metadata_path,
            'config=s'      => \$etcdirectory,
            'ischild'       => \$is_child,
            'files|f'        => \$readfromfile,
) or pod2usage() && exit 1;

my $TEMPFILE;

pod2usage(2) unless @ARGV;

if ($readfromfile) {
    $pathfilename = shift;
} else {
    # construct a filelist textfile
    ($TEMPFILE, $pathfilename) = tempfile();
    foreach (@ARGV) {
        print $TEMPFILE "$_\n";
    }
}

if(!Metamod::Config->config_found($etcdirectory)){
    pod2usage "Could not find the configuration on the commandline or the in the environment\n";
}

my $config = Metamod::Config->new( $etcdirectory );

printf STDERR "pathfilename=%s, ownertag=%s, xml_metadata_path=%s, is_child=%s\n", $pathfilename, $ownertag, $xml_metadata_path, $is_child ? 'yes' : 'no';
sleep 10;

digest($pathfilename, $ownertag, $xml_metadata_path, $is_child );

=head1 AUTHOR

Geir Aalberg, E<lt>geira\@met.noE<gt>

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut
