package Metamod::DatasetImporter;

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

use List::Util qw(max min);
use Log::Log4perl;
use Moose;
use Try::Tiny;
use Carp;

use Metamod::Dataset;
use Metamod::DatasetTransformer::ToISO19115;

=head1 NAME

Metamod::DatasetImporter - Module for importing dataset information into the metadata database.

=head1 SYNOPSIS

Blah blah blah FIXME

=head1 DESCRIPTION

Blah blah blah FIXME

=head1 FUNCTIONS/METHODS

Blah blah blah FIXME

=cut

has 'config' => ( is => 'ro', default => sub { Metamod::Config->instance() } );

has 'logger' => ( is => 'ro', default => sub { Log::Log4perl::get_logger('metamod::common::'.__PACKAGE__); } );

has 'ownertags' => ( is => 'rw', isa => 'HashRef' );

#
#  Hash with existing metadata in the database that may be shared between
#  datasets. The keys in this hash have the form: 'MT_name:MD_content' with
#  MD_content in lower-case and the values are the corresponding 'MD_id's.
#
has '_db_metadata' => ( is => 'ro', isa => 'HashRef', lazy => 1, builder => '_build__db_metadata' );

#
#  Hash with all MetadataTypes that prescribes sharing of common metadata
#  values between datasets.
#
has '_shared_metadatatypes' => ( is => 'ro', isa => 'HashRef', lazy => 1, builder => '_build__shared_metadatatypes' );

#
#  Hash with the rest of the MetadataTypes (i.e. no sharing).
#
has '_unshared_metadatatypes' => ( is => 'ro', isa => 'HashRef', lazy => 1, builder => '_build__unshared_metadatatypes' );

#
#  Hash with all existing basic keys in the database.
#  The keys in this hash have the form: 'SC_id:BK_name' and
#  the values are the corresponding 'BK_id's.
#  The BK_name are used as lower case.
#
has '_basickeys' => ( is => 'ro', isa => 'HashRef', lazy => 1, builder => '_build__basickeys' );


sub _build__db_metadata {
    my $self = shift;

    my $config = $self->config();
    my $dbh = $config->getDBH();

    my %dbMetadata = ();
    my $stm =
      $dbh->prepare_cached(
        "SELECT Metadata.MT_name,MD_content,MD_id FROM Metadata, MetadataType "
        . "WHERE Metadata.MT_name = MetadataType.MT_name AND "
        . "MetadataType.MT_share = TRUE" );
    $stm->execute();
    while ( my @row = $stm->fetchrow_array ) {
        my $key = $row[0] . ':' . $self->clean_content($row[1]);
        $dbMetadata{$key} = $row[2];
    }

    return \%dbMetadata;

}

sub _build__shared_metadatatypes {
    my $self = shift;

    my $config = $self->config();
    my $dbh = $config->getDBH();

    my %shared_metadatatypes = ();
    my $stm =
      $dbh->prepare_cached("SELECT MT_name FROM MetadataType WHERE MT_share = TRUE");
    $stm->execute();
    while ( my @row = $stm->fetchrow_array ) {
        $shared_metadatatypes{ $row[0] } = 1;
    }

    return \%shared_metadatatypes;
}

sub _build__unshared_metadatatypes {
    my $self = shift;

    my $config = $self->config();
    my $dbh = $config->getDBH();

    my %rest_metadatatypes = ();
    my $stm =
      $dbh->prepare_cached("SELECT MT_name FROM MetadataType WHERE MT_share = FALSE");
      $stm->execute();
    while ( my @row = $stm->fetchrow_array ) {
        $rest_metadatatypes{ $row[0] } = 1;
    }

    return \%rest_metadatatypes;

}

sub _build__basickeys {
    my $self = shift;

    my $config = $self->config();
    my $dbh = $config->getDBH();

    my %basickeys = ();
    my $stm       = $dbh->prepare_cached("SELECT BK_id,SC_id,BK_name FROM BasicKey");
    $stm->execute();
    while ( my @row = $stm->fetchrow_array ) {
        my $key = $row[1] . ':' . $self->clean_content($row[2]);
        $basickeys{$key} = $row[0];
    }

    return \%basickeys;

}

=head2 $self->write_to_database($inputBaseFile)

Write information about the database set to the index database.

=over

=item $inputBaseFile

The file name for the metadata file. The filename can be both with and without
the .xml and .xmd extension.

=item return

Returns 1 on success. Dies on failure, so must be eval-ed.

=back

=cut

sub write_to_database {
    my $self = shift;

    my ($inputBaseFile) = @_;

    my $config = $self->config();
    my $dbh = $config->getDBH();
    my $logger = $self->logger();

    #
    #  Read input XML file-pair:
    #
    my $ds = Metamod::Dataset->newFromFile($inputBaseFile);
    unless ($ds) {
        $logger->error("cannot initialize dataset for $inputBaseFile");
        #return;
        my $error_text =  Metamod::Dataset->getErrorText();
        $logger->error("Cannot initialize dataset for $inputBaseFile : $error_text");
        croak("Cannot initialize dataset for $inputBaseFile : $error_text");
    }

    # we turn of auto commit since we want to either update all or not update at all.
    my $previous_auto_commit = $dbh->{AutoCommit};
    $dbh->{AutoCommit} = 0;
    my $success = 0;

    try {

        my %info = $ds->getInfo;
        my $dsid = $self->_get_dsid($ds);
        $self->_remove_old_metadata($dsid);

        my $dsStatus = ( $info{status} eq 'active' ) ? 1 : 0;
        my $parentId = $self->_get_parent_id($ds);

        my $sql_insert_DS =  $dbh->prepare_cached(
            "INSERT INTO DataSet (DS_id, DS_name, DS_parent, DS_status, DS_datestamp, DS_ownertag, DS_creationDate, DS_metadataFormat, DS_filePath)"
          . " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)" );

        my $datestamp = $info{datestamp};
        if ( $config->get('TEST_IMPORT_SPEEDUP') > 1 ) {
            # testing, use artificial time
            my @timearr   = localtime( mmTtime::ttime() );
            $datestamp = sprintf( '%04d-%02d-%02dT%02d:%02d:%02dZ',
                                 1900 + $timearr[5],
                                 1 + $timearr[4],
                                 $timearr[3],
                                 $timearr[2],
                                 $timearr[1],
                                 $timearr[0] );
        }

        my $inputFileWithoutExtension = File::Spec->rel2abs($inputBaseFile);
        #print STDERR $inputFileWithoutExtension;
        $inputFileWithoutExtension =~ s/\.xm[ld]$//;
        $sql_insert_DS->execute(
            $dsid,               $info{name},
            $parentId,           $dsStatus,
            $datestamp,          $info{ownertag},
            $info{creationDate}, $info{metadataFormat},
            $inputFileWithoutExtension
        );

        if ($dsStatus) {
            $self->_insert_metadata($ds, $dsid);
        }

        $self->_update_geo_location($ds, $dsid);

        #
        #   Insert new projectionInformation
        #
        my $projectionInfo = $ds->getProjectionInfo;
        if ($projectionInfo) {
            my $sql_insert_ProjectionInfo = $dbh->prepare_cached("INSERT INTO ProjectionInfo (DS_id, PI_content) VALUES (?, ?)");
            $sql_insert_ProjectionInfo->execute($dsid, $projectionInfo);
        }

        #
        #   Insert new wmsInformation
        #
        my $wmsInfo = $ds->getWMSInfo;
        if (exists($info{wmsxml})) {
            my $wmsxml = $info{wmsxml};
            my $sql_insert_WMSInfo = $dbh->prepare_cached("INSERT INTO WMSInfo (DS_id, WI_content) VALUES (?, ?)");
            $sql_insert_WMSInfo->execute($dsid, $wmsxml);
        } elsif ($wmsInfo) {
            my $sql_insert_WMSInfo = $dbh->prepare_cached("INSERT INTO WMSInfo (DS_id, WI_content) VALUES (?, ?)");
            $sql_insert_WMSInfo->execute($dsid, $wmsInfo);
        } else {
           $logger->debug("No wmsxml");
        }
        $self->_updateExtraSearch($ds, $dsid, $inputBaseFile);


        # TODO: This code should be moved somewhere else.
        #    if( $config->get("USERBASE_NAME") && $ds->getParentName() && $activateSubscriptions ){
        #        my $subscription = Metamod::Subscription->new();
        #        my $num_subscribers = $subscription->activate_subscription_handlers($ds);
        #    }

        $dbh->commit;
        $dbh->{AutoCommit} = $previous_auto_commit;
        $success = 1;

    } catch {

        $logger->error("Failed to write information to database: $_");

        $dbh->rollback();
        $dbh->{AutoCommit} = $previous_auto_commit;
        $success = 0;
        croak("Failed to write information to database: $_");
    };

    if(!$success){
        return;
    }

    return $success;
}

sub _insert_metadata {
    my $self = shift;

    my ($ds, $dsid) = @_;

    my $dbh = $self->config->getDBH();
    my $logger = $self->logger();

    #
    #  Create hash mapping the correspondence between MetadataType name
    #  and SearchCategory
    #
    my %searchcategories = (
        variable              => 3,
        area                  => 2,
        activity_type         => 1,
        institution           => 7,
        datacollection_period => 8,
        operational_status    => 10,
        project_name          => 14,
    );

    #  Prepare SQL statements for repeated use.
    my $sql_getkey_MD = $dbh->prepare_cached("SELECT nextval('Metadata_MD_id_seq')");
    my $sql_insert_MD = $dbh->prepare_cached("INSERT INTO Metadata (MD_id, MT_name, MD_content) VALUES (?, ?, ?)");
    my $sql_insert_BKDS = $dbh->prepare_cached("INSERT INTO BK_Describes_DS (BK_id, DS_id) VALUES (?, ?)");
    my $sql_selectCount_BKDS= $dbh->prepare_cached("SELECT COUNT(*) FROM BK_Describes_DS WHERE BK_id = ? AND DS_id = ?");
    my $sql_insert_NI = $dbh->prepare_cached("INSERT INTO NumberItem (SC_id, NI_from, NI_to, DS_id) VALUES (?, ?, ?, ?)");
    my $sql_selectCount_DSMD = $dbh->prepare_cached("SELECT COUNT(*) FROM DS_Has_MD WHERE DS_id = ? AND MD_id = ?");
    my $sql_insert_DSMD = $dbh->prepare_cached("INSERT INTO DS_Has_MD (DS_id, MD_id) VALUES (?, ?)");

    #
    #  Insert metadata:
    #  Metadata with metadata type name not in the database are ignored.
    #

    $logger->debug("Inserting metadata for dataset #$dsid");
    my %dbMetadata = %{ $self->_db_metadata() };
    my %shared_metadatatypes = %{ $self->_shared_metadatatypes() };
    my %rest_metadatatypes = %{ $self->_unshared_metadatatypes() };

    my @metaarray = $self->_transform_metadata($ds);
    foreach my $mref (@metaarray) {
        my $mtname = $mref->[0];
        my $mdcontent = $mref->[1];
        my $mdid;
        if ( exists( $shared_metadatatypes{$mtname} ) ) {
            my $mdkey = $mtname . ':' . $self->clean_content($mdcontent);
            $logger->debug("mdkey: $mdkey");
            if ( exists( $dbMetadata{$mdkey} ) ) {
                $mdid = $dbMetadata{$mdkey};
            } else {
                $sql_getkey_MD->execute();
                my @result = $sql_getkey_MD->fetchrow_array;
                $mdid = $result[0];
                $sql_getkey_MD->finish;
                $sql_insert_MD->execute( $mdid, $mtname, $mdcontent );
                $dbMetadata{$mdkey} = $mdid;
            }
            $sql_selectCount_DSMD->execute( $dsid, $mdid );
            my $count = $sql_selectCount_DSMD->fetchall_arrayref()->[0][0];
            if ( $count == 0 ) {
                $sql_insert_DSMD->execute( $dsid, $mdid );
            } else {
                # duplicate key happens all the times, in particular when converting formats
                $logger->debug("duplicate metadata: $mdkey");
            }
        } elsif ( exists( $rest_metadatatypes{$mtname} ) ) {
            $sql_getkey_MD->execute();
            my @result = $sql_getkey_MD->fetchrow_array;
            $mdid = $result[0];
            $sql_getkey_MD->finish;
            $sql_insert_MD->execute( $mdid, $mtname, $mdcontent );
            $sql_insert_DSMD->execute( $dsid, $mdid );
        }

        #
        #  Insert searchdata:
        #
        my %basickeys = %{ $self->_basickeys };
        if ( exists( $searchcategories{$mtname} ) ) {
            my $skey = $searchcategories{$mtname} . ':' . $self->clean_content($mdcontent);
            $logger->debug("Insert searchdata. Try: '$skey'");
            if ( exists( $basickeys{$skey} ) ) {
                my $bkid = $basickeys{$skey};
                $sql_selectCount_BKDS->execute( $bkid, $dsid);
                my $count = $sql_selectCount_BKDS->fetchall_arrayref()->[0][0];
                if ( $count == 0 ) {
                    $sql_insert_BKDS->execute( $bkid, $dsid );
                } else {
                    # duplicate key happens all the times, in particular when converting formats
                    $logger->debug("duplicate basic key: '$skey'");
                }
                $logger->debug(" -OK: $bkid,$dsid");
            } elsif ( $mtname eq 'datacollection_period' ) {
                my $scid = $searchcategories{$mtname};
                if ( $mdcontent =~ /(\d{4,4})-(\d{2,2})-(\d{2,2}) to (\d{4,4})-(\d{2,2})-(\d{2,2})/ ) {
                    my $from = $1 . $2 . $3;
                    my $to   = $4 . $5 . $6;
                    $sql_insert_NI->execute( $scid, $from, $to, $dsid );
                }
            }
        }
    }


}

=head2 $self->_remove_old_metadata($dsid)

Remove metadata that is stored in the metabase and associated with a dsid.

=over

=item $dsid

The C<dsid> of the dataste.

=item return

Always 1. Throws and exception on database error.

=back

=cut
sub _remove_old_metadata {
    my $self = shift;

    my ($dsid) = @_;

    my $dbh = $self->config()->getDBH();

    # This will cascade to BK_Describes_DS and DS_Has_MD:
    my $sql_delete_DS = $dbh->prepare_cached("DELETE FROM DataSet WHERE DS_id = ?");
    $sql_delete_DS->execute( $dsid );

    my $sql_delete_ProjectionInfo = $dbh->prepare_cached("DELETE FROM ProjectionInfo WHERE DS_id = ?");
    $sql_delete_ProjectionInfo->execute($dsid);

    my $sql_delete_WMSInfo = $dbh->prepare_cached("DELETE FROM WMSInfo WHERE DS_id = ?");
    $sql_delete_WMSInfo->execute($dsid);

    return 1;

}

=head2 $self->_get_dsid($ds)

Get the <dsid> for the dataset or a new C<dsid> in case of first time import.

=over

=item $ds

A reference to the dataset object.

=item return

Returns either the current C<dsid> for the dataset or a new C<dsid> for new datasets.

=back

=cut
sub _get_dsid {
    my $self = shift;

    my ($ds) = @_;

    my $dbh = $self->config()->getDBH();

    my %info = $ds->getInfo();

    my $select_stmt = $dbh->prepare_cached("SELECT DS_id FROM Dataset WHERE DS_name = ?");
    $select_stmt->execute( $info{name} );
    my $dsid;
    while ( my @row = $select_stmt->fetchrow_array ) {
        $dsid = $row[0];
    }

    if ( !defined $dsid ) {

        my $next_id_stmt = $dbh->prepare_cached("SELECT nextval('DataSet_DS_id_seq')");
        $next_id_stmt->execute();
        my @result = $next_id_stmt->fetchrow_array;
        $dsid = $result[0];
        $next_id_stmt->finish;
    }

    return $dsid;

}


=head2 $self->_get_parent_id($ds)

Get the C<dsid> of the parent dataset if the dataset has a parent.

=over

=item $ds

A dataset object

=item return

Returns the C<dsid> if the parent dataset if the dataset has a parent. Returns
0 if the database does not have a parent.

=back

=cut
sub _get_parent_id {
    my $self = shift;

    my ($ds) = @_;

    my $dbh = $self->config()->getDBH();

    my $parent_id = 0;
    my $parent_name = $ds->getParentName;
    if ($parent_name) {
        my $stmt = $dbh->prepare_cached("SELECT DS_id FROM Dataset WHERE DS_name = ? AND DS_parent = ?");
        $stmt->execute($parent_name, 0);
        my @result = $stmt->fetchrow_array;
        if (@result != 0) {
            $parent_id = $result[0];
        } else {
            my %info = $ds->getInfo;
            die "couldn't find parent for $info{name}: $parent_name";
        }
        $stmt->finish;
    }

    return $parent_id;

}

=head2 $self->_transform_metadata($ds)

Transform the dataset metadata to a format understood by the database.

=over

=item $ds

A reference to a C<Metamod::ForeignDataset>

=item return

An array where all the values are tuples of the type [ <metadata name>, <value>]

=back

=cut
sub _transform_metadata {
    my $self = shift;

    my ($ds) = @_;

    my %info = $ds->getInfo;

    my %metadata = $ds->getMetadata;
    my $period_from;
    my $period_to;
    my @metaarray   = ();
    unless ( $info{name} ) {
        die "Dataset with no drpath/name";
    }

    foreach my $name ( keys %metadata ) {
        my $ref2 = $metadata{$name};
        if ( $name eq 'abstract' ) {
            my $mref = [ $name, $ref2->[0] ];
            push( @metaarray, $mref );
        } elsif ( $name eq 'datacollection_period_from' ) {
            $period_from = $ref2->[0];
            if ( $period_from =~ /(\d\d\d\d-\d\d-\d\d)/ ) {
                # Remove HH:MM UTC originating from questionnaire data.
                $period_from = $1;
            } else {
                undef $period_from;
            }
        } elsif ( $name eq 'datacollection_period_to' ) {
            $period_to = $ref2->[0];
            if ( $period_to =~ /(\d\d\d\d-\d\d-\d\d)/ ) {
                # Remove HH:MM UTC originating from questionnaire data.
                $period_to = $1;
            } else {
                undef $period_to;
            }
        } elsif ( $name eq 'topic' ) {
            foreach my $topic (@$ref2) {
                my $variable = $topic . ' > HIDDEN';
                my $mref = [ 'variable', $variable ];
                push( @metaarray, $mref );
            }
        } elsif ( $name eq 'area' ) {
            foreach my $str1 (@$ref2) {
                my $area = $str1;
                # Remove upper components of hierarchical name originating from
                # questionnaire data.
                $area =~ s/^.*>\s*//;

                my $mref = [ 'area', $area ];
                push( @metaarray, $mref );
            }
        } else {
            foreach my $str1 (@$ref2) {
                my $mref = [ $name, $str1 ];
                push( @metaarray, $mref );
            }
        }
    }
    if ( defined($period_from) && defined($period_to) ) {
        my $period = $period_from . ' to ' . $period_to;
        my $mref = [ 'datacollection_period', $period ];
        push( @metaarray, $mref );
    }

    return @metaarray;

}

sub _update_geo_location {
    my $self = shift;

    my ($ds, $dsid) = @_;

    my $config = $self->config();
    my $dbh = $config->getDBH();

    #
    #  Insert new geographical location (region)
    #
    my $sql_delete_Location = $dbh->prepare_cached("DELETE FROM Dataset_Location where DS_id = ?");
    $sql_delete_Location->execute($dsid);
    if (defined (my $region = $ds->getDatasetRegion)) {
        my @srids = split ' ', $config->get('SRID_ID_COLUMNS');
        my @regions;
        foreach my $srid (@srids) {
            my %sridBB;
            @sridBB{qw(north east south west)} =  split ' ', $config->get('SRID_NESW_BOUNDING_BOX_'.$srid);
            if (defined $sridBB{west}) {
                if ($region->overlapsBoundingBox(\%sridBB)) {
                    push @regions, $srid;
                }
            } else {
                # no bounding box defined for srid, use anyway
                push @regions, $srid;
            }
        }
        if (@regions) {
            my $regionColumns = join ',', map {"geom_$_"} @regions;
            my $lonlat = $config->get('LONLAT_SRID') or die "Missing config directive LONLAT_SRID";
            my $regionValues = join ',', map {"ST_TRANSFORM(ST_GeomFromText(?,$lonlat), $_)"} @regions;
            my $sql_insert_Location = $dbh->prepare_cached("INSERT INTO Dataset_Location (DS_id, $regionColumns) VALUES (?, $regionValues)");

            my $regionAdded = 0;
            foreach my $p ($region->getPolygons) {
                my $pString = $p->toProjectablePolygon->toWKT;
                if (length($pString) > 10  and length($pString) < 1_000_000) {
                    my $parCound = 0;
                    $sql_insert_Location->bind_param(++$parCound, $dsid);
                    foreach my $srid (@regions) {
                        $sql_insert_Location->bind_param(++$parCound, $pString);
                    }
                    $sql_insert_Location->execute();
                    $regionAdded++;
                }
            }
            my @points = $region->getPoints;
            if (@points) {
                my $pString = 'MULTIPOINT('. join(',', @points) . ')';
                if (length($pString) > 10 and length($pString) < 1_000_000) {
                    my $parCound = 0;
                    $sql_insert_Location->bind_param(++$parCound, $dsid);
                    foreach my $srid (@regions) {
                        $sql_insert_Location->bind_param(++$parCound, $pString);
                    }
                    $sql_insert_Location->execute();
                    $regionAdded++;
                }
                $regionAdded++;
            }
            if (!$regionAdded) {
                # trying to add boundingBox
                my %bb = $region->getBoundingBox;
                if (scalar keys %bb >= 4) {
                    my $polygon;
                    eval {
                        $polygon = Metamod::LonLatPolygon->new([$bb{west}, $bb{south}],
                                                               [$bb{west}, $bb{north}],
                                                               [$bb{east}, $bb{north}],
                                                               [$bb{east}, $bb{south}],
                                                               [$bb{west}, $bb{south}]);
                    }; if (!$@) { # ignore warnings/errors
                        my $pString = $polygon->toProjectablePolygon->toWKT;
                        my $parCound = 0;
                        $sql_insert_Location->bind_param(++$parCound, $dsid);
                        foreach my $srid (@regions) {
                            $sql_insert_Location->bind_param(++$parCound, $pString);
                        }
                        $sql_insert_Location->execute();
                        $regionAdded++;
                    }
                }
            }
        }
    }

}



sub _get_sru_ownertags {
    my $self = shift;

    unless ($self->ownertags) {
        my $sru2jdbc_tags = $self->config->get('SRU2JDBC_TAGS') or die "Missing config param SRU2JDBC_TAGS";
        my %ownertags = map {$self->clean_content($_) => 1} map {s/'//g; $_} split (',', $sru2jdbc_tags);
        $self->ownertags(\%ownertags);
    }
    return $self->ownertags;
}


sub _updateExtraSearch {
    my $self = shift;

    my ($ds, $dsid, $inputBaseFile) = @_;

    my $config = $self->config;
    my $dbh = $config->getDBH();

    # only main datasets (parents) included in extra-search
    if ($ds->getParentName()) {
        return;
    }

    # extra searches need ISO representation
    my $isoFds;
    my %info = $ds->getInfo();
    # convert to ISO19115 by reading original format from disk
    my $fds = Metamod::ForeignDataset->newFromFileAutocomplete($inputBaseFile);
    eval {
        my %options;
        if ($config->has('PMH_REPOSITORY_IDENTIFIER')) {
            $options{REPOSITORY_IDENTIFIER} = $config->get('PMH_REPOSITORY_IDENTIFIER');
        }
        $isoFds = Metamod::DatasetTransformer::ToISO19115::foreignDataset2iso19115($fds, \%options);
    }; if ($@) {
        $self->logger->warn("problems converting to iso19115 of $info{name}: $@\n");
    }
    $self->_updateSru2Jdbc($ds, $dsid, $inputBaseFile, $isoFds);
    $self->_updateOAIPMH($ds, $dsid, $inputBaseFile, $isoFds);
}

sub _updateOAIPMH {
    my $self = shift;

    my ($ds, $dsid, $inputBaseFile, $isoFds) = @_;

    my $config = $self->config;
    my $dbh = $config->getDBH();

    my $sth = $dbh->prepare_cached('SELECT OAI_identifier FROM OAIInfo WHERE DS_id = ?');
    $sth->execute($dsid);
    my $currentIdentifier;
    while (my $row = $sth->fetchrow_arrayref) {
        $currentIdentifier = $row->[0];
    }

    # get the new identifier
    my $newIdentifier;
    if ($config->has('PMH_SYNCHRONIZE_ISO_IDENTIFIER') && $config->get('PMH_SYNCHRONIZE_ISO_IDENTIFIER')) {
        if ($isoFds) {
            my $xpc = XML::LibXML::XPathContext->new();
            $xpc->registerNs('gmd', 'http://www.isotc211.org/2005/gmd');
            $newIdentifier = scalar $self->_get_text_from_doc($isoFds->getMETA_DOC(), '/gmd:MD_Metadata/gmd:fileIdentifier', $xpc);
        }
    } else {
        my $pmhIdentifier = $config->get('PMH_REPOSITORY_IDENTIFIER');
        my %info = $ds->getInfo();
        $newIdentifier = 'oai:'.$pmhIdentifier.':metamod/'.$info{name};
    }
    if ($currentIdentifier) {
        if ($newIdentifier) {
            if ($newIdentifier ne $currentIdentifier) {
                $self->logger->warn("changing oai-identifier from $currentIdentifier to $newIdentifier");
                my $sth = $dbh->prepare_cached('UPDATE OAIInfo SET OAI_identifier = ? WHERE DS_id = ?');
                $sth->execute($newIdentifier, $dsid);
            }
        }
    } else {
        if ($newIdentifier) {
            my $sth = $dbh->prepare_cached('INSERT INTO OAIInfo (OAI_identifier, DS_id) VALUES (?,?)');
            $sth->execute($newIdentifier, $dsid);
        }
    }
}

sub _updateSru2Jdbc {
    my $self = shift;

    my ($ds, $dsid, $inputBaseFile, $isoFds) = @_;

    my $config = $self->config;
    my $dbh = $config->getDBH();

    my $ownertag = $self->_get_sru_ownertags();
    my %info = $ds->getInfo();
    if ($ownertag->{$self->clean_content($info{ownertag})}) {
        $self->logger->debug("running updateSru2Jdbc on $info{name}");
        # ownertag matches and not a child (no parent)
        # delete existing metadata
        my $deleteSth = $dbh->prepare_cached('DELETE FROM sru.products where id_product = ?');
        $deleteSth->execute($dsid);
        # check status
        if ($isoFds and ($info{status} eq 'active')) {
            eval {
                $self->_isoDoc2SruDb($isoFds, $dsid);
            }; if ($@) {
                $self->logger->warn("problems adding to sru-db: $@");
            }
        }
    } else {
        $self->logger->debug("not including sru-searchdata for $info{name}, $info{ownertag}");
    }
}

# read a parsed iso19115 libxml document
# and put it into the sru database
sub _isoDoc2SruDb {
    my $self = shift;

    my ($isods, $dsid) = @_;

    my $dbh = $self->config->getDBH();

    my %info = $isods->getInfo;
    return unless $info{status} eq 'active';

    # find elements
    my $xpc = XML::LibXML::XPathContext->new();
    $xpc->registerNs('gmd', 'http://www.isotc211.org/2005/gmd');
    $xpc->registerNs('d', 'http://www.met.no/schema/metamod/dataset');

    my (@params, @values);

    push @params, "id_product";
    push @values, $dsid;

    push @params, "dataset_name";
    push @values, $info{name};

    push @params, "ownertag";
    push @values, uc($info{ownertag});

    push @params, "created";
    push @values, $info{creationDate};

    push @params, "updated";
    push @values, $info{datestamp};

    my $xml = $isods->getMETA_XML();
    $xml =~ s/<\?xml[^>]*>//g; # remove xml-processing strings
    push @params, "metaxml";
    push @values, $xml;

    push @params, "metatext";
    push @values, $isods->getMETA_DOC()->textContent();

    {
        no warnings 'uninitialized'; # stop bitching about uc(undef)

        $self->_build_params_values(\@params,\@values,"title",
            uc(scalar $self->_get_text_from_doc($isods->getMETA_DOC(), '//gmd:title', $xpc)));

        $self->_build_params_values(\@params,\@values,"abstract",
            uc(scalar $self->_get_text_from_doc($isods->getMETA_DOC(), '//gmd:abstract', $xpc)));

        $self->_build_params_values(\@params,\@values,"subject",
            uc(scalar $self->_get_text_from_doc($isods->getMETA_DOC(), '//gmd:subject', $xpc))); # TODO: does this exist?

        $self->_build_params_values(\@params,\@values,"search_strings",
            uc(scalar $self->_get_text_from_doc($isods->getMETA_DOC(), '//gmd:keyword', $xpc))); # TODO: word separator?

        # TODO, not in document yet ???
        #push @params, "begin_date";
        #push @values, uc(scalar $self->_get_text_from_doc($isods->getMETA_DOC(), '//gmd:XXXX', $xpc));

        # TODO, not in document yet ???
        #push @params, "end_date";
        #push @values, uc(scalar $self->_get_text_from_doc($isods->getMETA_DOC(), '//gmd:XXXX', $xpc));

        $self->_build_params_values(\@params,\@values,"west",
            min($self->_get_text_from_doc($isods->getMETA_DOC(), '//gmd:westBoundLongitude', $xpc)));
        $self->_build_params_values(\@params,\@values,"east",
            max($self->_get_text_from_doc($isods->getMETA_DOC(), '//gmd:eastBoundLongitude', $xpc)));
        $self->_build_params_values(\@params,\@values,"south",
            min($self->_get_text_from_doc($isods->getMETA_DOC(), '//gmd:southBoundLatitude', $xpc)));
        $self->_build_params_values(\@params,\@values,"north",
            max($self->_get_text_from_doc($isods->getMETA_DOC(), '//gmd:northBoundLatitude', $xpc)));

    }

    # id_contact parameter
    push @params, "id_contact";
    push @values, $self->_get_contact_id($dbh, $isods->getMETA_DOC(), $xpc);

    # insert into db
    $self->logger->debug("Trying to insert sru-searchdata");
    my $paramNames = join ', ', @params;
    my $placeholder = join ', ', map {'?'} @values;
    my $sth = $dbh->prepare_cached(<<"SQL");
INSERT INTO sru.products ( $paramNames ) VALUES ( $placeholder )
SQL
    $sth->execute(@values);
    $self->logger->debug("Inserted sru-searchdata");
}

# Add one param and value pair to the @params and @values arrays
# if the value is defined.
#
sub _build_params_values {
    my $self = shift;
    my ($params,$values,$newparam,$newvalue) = @_;
    if (defined $newvalue) {
       push @{$params}, $newparam;
       push @{$values}, $newvalue;
    }
}

#
# get the author and organization from the document
# and find an possibly existing contact_id in the database
# or create one
#
sub _get_contact_id {
    my $self = shift;

    my ($doc, $xpc) = @_;

    my $dbh = $self->config->getDBH();
    $dbh->{PrintError} = 1;

    # fetch author and org from document, publisher or principalInvestigator
    my $authorXP = '//gmd:pointOfContact/gmd:CI_ResponsibleParty[ gmd:role/gmd:CI_RoleCode[ @codeListValue="publisher" or @codeListValue="principalInvestigator" ] ]/gmd:individualName';
    my $author = $self->_get_text_from_doc($doc, $authorXP, $xpc);
    #$author =~ s/\s+$//; # suggest trim trailing spaces?
    my $orgXP = '//gmd:pointOfContact/gmd:CI_ResponsibleParty[ gmd:role/gmd:CI_RoleCode[ @codeListValue="publisher" or @codeListValue="principalInvestigator" ] ]/gmd:organisationName';
    my $organization = $self->_get_text_from_doc($doc, $orgXP, $xpc);
    my $org_as_str = $organization || '-';

    # TODO: get author from other places if other code-list is used

    $self->logger->debug("found contact-(author,organization)=($author,$org_as_str) in sru/iso19115");

    # search for existing author/organization
    ($author, $organization) =  map {defined $_ ? uc($_) : undef} ($author, $organization);
    my $authorSQL = defined $author ? "author = ?" : "author IS NULL";
    my $orgSQL = defined $organization ? "organization = ?" : "organization IS NULL";
    my $sth_search = $dbh->prepare_cached(<<"SQL");
SELECT id_contact
  FROM sru.meta_contact
 WHERE $authorSQL
   AND $orgSQL
SQL
    my @authorOrganization = map {defined $_ ? $_ : ()} ($author, $organization);
    $sth_search->execute(@authorOrganization) or $self->logger->error($sth_search->errstr);
    my $contact_id;
    while (my $row = $sth_search->fetchrow_arrayref) {
        $contact_id = $row->[0]; # max one row, schema enforces uniqueness
        $self->logger->debug("found contact_id for $author, $org_as_str: $contact_id");
    }
    return $contact_id if defined $contact_id;


    # insert new author/organization
    my $sth = $dbh->prepare_cached(<<"SQL");
INSERT INTO sru.meta_contact ( author, organization ) VALUES ( ?, ? )
SQL
    $sth->execute($author, $organization) or $self->logger->error($sth_search->errstr);
    $contact_id = $dbh->last_insert_id(undef, 'sru', 'meta_contact', undef);
    if (! defined $contact_id) {
        $self->logger->error("cannot determine contact id from database\n");
    }
    $sth->finish;
    return $contact_id;
}

#
# get all text-contents from a LibXML document
# paramas:
#    doc: xml document
#  xpath: search string
#    xpc: xpath context
# return:
#   list-context: list of text-contents
#   scalar: white-space joined context, or undef
sub _get_text_from_doc {
    my $self = shift;

    my ($doc, $xpath, $xpc) = @_;
    my @nodes = $xpc->findnodes($xpath, $doc);
    my @results;
    foreach my $node (@nodes) {
        push @results, $node->textContent;
    }

    if (wantarray) {
        return @results;
    } else {
        if (@results) {
            return join "\t", @results;
        } else {
            return undef;
        }
    }
}

sub clean_content {
    my $self = shift;

    my ($content) = @_;
    # trim
    $content =~ s/(^\s+|\s+$)//go;
    # convert several spaces to one space
    $content =~ s/\s+/ /go;
    return lc($content);
}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut
1;
