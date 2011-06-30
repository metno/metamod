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

# small routine to get lib-directories relative to the installed file
sub getTargetDir {
    my ($finalDir) = @_;
    my ( $vol, $dir, $file ) = File::Spec->splitpath(__FILE__);
    $dir = $dir ? File::Spec->catdir( $dir, ".." ) : File::Spec->updir();
    $dir = File::Spec->catdir( $dir, $finalDir );
    return File::Spec->catpath( $vol, $dir, "" );
}

use lib ( '../../common/lib', getTargetDir('lib'), getTargetDir('scripts') );

use Metamod::UploadMonitor qw(
    init
    syserrorm
    get_dataset_institution
    clean_up_problem_dir
    clean_up_repository
    ftp_process_hour
    web_process_uploaded
    testafile
    %dataset_institution
    %ftp_events
    $file_in_error_counter
    $config
);


use Moose;
use namespace::autoclean;

has 'error_msg' => ( is => 'rw' );

=head1 NAME

Metamod::Queue::Job::Upload - Server side job for processing uploaded NetCDF files

=head1 DESCRIPTION

...

This module shall be indenpendent of the actual job queue system that is used
to simplify testing and make it easier to replace the job queue system as
requirements change.

=head1 FUNCTIONS/METHODS

=cut

sub BUILD {
    my $self = shift;

    &init; # setup UploadMonitor
}

=head2 process_file

Do upload processing for the file indicated

=head3 Parameters:

=over

=item jobid

=item filename

=item type

Must be either 'INDEX' or 'TEST'

A text string in a format that is more readable than mere byte size.

=back

=cut

sub process_file {
    my $self = shift;

    my ( $jobid, $file, $type ) =
        validate_pos( @_, 1, 1, 1 );

    my $logger = get_logger('job');

    $logger->debug("Processing file $file...");

    &get_dataset_institution( \%dataset_institution );

    if ($type eq 'INDEX') {
        web_process_uploaded($file);
    } elsif ($type eq 'TEST') {
        testafile($file);
    } else {
        $logger->error('Unknown job type');
    }

    $logger->debug('Job done');
    return 1;

}

__PACKAGE__->meta->make_immutable;

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
