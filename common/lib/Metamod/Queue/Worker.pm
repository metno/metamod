package Metamod::Queue::Worker;

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


use warnings;

=head1 NAME

Metamod::Queue::Worker - Generate workers abstracted from queue system
implementation (TheSchwartz)

=head1 DESCRIPTION

Blah blah blah

=head1 FUNCTIONS/METHODS

=cut

use Moose;
use Metamod::Config;
use Metamod::Queue;

=head2 Metamod::Queue::Worker->new($ability)

Generate a new worker with correct application_id and database connection.

Note: Worker methods significantly less powerful than those built into TheSchwartz,
however this is a necessity in order to use coalescion to separate jobs from different
installations using the same database.

=head3 Parameter

Name of ability (a Perl Worker module)

Note that the Perl module must also be C<use>'d in the worker script.

=cut

has 'worker' => ( is => 'rw', isa => 'TheSchwartz' );
has 'coalesce' => ( is => 'rw' );

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
    my $ability = shift or die "Missing worker ability parameter";

    my $queue = Metamod::Queue->new() or die;
    my $appid = $queue->mm_config->get('APPLICATION_ID');
    my $worker = $queue->job_client;
    $worker->can_do( $ability );
    return $class->$orig( worker => $worker, coalesce => $appid )
};

=head2 get_a_job

Finds a job with a corresponding coalesce value (applic_id). This sadly means
that priority is now ignored (could be a problem if trying to use generic
workers).

=cut

sub get_a_job {
    my $self = shift;
    printf STDERR "-- %s jobs for %s ---\n", $self->can_do, $self->coalesce;
    return $self->worker->find_job_with_coalescing_value( $self->can_do, $self->coalesce );
}

=head2 wojk($delay)

Start processing jobs, optionally with a $delay seconds wait between each job.

Note that method names have been tweaked to avoid confusion with native TheSchwartz methods.

=cut

sub wojk {
    my($self, $delay) = @_;
    #$self->worker->work($delay);
    $delay ||= 5;
    while (1) {
        sleep $delay unless $self->wojk_once;
    }
}

=head2 wojk_once($job)

Process the job indicated, or a single suitable job in the queue

=cut

sub wojk_once {
    my $self = shift;
    my $job = shift;  # optional specific job to work on
    $self->worker->work_once($job);
}

=head2 wojk_until_done

Process alle the jobs in the queue

=cut

sub wojk_until_done {
    my $self = shift;
    #
    while (my $job = $self->get_a_job) {
        $self->worker->work_once($job);
    }
}

1;
