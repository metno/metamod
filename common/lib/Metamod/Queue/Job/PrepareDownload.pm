package Metamod::Queue::Job::PrepareDownload;

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

use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use Data::Dump qw(dump);
use File::Spec;
use File::Temp qw(tempdir);
use Log::Log4perl qw(get_logger);
use LWP::Simple;
use Params::Validate qw(:all);

use Metamod::Config;

use Moose;
use namespace::autoclean;

has 'error_msg' => ( is => 'rw' );

=head1 NAME

Metamod::Queue::Job::PrepareDownload - Server side job for prepareing a collection basket download.

=head1 DESCRIPTION

This module implements a server side job for preparing a collection basket for
download. It will will fetch a list of files over the network, store the files
in a temporary directory, create a zip file for all the downloaded files, place
the zip file in a configurable location and then send an email with the URL to
the zip file to a specified email address.

This module shall be indenpendent of the actual job queue system that is used
to simplify testing and make it easier to replace the job queue system as
requirements change.

=head1 FUNCTIONS/METHODS

=cut


=head2 $self->prepare_download($jobid, $locations)

Prepare the download and send an email to the user.

=over

=item $jobid

The id of the current job that is being executed.

=item $locations

An array ref of file URLs that should be downloaded and placed in a zip file.

=item $email

The email address that the link should be sent to.

=item return

Returns 1 on success and false otherwise. If it returns false and error message
is available via C<error_msg()>;

=back

=cut
sub prepare_download {
    my $self = shift;

    my ( $jobid, $locations ) = validate_pos( @_, { type => SCALAR }, { type => ARRAYREF } );

    my $logger = get_logger('job');

    my $tmp_dir = tempdir( 'metamod_collection_basket_XXXXX', TMPDIR => 1 );

    my $zip = Archive::Zip->new();
    foreach my $location (@$locations) {

        if ( $location =~ /.*\/(.*\.nc)$/ ) {
            my $destination = File::Spec->catfile( $tmp_dir, $1 );
            $logger->debug("Downloading $location to $destination");

            my $status = getstore( $location, $destination );
            $logger->debug("Download status: $status");

            $zip->addFile( $destination, $1 );

        } else {
            $logger->warn("Location did not have expected format $location");
        }
    }

    my $config          = Metamod::Config->new();
    my $download_area   = $config->get('WEBRUN_DIRECTORY') . "/download";
    my $zip_destination = File::Spec->catfile( $download_area, "${jobid}.zip" );

    if ( $zip->writeToFileNamed($zip_destination) != AZ_OK ) {
        $self->error_msg("Failed to write zip file to '$zip_destination'");
        $logger->error($self->error_msg);
        return;
    }

    $logger->debug('Job done');
    return 1;

}

__PACKAGE__->meta->make_immutable;

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
