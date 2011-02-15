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
use Log::Log4perl qw(get_logger);
use Params::Validate qw(:all);
use POSIX qw(strftime);

use Metamod::Config;
use Metamod::Email;

use Moose;
use namespace::autoclean;

has 'error_msg' => ( is => 'rw' );

=head1 NAME

Metamod::Queue::Job::PrepareDownload - Server side job for prepareing a collection basket download.

=head1 DESCRIPTION

This module implements a server side job for preparing a collection basket for
download. It will will fetch a list of files from disk and add them to a zip
archive. The zip archive will be stored in a WEBRUN_DIRECTORY/download. An
email will then be sent to the specified email address.

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

    my ( $jobid, $locations, $email ) =
        validate_pos( @_, { type => SCALAR }, { type => ARRAYREF }, { type => SCALAR } );

    my $logger = get_logger('job');

    my $zip = Archive::Zip->new();
    foreach my $location (@$locations) {

        if( !(-r $location)){
            $logger->error("Cannot read file at location: $location");
            next;
        }

        my (undef, undef, $filename) = File::Spec->splitpath($location);
        $logger->debug("Adding $location as $filename to archive");
        $zip->addFile( $location, $filename );
    }

    my $config          = Metamod::Config->new();
    my $download_area   = $config->get('WEBRUN_DIRECTORY') . "/download";

    if( !(-d $download_area) ){
        $self->error_msg("'$download_area' is not a directory. Cannot continue to create zip");
        $logger->error($self->error_msg);
        return;
    }

    if( !(-w $download_area )){
        $self->error_msg("'$download_area' is not a writable. Cannot continue to create zip");
        $logger->error($self->error_msg);
        return;
    }

    my $now = time;
    my $zip_filename = $email . '_' . $now . '.zip';
    my $zip_destination = File::Spec->catfile( $download_area, $zip_filename );
    my $zip_url = $config->get('BASE_PART_OF_EXTERNAL_URL') . $config->get('LOCAL_URL') . 'download/' . $zip_filename;

    if ( $zip->writeToFileNamed($zip_destination) != AZ_OK ) {
        $self->error_msg("Failed to write zip file to '$zip_destination'");
        $logger->error( $self->error_msg );
        return;
    }

    my $operator_email = $config->get('OPERATOR_EMAIL');
    if(!$operator_email){
        $self->error_msg("OPERATOR_EMAIL not set. Refusing to send email without it");
        $logger->error( $self->error_msg );
        return;
    }

    my $in_one_week = $now + (3600 * 24 * 7);
    my $datestamp = strftime("%Y-%m-%d %H:%M", localtime($in_one_week));

    my $email_body = <<"END_EMAIL";
Your basket has now been processed and a zip archive with the requested file
can now be downloaded.

The zip archive will be available until $datestamp after that point it
may be deleted and no longer be available.

$zip_url
END_EMAIL

    Metamod::Email::send_simple_email(
        {
            to      => [$email],
            from    => $operator_email,
            subject => 'Collection basket download ready',
            body    => $email_body,
        }
    );

    $logger->debug('Job done');
    return 1;

}

__PACKAGE__->meta->make_immutable;

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
