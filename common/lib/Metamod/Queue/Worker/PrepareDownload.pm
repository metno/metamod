package Metamod::Queue::Worker::PrepareDownload;

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

use TheSchwartz::Job;

use Metamod::Queue::Job::PrepareDownload;

=head1 NAME

Metamod::Queue::Worker::PrepareDownload - A TheSchwartz compatible worker for preparing a collection basket download

=head1 DESCRIPTION

This module acts as glue between C<TheSchwartz> job queue system/module and
C<Metamod::Queue::Job::PrepareDownload>. See the job module for more details.

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

    eval {

        my $jobid = $job->jobid();
        my $locations = $job->arg->{locations};
        my $email = $job->arg->{email};

        my $mm_job = Metamod::Queue::Job::PrepareDownload->new();
        my $success = $mm_job->prepare_download($jobid, $locations, $email);

        if( !$success ){
            die $mm_job->error_msg();
        }

        $job->completed();

    } or print $@;

}

# keep the exit status for one week
sub keep_exit_status_for { 60 * 60 * 24 * 7 }

# grap the job for one hour
sub grab_for             { 60 * 60 * 1 }

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
