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

use Moose;
use warnings;

use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use Data::Dump qw(dump);
use File::Spec;
use Log::Log4perl qw(get_logger);
use Params::Validate qw(:all);
use POSIX qw(strftime);
use LWP::UserAgent;
use Try::Tiny;
use Filesys::DfPortable;
use File::Temp;
use Data::Dumper;

use Metamod::Config;
use Metamod::Email;

use namespace::autoclean;

has 'config' => (
    is => 'ro',
    required => 1,
    isa => 'Metamod::Config',
    default => sub { Metamod::Config->instance() }
);

has 'logger' => (
    is => 'ro',
    required => 1,
    default => sub { get_logger('job') }
);

has 'error_msg' => ( is => 'rw' );

has 'recipient' => ( is => 'rw', required => 1, ); # add email address validation - FIXME

has 'download_area' => (
    is => 'ro',
    required => 1,
    default => sub {
        my $self = shift;
        $self->config->get('WEBRUN_DIRECTORY') . "/download";
    }
);

has 'operator_email' => (
    is => 'ro',
    required => 1,
    default => sub {
        my $self = shift;
        my $username = $ENV{LOGNAME} || $ENV{USER} || getpwuid($<);
        $self->config->get('OPERATOR_EMAIL') || "$username\@" . $self->config->get('SERVER');
    }
);

has 'max_filesize' => (
    is => 'ro',
    required => 1,
    default => sub {
        my $self = shift;
        $self->config->get('MAX_UPLOAD_SIZE_BYTES');
    }
);

has 'ua' => (
    is => 'ro',
    required => 1,
    default => sub {
        my $self = shift;
        my $ua = LWP::UserAgent->new;
        $ua->timeout(10);
        #$ua->env_proxy;
        $ua->max_size( $self->max_filesize ); # do not download files larger than this
        $ua;
    }
);

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

=head1 TODO

Regression tests

Add cron job to remove files after two weeks

=head1 SYNOPSIS

    my $fluffer = Metamod::Queue::Job::PrepareDownload->new(recipient => $email);
    $fluffer->prepare_download($jobid, $locations)
        or die $fluffer->error_msg();

=head1 METHODS

=head2 $p = Metamod::Queue::Job::PrepareDownload->new(recipient => $email)

Construct a prepper object

=head3 Arguments

=over

=item recipient

User's email address

=back

=cut

=head2 $p->prepare_download($jobid, $locations)

Prepare the download and send an email to the user.

=head3 Arguments

=over

=item $jobid

The id of the current job that is being executed.

=item $locations

An array of URLs/filepaths that should be downloaded and placed in a zip file.

=back

Returns 1 on success and false otherwise. If it returns false an error message
is available via C<error_msg()>;

=cut

sub prepare_download {
    my $self = shift;

    my ( $jobid, $locations ) =
        validate_pos( @_, { type => SCALAR }, { type => ARRAYREF } );

    try {
        $self->_check_download_area();
        $self->_check_disk_space();
    } catch {
        $self->report_error($_);
        return;
    };

    my $now = time;
    my $zip_filename = $self->recipient . "_$now.zip";
    my $zip_destination = File::Spec->catfile( $self->download_area, $zip_filename );
    my $zip_url = $self->config->get('BASE_PART_OF_EXTERNAL_URL') . $self->config->get('LOCAL_URL') . '/download/' . $zip_filename;

    my $tmpdir = File::Temp->newdir( "$zip_filename~XXXX", DIR => $self->download_area ); # will be deleted after going out of scope

    # prepare zip archive
    my $zip = Archive::Zip->new();
    #print STDERR Dumper $locations;
    foreach my $location (@$locations) {
        $self->logger->info("Processing file for download: $location");

        my ($local_file, $basename) = $self->make_file_available($location, $tmpdir) or next;

        if( !(-r $local_file)){
            $self->report_error("Cannot read file at location: $local_file");
            next;
        }

        $self->logger->debug("Adding $local_file as $basename to archive");
        $zip->addFile( $local_file, $basename );
    }

    # generate zipfile
    if ( $zip->writeToFileNamed($zip_destination) != AZ_OK ) {
        $self->report_error("Failed to write zip file to '$zip_destination'");
        return;
    }

    # zip archive created, now generate email report
    my $in_one_week = $now + (3600 * 24 * 7);
    my $datestamp = strftime("%Y-%m-%d %H:%M", localtime($in_one_week));
    $self->logger->warn("Deleting file $zip_destination on $datestamp - not yet implemented");

    my $email_body = <<"END_EMAIL";
Your basket has now been processed and a zip archive with the requested file
can now be downloaded.

The zip archive will be available until $datestamp.
After that point it may be deleted and no longer be available.

$zip_url
END_EMAIL

    $self->send_email($email_body);
    $self->logger->debug('Job done');
    return 1;

}

=head1 INTERNAL METHODS

=head2 $self->make_file_available($file, $dir)

Download $file to $dir via HTTP if not local.

Returns list (<path to file>, <filename to use in zip>).

=back

=cut

sub make_file_available {
    my ($self, $file, $dir) = @_;
    
    # check if local file
    if ( $file !~ /^https?:/ ) { # local file
        my @path = File::Spec->splitpath($file);
        return ($file, $path[2]);
    }

    # check diskspace before each download so we don't slowly eat up disk
    try {
        $self->_check_disk_space();
    } catch {
        $self->report_error($_);
        return;
    };

    $self->logger->info("Downloading $file to temporary directory $dir");
    my $tmpfile = File::Temp->new(
        DIR => $dir,
        UNLINK => 0, # let newdir() delete files after use
    );
    $self->logger->debug("Created file ", $tmpfile->filename); # full path

    my $response = $self->ua->get($file, ':content_file' => $tmpfile->filename);
    if ($response->is_success) {
        return ($tmpfile->filename, $response->filename);
    } else {
        $self->report_error("Download of file $file unsuccessful:\n". $response->status_line);
        return;
    }
}

=head2 $self-report_error($error)

Log and report $error to user

=cut

sub report_error {
    my ($self, $error) = @_;
    $self->error_msg($error);
    $self->logger->error($error);
    my $email_body = <<"END_EMAIL";
Your basket download could not be processed due to the following error:

$error

Sorry about that. The error has been logged.
END_EMAIL
    $self->send_email($email_body);
}

=head2 $self-send_email($text)

Wrapper for mailer

=cut

sub send_email {
    my ($self, $body) = @_;
    Metamod::Email::send_simple_email(
        {
            to      => [ $self->recipient ],
            from    => $self->operator_email,
            subject => 'Collection basket download notification',
            body    => $body,
        }
    );
}

=head2 $self-_check_download_area

Make sure download dir is writable

=cut

sub _check_download_area {
    my $self = shift;
    die $self->download_area . ' is not a directory. Cannot continue to create zip' unless -d $self->download_area;
    die $self->download_area . ' is not writable. Cannot continue to create zip' unless -w $self->download_area;
}

=head2 $self-_check_disk_space

Make sure we have enough disk space (2 x MAX_UPLOAD_SIZE_BYTES to account for both downloads and zip archive).
Should be run before every download.

=cut

sub _check_disk_space {
    my $self = shift;
    my $df = dfportable($self->download_area) or die "Can't calculate disk space";
    my $free = $df->{bfree};
    $self->logger->info("$free bytes left on device " . $self->download_area);
    die "Not enough disk space left for download in " . $self->download_area
        unless $free > 2 * $self->max_filesize;
}

__PACKAGE__->meta->make_immutable;

=head1 AUTHOR

Geir Aalberg, E<lt>geira@met.noE<gt>

=head1 LICENSE

Copyright (C) 2014 The Norwegian Meteorological Institute.

METAMOD is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
