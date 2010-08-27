package Metamod::DatasetDb;

=head1 NAME

Metamod::DatasetDb - API for accessing dataset from indexed database

=begin LICENCE

METAMOD - Web portal for metadata search and upload
Copyright (C) 2008 met.no

Contact information:
Norwegian Meteorological Institute
Box 43 Blindern
0313 OSLO
NORWAY

This file is part of METAMOD

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

=end LICENCE

=cut

use strict;
use warnings;

use DBI;
use Params::Validate qw();
use Metamod::Config;
use Log::Log4perl;

our $VERSION = do { my @r = (q$LastChangedRevision$ =~ /\d+/g); sprintf "0.%d", @r };
my $logger = Log::Log4perl::get_logger('metamod::common::Metamod::DatasetDb');

=head1 SYNOPSIS

  use Metamod::DatasetDb;
  my $db = new Metamod::DatasetDb;

  my $dsRef = $db->find_dataset('hirlam12');
  my $level2Ref = $db->get_level2_datasets(ds_id => $dsRef->{ds_id});
  my $metaRef = $db->get_metadata($dsRef->{ds_id}, ['title', 'PI_name']);

  my $dsList = $db->get_level1_datasets();

=head1 DESCRIPTION

Access active datasets in the indexed SQL database.
All function will die on (database) errors.

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
    my ($self, $name) = @_;

    my @ownertags = $self->_get_ownertags;
    my $ownertag_placeholder = join ',', map {'?'} @ownertags;

    my $dbh = $self->{config}->getDBH();
    my $sth = $dbh->prepare_cached(<< "EOT");
SELECT DS_id, DS_name, DS_parent, DS_status, DS_datestamp, DS_ownertag, DS_creationDate, DS_metadataFormat, DS_filePath
  FROM Dataset
 WHERE DS_name LIKE ?
   AND DS_status = '1'
   AND DS_ownertag IN ($ownertag_placeholder)
EOT
    $sth->execute('%/'.$name, @ownertags);
    my $hashref = $sth->fetchrow_hashref();
    $sth->finish;

    return $hashref;
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

=head2 $self->get_level2_datasets($ds_id)

Get an arrayref of all the available datasets level2
belonging to the dataset level1 id $ds_id

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

=back

=cut
sub get_level2_datasets {
    my $self = shift @_;

    my %parameters = Params::Validate::validate( @_, { ds_id => 1, max_files => { default => 100, }, max_age => { default => 90 } } );

    my $dbh = $self->{config}->getDBH();
    my $days = $parameters{max_age} + 0; # get into numeric presentation
    my ($cutOffDate) = $dbh->selectrow_array("SELECT now() - interval '$days days'");

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
    my $datasets = [];
    while (defined (my $row = $newestSth->fetchrow_hashref)) {
        push @$datasets, $row;
    }

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

    return $datasets;
}

=head2 $self->get_metadata( $ds_ids, \@metadata_names )

Get the files (level2 datasets) associated with a dataset level 1.

=over

=item ds_id

the id to get metadata for, might be scalar or array-ref

=item metadata_names

list of items to fetch metadata-values for, e.g.
title, abstract, dataref, datacollection_period, PI_name,
contact, bounding_box

=item return

an hashref (key ds_id) of hashrefs (key metadataname) of arrayrefs (metadata-values),
e.g. {$ds_id1 => {'title' => ["my title"], 'abstract' => ["my abstract"], 'variable' => ["snow", "ice"]}

All metadatanames-keys and arrayref-values are guaranteed to exist, so they might
be empty lists if the element does not exist in the database.

=back

=cut
sub get_metadata {
    my ($self, $ds_id, $md_names) = @_;

    my @ds_ids = ref $ds_id ? @$ds_id : ($ds_id); # expand $ds_id to list
    my $ds_id_placeholder = join ',', map {'?'} @ds_ids;
    my $md_names_placeholder = join ',', map {'?'} @$md_names;

    unless ($ds_id_placeholder && $md_names_placeholder) {
        $logger->logcroak("get_metadata called without ds_id (@ds_ids) or md_names (@$md_names)");
    }

    # prepare the return value to contain all ds_ids and md_names
    my %retVal;
    foreach my $ds_id (@ds_ids) {
        foreach my $md_name (@$md_names) {
            $retVal{$ds_id}{$md_name} = [];
        }
    }

    # read the metadata information for each dataset
    my $dbh = $self->{config}->getDBH;
    my $sth = $dbh->prepare_cached(<< "EOT");
SELECT DS_id, MT_name, MD_content
  FROM Metadata, DS_Has_MD
 WHERE DS_id IN ($ds_id_placeholder)
   AND Metadata.MD_id = DS_HAS_MD.MD_id
   AND MT_name IN ($md_names_placeholder)
EOT
    $sth->execute(@ds_ids, @$md_names);

    while (defined (my $row = $sth->fetchrow_hashref)) {
        push @{ $retVal{$row->{ds_id}}{$row->{mt_name}} }, $row->{md_content};
    }

    return \%retVal;
}



# small function to get a list of ownertags from config
sub _get_ownertags {
    my $self = shift;

    my @ownertags;
    my $ownertags = $self->{config}->get('DATASET_TAGS');
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
