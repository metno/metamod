package Test::PerformanceRegression;

use strict;
use warnings;

=head1 NAME

Test::PerformanceRegression - Test::Builder based module for doing regression testing of performance.

=head1 SYNOPSIS

 my $perf = Test::PerformanceRegression->new();
 
 my $sub_to_perf_test = sub { my $result = run_some_code() };
  
 my $check_of_result = sub { my (@result) = @_; #is result as expected };
 
 # check that a single run of the function has ok performance.
 perf_ok($sub_to_perf, $check_of_result, 'A unique tag for the test');
 
 # run the sub enough times that we a statistically certain that we have achieved a the real
 # mean runtime for the sub and then check if the performance is ok.
 statistic_perf_ok

=head1 DESCRIPTION

This module provides functionality for doing regression test of performance. It is built using
Test::Builder so it is compatible with the standard Perl testing libraries.

The purpose of this module is B<NOT> to measure the actual performance of a piece of code, but
instead to ensure that a change does not introduce reduced performance without it being reported
to the developer. 

Since running times can vary greatly between different machines and it can be difficult to 
measure the speed of some code against a fixed number. For this reason this module will instead
compare the current performance against a previous performance on the same machine. The first time
a performance test is run for a piece of code it will be stored in a file. On later runs the 
performance will be compared with the stored version.

If you want to update all the performance benchmarks for a test script you can just delete the 
file containing the cached performance results.

=head1 FUNCTIONS/METHODS

=cut

use Benchmark::Timer;
use Data::Dumper;
use JSON::Any;
use Test::Builder;
use Time::HiRes qw( gettimeofday tv_interval );

my $tester = Test::Builder->new();

sub new {
    my ( $class, $options ) = @_;

    my $self = bless {}, $class;
    
    my $accepted_error = $options->{ accepted_error } || 10;
    $self->accepted_error($accepted_error);
    my $statistic_error = $options->{ statistic_error } || 10;    
    $self->statistic_error($statistic_error);
    my $statistict_confidence = $options->{ statistic_confidence } || 95;
    $self->statistic_confidence($statistict_confidence);
    my $statistic_minimum = $options->{sdf};
    $self->statistic_minimum(5);
    $self->{_result_file} = $self->_default_filename();

    $self->{_previous_result} = $self->_read_result( $self->{_result_file} );

    $self->{_new_result} = {};

    return $self;

}

sub accepted_error {
    my $self = shift;

    if ( defined $_[0] ) {
        $self->{_accepted_error} = shift;
    }
    return $self->{_accepted_error};
}

sub statistic_error {
    my $self = shift;

    if ( defined $_[0] ) {
        $self->{_statistic_error} = shift;
    }
    return $self->{_statistic_error};
}

sub statistic_confidence {
    my $self = shift;

    if ( defined $_[0] ) {
        $self->{_statistic_confidence} = shift;
    }
    return $self->{_statistic_confidence};
}

sub statistic_minimum {
    my $self = shift;

    if ( defined $_[0] ) {
        $self->{_statistic_minimum} = shift;
    }
    return $self->{_statistic_minimum};
}

=head2 $self->perf_ok($code, $pre_test, $tag, $testname)

Check the performance of a sub by running it once, optionally performing an additional
test first about the correctness of the result returned by the sub.

If the previous running time of the sub has not been recorded the test will be skipped, but
the sub will still be run and the running time recorded for the next time the test is run.

=item $code

A reference to the sub to execute.

=item $pre_test

Either a reference to sub to be execute or a value that will be tested for true/false.

If a reference to sub is supplied the sub will be executed and the return value used to determine
if the test should be performed.

If the return value is false or the supplied value is false the test will be skipped using the
Test::Builder->skip() function.

=item $tag

A tag that is used to identify the current test. This tag must be unique within the test
script since it is used to compare the running time of the sub with the previous running times.

=item $testname (optional)

The name of the test. If not supplied a default test name based on the C<$tag> will be created
for you.

=item return

Returns false if the test was not run either because $pre_test failed, because a previous
running time was available or because the test failed. Otherwise it returns 1.


=cut

sub perf_ok {
    my $self = shift;

    my ( $code, $pre_test, $tag, $testname ) = @_;

    my $before = [gettimeofday];
    my @result = $code->();
    my $after  = [gettimeofday];

    my $pre_test_success = $self->_run_pre_test( $pre_test, @result );

    if ( !$pre_test_success ) {
        $tester->skip('Result of pre tests failed. No reason to check performance');
        return;
    }

    my $performance = tv_interval( $before, $after );
    return $self->_test_perf( $performance, $tag, $testname );

}

=head2 $self->statistic_perf_ok($code, $pre_test, $tag, $testname)

Check the performance of a sub by running it enough times that we are certain that the recorded
running time is within a margin of error of the real running time. Optionally performing an 
additional test first about the correctness of the result returned by the sub.

If the previous running time of the sub has not been recorded the test will be skipped, but
the sub will still be run and the running time recorded for the next time the test is run.

=item $code

A reference to the sub to execute.

=item $pre_test

Either a reference to sub to be execute or a value that will be tested for true/false.

If a reference to sub is supplied the sub will be executed and the return value used to determine
if the test should be performed.

If the return value is false or the supplied value is false the test will be skipped using the
Test::Builder->skip() function.

=item $tag

A tag that is used to identify the current test. This tag must be unique within the test
script since it is used to compare the running time of the sub with the previous running times.

=item $testname (optional)

The name of the test. If not supplied a default test name based on the C<$tag> will be created
for you.

=item return

Returns false if the test was not run either because $pre_test failed, because a previous
running time was available or because the test failed. Otherwise it returns 1.

=cut

sub statistic_perf_ok {
    my $self = shift;

    my ( $code, $pre_test, $tag, $testname ) = @_;

    my $timer = Benchmark::Timer->new(
        confidence => $self->statistic_confidence(),
        error      => $self->statistic_error(),
        minimum    => $self->statistic_minimum(),
    );

    my $pre_test_success;
    while ( $timer->need_more_samples($tag) ) {
        $timer->start($tag);
        my @result = $code->();
        $timer->stop($tag);

        # on the first run it will be undefined. At later stages it will either be defined
        # or the loop terminated
        if ( !defined $pre_test_success ) {
            $pre_test_success = $self->_run_pre_test( $pre_test, @result );

            if ( !$pre_test_success ) {
                last;
            }
        }
    }

    if ( !$pre_test_success ) {
        $tester->skip('Result of pre tests failed. No reason to check performance');
        return;
    }

    my $performance = $timer->result($tag);
    return $self->_test_perf( $performance, $tag, $testname );

}

sub _test_perf {
    my $self = shift;

    my ( $performance, $tag, $testname ) = @_;

    if ( !defined $testname ) {
        $testname = "Performance of $tag";
    }

    $self->{_new_result}->{$tag} = $performance;
    my $accepted_performance = $self->_accepted_performance($tag);

    if ( !defined $accepted_performance ) {
        $tester->skip('Have no previous performance result');
        return;
    }

    return $tester->cmp_ok( $performance, '<=', $accepted_performance, $testname );

}

sub _run_pre_test {
    my $self = shift;

    my ( $pre_test, @pre_test_args ) = @_;

    my $pre_test_success;
    if ( ref($pre_test) eq 'CODE' ) {
        $pre_test_success = $pre_test->(@pre_test_args);
    } else {
        $pre_test_success = $pre_test;
    }

    return $pre_test_success;

}

sub _accepted_performance {
    my $self = shift;

    my ($tag) = @_;

    if ( !exists $self->{_previous_result}->{$tag} ) {
        return;
    }

    my $prev_result = $self->{_previous_result}->{$tag};
    my $accepted_performance = $prev_result * ( 1 + ( $self->accepted_error() / 100 ) );

    return $accepted_performance;

}

sub _default_filename {
    my $self = shift;

    my ( $volume, $directories, $filename ) = File::Spec->splitpath($0);
    my $path = File::Spec->catpath( $volume, $directories, "$filename-perf.log" );
    return $path;

}

sub _read_result {
    my $self = shift;

    my ($result_file) = @_;

    if ( -e $result_file ) {

        my $success = open my $FILE, '<', $result_file;
        if ( !$success ) {
            $self->_fatal_error("Failed to open '$result_file': $!");

        }

        my $result_string = do { local $/; <$FILE> };
        close $FILE;

        my $json         = JSON::Any->new();
        my $prev_results = $json->from_json($result_string);
        return $prev_results;

    } else {
        return {};
    }

}

sub _write_result {
    my $self = shift;

    my ($result_file) = @_;

    my $new_result    = $self->{_new_result};
    my $prev_result   = $self->{_previous_result};
    my $merged_result = $self->_update_result_tags( $prev_result, $new_result );

    # $merged_result will only add keys, not change them so if the number of keys are equal
    # no changes have been made
    if ( scalar keys %$merged_result == scalar keys %$prev_result ) {
        return;
    }

    #if the results are empty do not write to the file
    if ( 0 == keys %$new_result ) {
        return;
    }

    my $json        = JSON::Any->new();
    my $result_json = $json->to_json($new_result);

    my $success = open my $FILE, '>', $result_file;
    if ( !$success ) {
        $self->_fatal_error("Failed to open '$result_file': $!");
    }

    print $FILE $result_json;
    return 1;

}

sub _update_result_tags {
    my $self = shift;

    my ( $prev_result, $new_result ) = @_;

    # do a copy of the original result to prevent inplace changes the $prev_result argument
    my %merged_result = %$prev_result;
    while ( my ( $tag, $value ) = each %$new_result ) {
        next if exists $merged_result{$tag};

        $merged_result{$tag} = $value;
    }

    return \%merged_result;

}

sub _fatal_error {
    my $self = shift;

    my ($msg) = @_;

    $tester->skip_all( "Fatal error occured. Skipping tests: " . $msg);

}

sub DESTROY {
    my $self = shift;

    $self->_write_result( $self->{_result_file} );

}

1;
