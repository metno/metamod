package Metamod::Queue::Job::Upload;

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

use strict;
use warnings;
use File::Spec;
use Params::Validate qw(:all);
use Log::Log4perl qw(get_logger);

use Metamod::UploadHelper;

use Moose;
use namespace::autoclean;

has 'error_msg' => ( is => 'rw' );

=head1 NAME

Metamod::Queue::Job::Upload - Server side job for processing uploaded NetCDF files

=head1 DESCRIPTION

... blah blah blah FIXME

This module shall be indenpendent of the actual job queue system that is used
to simplify testing and make it easier to replace the job queue system as
requirements change.

=head1 FUNCTIONS/METHODS

=cut

=head2 process_file

Do upload processing for the file indicated

=head3 Parameters:

=over

=item jobid

=item filename

=item type

Must be either 'FTP', 'WEB' or 'TAF' (test-a-file)

A text string in a format that is more readable than mere byte size.

=back

=cut

sub process_file {
    my $self = shift;

    my $upload_helper = Metamod::UploadHelper->new();
    my ( $jobid, $file, $type ) = validate_pos( @_, 1, 1, 1 );
    my $logger = get_logger('job');

    #print STDERR "Processing file $file ($type)\n";
    $logger->info("Processing file $file ($type)");
    my $error = $upload_helper->process_upload($file, $type);
    if ($error) {
        $logger->warn("Job $file failed: $error");
    } else {
        $logger->debug("Job $file done");
    }

    return ! $error;

}

__PACKAGE__->meta->make_immutable;

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
