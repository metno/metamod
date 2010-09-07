package Metamod::SubscriptionUtils;

use strict;
use warnings;

use base 'Exporter';
our @EXPORT_OK = qw( split_parent_name get_basename );

use Log::Log4perl qw( get_logger );

=head1 NAME

Metamod::SubscriptionUtils - Utility functions for Subscription modules.

=head1 FUNCTIONS/METHODS

=cut

my $logger = get_logger('metamod.subscription');

=head2 split_parent_name( $parent_name )

Split a dataset parent name as returned by C<getParentName()> into an
application id and a dataset name.

=item $parent_name

The parent name to split.

=item return

On success it returns the application id and dataset name. If $parent_name does
not have the expected format it returns (undef, undef).

=cut
sub split_parent_name {
    my ($parent_name) = @_;
    
    my ( $application_id, $ds_name, $rest ) = split '/', $parent_name;
    
    if( defined $rest ){
        $logger->warn( "'$ds_name' did not have valid format" );
        return ( undef, undef );
    }
    
    return ( $application_id, $ds_name ); 
}

=head2 get_basename( $ds_name )

Get the basename part of a full dataset name.  

=over

=item $ds_name

The name of the dataset on the form used in the metadata database. E.g DAMOC/hirlam12/hirlam1220100909

=item return

The basename part of the name. E.g hirlam1220100909.

=back

=cut
sub get_basename {
	my ( $ds_name ) = @_;   

    my $basename;
    if ( $ds_name =~ /^.+\/(.+)$/ ) {
        $basename = $1;
    } else {
        $logger->warn("Dataset name $ds_name does not have correct format");
    }

    return $basename;
}


1;