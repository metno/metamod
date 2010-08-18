#!/usr/bin/env perl

package Metamod::Search::FeedData;

use strict;
use warnings;

use Params::Validate qw( :all );

=head1 NAME

Metamod::Search::FeedData - API for accessing data necessary for the feeds.

=head1 DESCRIPTION

=head1 FUNCTIONS/METHODS

=cut

sub new {
    my $class = shift;

    my $self = bless {}, $class;

    return $self;

}

=head2 $self->find_dataset( $ds_name )

Search the database for a dataset

=over

=item $ds_name

The name of the dataset.

=item return 

Returns undef if the dataset cannot be found in the database. Otherwise it
returns a hashref with information about the dataset.

=back

=cut

sub find_dataset {
    my $self = shift;

    my ($ds_name) = @_;

    if( $ds_name eq 'hirlam12' ){
        return { name => $ds_name }
    }
    
    return;

}

=head2 $self->get_files( NAMED_PARAMS )

Get the files associated with a dataset.

=over

=item ds_name

The name of the dataset to get the associated files for.

=item max_age (optional, default = 90)

The maximum age of a file if the number specified in C<max_files> is to large.

=item max_files (optional, default = 100)

The maximum number of files that can be of any age. If the number of files in
the dataset is larger than this, all files older than C<max_age> will be removed.

=item return

A reference to an array of hash references. Each hashreference contains the
following information: the name of the file, the abstract of the file and the
URL to the file where it can be downloaded.

=back

=cut
sub get_files {
    my $self = shift;

    my %parameters = validate( @_, { ds_name => 1, max_files => { default => 100, }, max_age => { default => 90 } } );
    
    return [
        { title => 'file 1', url => 'http://localhost/test', abstract => 'Testing testing testing' },
        { title => 'file 2', url => 'http://localhost/test2', abstract => 'Testing testing testing' },    
    ];

}

=head2 $self->get_datasets()

Get a list of all the available datasets.

=over

=item return

A reference to an array of hashreferences. Each hash reference contains the
information about of one dataset.

=back

=cut
sub get_datasets {
    my $self = shift;
    
    return [
        { name => 'ice' },
        { name => 'hirlam12' },
        { name => 'iceam' },                
    ]

}

1;
