package Metamod::Search::FeedData;

use strict;
use warnings;

use DBI;
use Params::Validate qw( :all );
use Metamod::Config;

=head1 NAME

Metamod::Search::FeedData - API for accessing data necessary for the feeds.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 FUNCTIONS/METHODS

=head2 new

create a handle to the 

=cut
{
    my $singleton = bless {config => Metamod::Config->new()}, __PACKAGE__;
    sub new {
        return $singleton;
    }
}

=head2 $self->find_dataset( $name )

Search the database for a dataset

=over

=item $name

The unqualified name of the dataset, i.e. hirlam12 (not DAMOC/hirlam12

=item return 

Returns undef if the dataset cannot be found in the database. Otherwise it
returns a hashref with information about the dataset. Information is:
ds_id, ds_name, ds_parent, ds_status, ds_datestamp, ds_ownertag, ds_creationDate, ds_metadataFormat, ds_filePath

=back

=cut

sub find_dataset {
    my ($self, $ds_name) = @_;

    my @ownertags = $self->_get_ownertags;
    my $ownertag_placeholder = join ',', map {'?'} @ownertags; 

    my $dbh = $self->{config}->getDBH();
    my $sth = $dbh->prepare_cached(<< "EOT");
SELECT DS_id, DS_name, DS_parent, DS_status, DS_datestamp, DS_ownertag, DS_creationDate, DS_metadataFormat, DS_filePath
  FROM Dataset
 WHERE DS_name = ?
   AND DS_status = '1'
   AND DS_ownertag IN ($ownertag_placeholder)
EOT
    $sth->execute($ds_name, @ownertags);
    my $hashref = $sth->fetchrow_hashref();
    $sth->finish;
    
    return $hashref;
}

=head2 $self->get_files( NAMED_PARAMS )

Get the files (level2 datasets) associated with a dataset level 1.

=over

=item ds_id

The id of the dataset (level 1) to get the associated files for.

=item max_age (optional, default = 90)

The maximum age of a file if the number specified in C<max_files> is to large.

=item max_files (optional, default = 100)

The maximum number of files that can be of any age. If the number of files in
the dataset is larger than this, all files older than C<max_age> will be removed.

=item return

A date-ordered reference to an array of hash references. Each hashreference contains the
following information if available: 
ds_id, ds_name, ds_parent, ds_status, ds_datestamp, ds_ownertag, ds_creationDate, ds_metadataFormat, ds_filePath
title, abstract, dataref, datacollection_period, PI_name,
contact, bounding_box

=back

=cut
sub get_files {
    my $self = shift;

    my %parameters = validate( @_, { ds_id => 1, max_files => { default => 100, }, max_age => { default => 90 } } );

    my $dbh = $self->{config}->getDBH();
    my $dateSth = $dbh->prepare_cached(<<'EOT');
SELECT now() - interval ?
EOT
    $dateSth->execute($parameters{max_age} . " days");
    my ($cutOffDate) = $dateSth->fetchrow_array();
    $dateSth->finish;
    my $baseQuery = << 'EOT';
SELECT DS_id, DS_name, DS_parent, DS_status, DS_datestamp, DS_ownertag, DS_creationDate, DS_metadataFormat, DS_filePath 
  FROM Dataset 
 WHERE DS_parent = ? 
   AND DS_status = '1'
EOT
    my $newestSth = $dbh->prepare_cached($baseQuery . << 'EOT');
   AND DS_datestamp > ? 
ORDER BY DS_datestamp DESC
EOT
    $newestSth->execute($parameters{ds_id}, $cutOffDate);
    my $datasets = $newestSth->fetchall_arrayref;
    
    if (@$datasets < $parameters{max_files}) {
        # add more datasets until max_files
        my $limit = $parameters{max_files} - @$datasets;
        my $olderSth = $dbh->prepare_cached($baseQuery . <<'EOT');
   AND DS_datestamp <= ?
ORDER BY DS_datestamp DESC
 LIMIT ?
EOT
        $olderSth->execute($parameters{ds_id}, $cutOffDate, $limit);
        while (defined (my $row = $olderSth->fetchrow_hashref)) {
            push @$datasets, $row;
        }
    } 

    # read the metadata information for each dataset
    my $mdSth = $dbh->prepare_cached(<< 'EOT');
SELECT MT_name, MD_content
  FROM Metadata, DS_Has_MD
 WHERE DS_id = ?
   AND Metadata.MD_id = DS_HAS_MD.MD_id
   AND MT_name IN ('title', 'abstract', 'dataref', 'datacollection_period', 'PI_name', 'contact', 'bounding_box')
EOT
    foreach my $row (@$datasets) {
        $mdSth->execute($row->{ds_id});
        while (defined (my $mdRow = $mdSth->fetchrow_hashref)) {
            $row->{$mdRow->{mt_name}} = $mdRow->{md_content};
        }
    }
    return $datasets;

}

=head2 $self->get_level1_datasets()

Get a list of all the available datasets (level1, catalogs).

=over

=item return

A reference to an array of hashreferences. Each hash reference contains the
information about the dataset.

=back

=cut
sub get_level1_datasets {
    my $self = shift;
    
    my @ownertags = $self->_get_ownertags;
    my $ownertag_placeholder = join ',', map {'?'} @ownertags; 
    
    my $dbh = $self->{config}->getDBH();
    my $sth = $dbh->prepare_cached(<< "EOT");
SELECT DS_id, DS_name, DS_parent, DS_status, DS_datestamp, DS_ownertag, DS_creationDate, DS_metadataFormat, DS_filePath
  FROM Dataset
 WHERE DS_status = 1
   AND DS_parent = 0
   AND DS_ownertag IN ($ownertag_placeholder)
EOT
    $sth->execute(@ownertags);
    my @rows;
    while (defined (my $row = $sth->fetchrow_hashref)) {
        push @rows, $row;
    }
        
    return \@rows;

}

# small function to get a list of ownertags from config
sub _get_ownertags {
    my $self = shift;
    
    my @ownertags; 
    my $ownertags = $self->{config}->getVar('DATASET_TAGS');
    if (defined $ownertags) {
        # comma-separated string
        @ownertags = split /\s*,\s*/, $ownertags;
        # remove '' around tags
        @ownertags = map {s/^'//; s/'$//; $_} @ownertags;
    }
    return @ownertags;
}

1;
__END__

=head1 AUTHOR

Heiko Klein, E<lt>H.Klein@met.noE<gt>

=head1 SEE ALSO

L<Metamod::Config>

=cut

