package MetamodWeb::Utils::UploadUtils;

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

use Moose;
use namespace::autoclean;
use warnings;

#
# A Metamod::Config object containing the configuration for the application
#
has 'config' => ( is => 'ro', isa => 'Metamod::Config', required => 1 );

=head1 NAME

MetamodWeb::Utils::UploadUtils - Utilities for data upload.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 FUNCTIONS/METHODS

=cut

=head2 validate_datafile

Check filename according to set rules and return dataset name (first part)

=cut

sub validate_datafile {
    my $self = shift;
    my $filename = shift or die "Missing filename";

    return $1 if $filename =~ /^([a-zA-Z0-9\-]+)_[a-zA-Z0-9_\-]+\.([a-zA-Z]+)/;
    return; # false

}

=head2 process_newfiles

Call upload_indexer on files specified

=cut

sub process_newfiles {

    my ($self, $dataset, $dirkey, $filename) = @_;

    #printf STDERR " l4p = '%s'\n", $self->{config}->get('LOG4PERL_CONFIG');

    # FIXME - rewrite upload_indexer as library routine
    my @command = ($self->{config}->get('INSTALLATION_DIR') . "/upload/scripts/upload_indexer.pl",
        "--dataset=$dataset", "--dirkey=$dirkey");
    if (ref($filename) eq 'ARRAY') {
        push @command, @$filename;
    } else {
        push @command, $filename;
    }

    printf STDERR "Running indexer '%s'\n", join(" ", @command);

    # don't use backtick on CGI params - very dangerous! redirect to file instead
    system(@command) == 0
    or die "system @command failed: \n$?";

    return "OK, files registered";

}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
