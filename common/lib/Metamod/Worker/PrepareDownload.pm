package Metamod::Worker::PrepareDownload;

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

use base 'TheSchwartz::Worker';

use strict;
use warnings;

use Data::Dump qw(dump);
use File::Spec;
use File::Temp qw( tempdir );
use Log::Log4perl qw(get_logger);
use LWP::Simple;
use TheSchwartz::Job;

use Metamod::Config;

=head1 NAME

Metamod::Worker::PrepareDownload - A TheSchwartz compatible worker for preparing a collection basket download

=head1 DESCRIPTION

The module implements a C<TheSchwartz> compatible worker (i.e. a
TheSchwartz::Worker sub class) that will fetch a list of files over the
network, store the files in a temporary directory, create a zip file for all
the downloaded files, place the zip file in a configurable location and then
send an email with the URL to the zip file to a specified email address.

=head1 METHODS

=cut

=head2 work($class, $job)

Method that is called to perform the work.

=over

=item $class

The current class

=item $job

A TheSchwartz::Job object. The job is expected to have the arguments
C<locations> and C<email>.

C<locations> should be an array reference of complete URLs that can be used to
download files. This function will not perform any form of calculation on the
URLs.

C<email> should be a valid email address that will be used for sending an email
with the URL to the generated zip file.

=back

=cut
sub work {
    my ( $class, $job ) = @_;

    my $logger = get_logger();

    my $jobid = $job->jobid();
    my $tmp_dir = tempdir( 'metamod_collection_basket_XXXXX', TMPDIR => 1 );

    use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
    my $zip = Archive::Zip->new();

    my $locations = $job->arg->{locations};
    foreach my $location (@$locations) {

        if ( $location =~ /.*\/(.*\.nc)$/ ) {
            my $destination = File::Spec->catfile( $tmp_dir, $1 );
            $logger->debug( "Downloading $location to $destination" );

            my $status = getstore( $location, $destination );
            $logger->debug( "Download status: $status" );

            $zip->addFile($destination, $1);

        } else {
            $logger->warn( "Location did not have expected format $location" );
        }
    }

    my $config          = Metamod::Config->new();
    my $download_area   = $config->get('WEBRUN_DIRECTORY') . "/download";
    my $zip_destination = File::Spec->catfile($download_area, "${jobid}.zip");

    if ( $zip->writeToFileNamed($zip_destination) != AZ_OK ) {
        $logger->error("Failed to write zip file to '$zip_destination'");
        die "Failed to write zip file to '$zip_destination'";
    }

    $job->completed();
    $logger->debug('Job done');
}

# keep the exit status for one week
sub keep_exit_status_for { 60 * 60 * 24 * 7 }

# grap the job for one hour
sub grab_for             { 60 * 60 * 1 }

1;
