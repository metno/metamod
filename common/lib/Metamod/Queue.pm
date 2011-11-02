package Metamod::Queue;

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

=head1 NAME

Metamod::Queue - Server side job queue.

=head1 DESCRIPTION

This class implements an abstraction over the queue implementation used in
METAMOD. It is in otherwords not an actual queue implementation only a thin
wrapper around a queue implementation. This wrapper is intended to only expose
the parts of the actual queue implementation that is used by METAMOD.

The point of this abstraction is to facilitate easier conversion from
one queue implementation (e.g. TheSchwartz) to another.

=head1 FUNCTIONS/METHODS

=cut

use Metamod::Config;

use Moose;
use Params::Validate qw(:all);
use TheSchwartz;
use TheSchwartz::Job;

#
# The current METAMOD configuration object
#
has 'mm_config' => ( is => 'ro', isa => 'Metamod::Config', default => sub { return Metamod::Config->instance() } );

#
# The TheSchwartz client that is used to insert jobs into the queue
#
has 'job_client' => ( is => 'ro', isa => 'TheSchwartz', lazy => 1, builder => '_build_job_client' );

sub _build_job_client {
    my $self = shift;

    my $mm_config = $self->mm_config();

    my $job_client = TheSchwartz->new(
        databases => [
            {
                dsn  => $mm_config->getDSN_Userbase(),
                user => $mm_config->get('PG_WEB_USER'),
                pass => $mm_config->get('PG_WEB_USER_PASSWORD')
            }
        ]
    );

    return $job_client;


}


=head2 $self->insert_job(%PARAMS)

Insert a new job into the job queue.

=over

=item job_type

A string with the type of job that should be performed. This is used to determine how the job will be executed.

=item job_parameters

A hash reference of job parameters. These parameters can be any thing as required by the job type.

=item priority

The priority of the job.

=item return

Returns 1 if the job was inserted successfully. False otherwise.

=back

=cut
sub insert_job {
    my $self = shift;

    my %params = validate( @_, {
        job_type => { type => SCALAR },
        job_parameters => { type => HASHREF },
        priority => { optional => 1 }
    } );

    my ($job_parameters, $job_type, $priority) = @params{qw(job_parameters job_type priority)};

    my $job = TheSchwartz::Job->new(
        funcname => $job_type,
        arg => $job_parameters,
        priority => $priority,
    );
    my $status = $self->job_client->insert( $job_type, $job_parameters );

    return if !defined $status;

    return 1;

}


1;
