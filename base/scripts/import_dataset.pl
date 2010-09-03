#!/usr/bin/perl -w
#
#----------------------------------------------------------------------------
#  METAMOD - Web portal for metadata search and upload
#
#  Copyright (C) 2008 met.no
#
#  Contact information:
#  Norwegian Meteorological Institute
#  Box 43 Blindern
#  0313 OSLO
#  NORWAY
#  email: egil.storen@met.no
#
#  This file is part of METAMOD
#
#  METAMOD is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  METAMOD is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with METAMOD; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#----------------------------------------------------------------------------
#
use strict;
use warnings;
use File::Spec;
use File::Find qw();
# small routine to get lib-directories relative to the installed file
sub getTargetDir {
    my ($finalDir) = @_;
    my ($vol, $dir, $file) = File::Spec->splitpath(__FILE__);
    $dir = $dir ? File::Spec->catdir($dir, "..") : File::Spec->updir();
    $dir = File::Spec->catdir($dir, $finalDir); 
    return File::Spec->catpath($vol, $dir, "");
}

use lib ('../../common/lib', getTargetDir('lib'), getTargetDir('scripts'), '.');

use Metamod::Dataset;
use Metamod::DatasetTransformer::ToISO19115 qw(foreignDataset2iso19115);
use Metamod::Config qw(:init_logger);
use Metamod::Utils qw();
use Data::Dumper;
use DBI;
use XML::LibXML::XPathContext;
use File::Spec qw();
use mmTtime;

my $config = new Metamod::Config();

#
#  Import datasets from XML files into the database.
#
#  With no command line arguments, this program will enter a loop
#  while monitoring a number of directories (@importdirs) where XML files are
#  found. As new XML files are created or updated in these directories,
#  they are imported into the database. The loop will continue as long as
#  you terminate the process.
#
#  With one command line argument, the program will import the XML file
#  given by this argument.
#

my $progress_report = $config->get("TEST_IMPORT_PROGRESS_REPORT");    # If == 1, prints what
                                                            # happens to stdout
my $sleeping_seconds = 600; # check every 10 minutes for new files
if ( $config->get('TEST_IMPORT_SPEEDUP') > 1 ) {
    $sleeping_seconds = 1; # don't wait in test-case
}
my $importdirs_string          = $config->get("IMPORTDIRS");
my @importdirs                 = split( /\n/, $importdirs_string );
my $path_to_import_updated     = $config->get("WEBRUN_DIRECTORY").'/import_updated';
my $path_to_import_updated_new = $config->get("WEBRUN_DIRECTORY").'/import_updated.new';
my $path_to_logfile            = $config->get("LOGFILE");

#
#  Check number of command line arguments
#
if ( scalar @ARGV > 2 ) {
    die "\nUsage:\n\n   Import single XML file:     $0 filename\n"
      . "   Import a directory:         $0 directory\n"
      . "   Infinite monitoring loop:   $0\n"
      . "   Infinite daemon monitor:    $0 logfile pidfile\n\n";
}
my $inputfile;
my $inputDir;
if ( @ARGV == 1 ) {
    if ( -f $ARGV[0] ) {
        $inputfile = $ARGV[0];
    }
    elsif ( -d $ARGV[0] ) {
        $inputDir = $ARGV[0];
    }
    else {
        die "Unknown inputfile or inputdir: $ARGV[0]\n";
    }
} elsif ( @ARGV == 2 ) {
    Metamod::Utils::daemonize($ARGV[0], $ARGV[1]);
}
our $SIG_TERM = 0;
sub sigterm {++$SIG_TERM;}
$SIG{TERM} = \&sigterm;

#
if ( defined($inputfile) ) {

    #
    #  Evaluate block to catch runtime errors
    #  (including "die()")
    #
    my $dbh = $config->getDBH();
    eval { &update_database($inputfile, $dbh); };

    #
    #  Check error string returned from eval
    #  If not empty, an error has occured
    #
    if ($@) {
        warn $@;
        $dbh->rollback or die $dbh->errstr;
        &write_to_log("$inputfile (single file) database error: $@");
    }
    else {
        $dbh->commit or die $dbh->errstr;
        &write_to_log("$inputfile successfully imported (single file)");
    }
}
elsif ( defined($inputDir) ) {
   process_directories(-1, $inputDir);
}
else {
    &process_xml_loop();
}

# ------------------------------------------------------------------
sub process_xml_loop {

    #
    #  Infinite loop that checks for new or modified XML files as long as
    #  SIG_TERM (standard kill, Ctrl-C) has not been called.
    #
    &write_to_log("Check for new datasets in @importdirs");
    while ( ! $SIG_TERM ) {

#    The file $path_to_import_updated was last modified in the previous
#    turn of this loop. All XML files that are modified later are candidates
#    for import in the current turn of the loop.
#    Get the modification time corresponding to the previous turn of the loop:
#
        my @status = stat($path_to_import_updated);
        if ( scalar @status == 0 ) {
            die "Could not stat $path_to_import_updated\n";
        }
        my $last_updated = $status[9];    # Seconds since the epoch
        my $checkTime = time();
        process_directories($last_updated, @importdirs);
        utime($checkTime, $checkTime, $path_to_import_updated)
            or die "Cannot touch $path_to_import_updated";
        # disconnect database before sleep
        $config->getDBH()->disconnect;
        sleep($sleeping_seconds);
    }

    #
    #     Subroutine call: write_to_log
    #
    &write_to_log("Check for new datasets stopped");
}

# callback function from File::Find for directories
sub processFoundFile {
    my ($last_updated) = @_;
    my $file = $File::Find::name;
    if ($file =~ /\.xm[ld]$/ and -f $file and (stat(_))[9] >= $last_updated) {
        print "      $file -accepted\n" if ($progress_report == 1);
        my $basename = substr $file, 0, length($file)-4; # remove .xm[ld]
        if ($file eq "$basename.xml" and -f "$basename.xmd" and (stat(_))[9] >= $last_updated) {
            # ignore .xml file, will be processed together with .xmd file            
        } else {
            # import to database
            my $dbh = $config->getDBH();
            eval { &update_database( $file, $dbh ); };
            if ($@) {
                $dbh->rollback or die $dbh->errstr;
                my $stm = $dbh->{"Statement"};
                &write_to_log("$file database error: $@\n   Statement: $stm");
            }
            else {
                $dbh->commit or die $dbh->errstr;
                &write_to_log("$basename successfully imported");
            }
        }
    } 
}

sub process_directories {
    my ($last_updated,@dirs) = @_;

    foreach my $xmldir (@dirs) {
        my $xmldir1          = $xmldir;
        $xmldir1 =~ s/^ *//g;
        $xmldir1 =~ s/ *$//g;
        my @files_to_consume;
        if ( -d $xmldir1 ) {
            # xm[ld] files newer than $last_updated
            File::Find::find({wanted => sub {processFoundFile($last_updated)},
                              no_chdir => 1},
                              $xmldir1);
        }
    }
}

# ------------------------------------------------------------------
sub write_to_log {

    #
    #     Split argument array into variables
    #
    my ($message) = @_;

    #
    #     Open file for writing
    #
    open( LOG, ">>$path_to_logfile" );

    #
    #     Find current time
    #
    my @timearr = localtime;
    my $year    = 1900 + $timearr[5];
    my $mon     = $timearr[4] + 1;      # 1-12
    my $mday    = $timearr[3];          # 1-31
    my $hour    = $timearr[2];          # 0-23
    my $min     = $timearr[1];          # 0-59

    #
    #     Create a string using printf-compatible format:
    #
    my $datetime =
      sprintf( '%04d-%02d-%02d %02d:%02d', $year, $mon, $mday, $hour, $min );
    print LOG "$datetime\n   $message\n";
    close(LOG);
}

# ------------------------------------------------------------------
sub update_database {
    my ($inputBaseFile, $dbh) = @_;

    #
    #  Read input XML file-pair:
    #
    my $ds = Metamod::Dataset->newFromFile($inputBaseFile);
    unless ($ds) {
        die "cannot initialize dataset for $inputBaseFile";
    }
    my %info = $ds->getInfo;

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
    );

    #
    #  Create the datestamp for the current date:
    #
    my @timearr   = localtime( mmTtime::ttime() );
    my $datestamp = sprintf( '%04d-%02d-%02d',
        1900 + $timearr[5],
        1 + $timearr[4],
        $timearr[3] );

    #
    #  Create hash with all existing basic keys in the database.
    #  The keys in this hash have the form: 'SC_id:BK_name' and
    #  the values are the corresponding 'BK_id's.
    #  The BK_name are used as lower case.
    #
    my %basickeys = ();
    my $stm       = $dbh->prepare_cached("SELECT BK_id,SC_id,BK_name FROM BasicKey");
    $stm->execute();
    while ( my @row = $stm->fetchrow_array ) {
        my $key = $row[1] . ':' . cleanContent($row[2]);
        $basickeys{$key} = $row[0];
    }

#
#  Create hash with existing metadata in the database that may be shared between
#  datasets. The keys in this hash have the form: 'MT_name:MD_content' with 
#  MD_content in lower-case and the values are the corresponding 'MD_id's.
#
    my %dbMetadata = ();
    $stm =
      $dbh->prepare_cached(
        "SELECT Metadata.MT_name,MD_content,MD_id FROM Metadata, MetadataType "
        . "WHERE Metadata.MT_name = MetadataType.MT_name AND "
        . "MetadataType.MT_share = TRUE" );
    $stm->execute();
    while ( my @row = $stm->fetchrow_array ) {
        my $key = $row[0] . ':' . cleanContent($row[1]);
        $dbMetadata{$key} = $row[2];
    }

#
#  Create hash with all MetadataTypes that prescribes sharing of common metadata
#  values between datasets.
#
    my %shared_metadatatypes = ();
    $stm =
      $dbh->prepare_cached("SELECT MT_name FROM MetadataType WHERE MT_share = TRUE");
    $stm->execute();
    while ( my @row = $stm->fetchrow_array ) {
        $shared_metadatatypes{ $row[0] } = 1;
    }

    #
    #  Create hash with the rest of the MetadataTypes (i.e. no sharing).
    #
    my %rest_metadatatypes = ();
    $stm =
      $dbh->prepare_cached("SELECT MT_name FROM MetadataType WHERE MT_share = FALSE");
      $stm->execute();
    while ( my @row = $stm->fetchrow_array ) {
        $rest_metadatatypes{ $row[0] } = 1;
    }

    {
        my %metadata = $ds->getMetadata;
        my $period_from;
        my $period_to;
        my @metaarray   = ();
        my @searcharray = ();
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
        
        my $sql_getIDByName_DS = $dbh->prepare_cached("SELECT DS_id FROM Dataset WHERE DS_name = ?");
        $sql_getIDByName_DS->execute( $info{name} );
        my $dsid;
        while ( my @row = $sql_getIDByName_DS->fetchrow_array ) {
            $dsid = $row[0];
        }
        if ( defined $dsid ) {
            # Delete existing dataset and corresponding GeographicalArea (if found).
            # This will cascade to BK_Describes_DS, GA_Describes_DS, GD_Ispartof_GA
            # and also DS_Has_MD:
            my $sql_delete_GA = $dbh->prepare_cached( "DELETE FROM GeographicalArea WHERE GA_id IN "
                                             . "(SELECT GA_id FROM GA_Describes_DS AS g, DataSet AS d WHERE "
                                             . "g.DS_id = d.DS_id AND (d.DS_id = ?))" );
            $sql_delete_GA->execute( $dsid );
            my $sql_delete_DS = $dbh->prepare_cached("DELETE FROM DataSet WHERE DS_id = ?");
            $sql_delete_DS->execute( $dsid );
        } else {
            my $sql_getkey_DS = $dbh->prepare_cached("SELECT nextval('DataSet_DS_id_seq')");            
            $sql_getkey_DS->execute();
            my @result = $sql_getkey_DS->fetchrow_array;
            $dsid = $result[0];
            $sql_getkey_DS->finish;
        }
        my $dsStatus = ( $info{status} eq 'active' ) ? 1 : 0;
        my $parentId = 0;
        my $parentName = $ds->getParentName;
        if ($parentName) {
            my $sql_getIDByNameAndParent_DS = $dbh->prepare_cached("SELECT DS_id FROM Dataset WHERE DS_name = ? AND DS_parent = ?");
            $sql_getIDByNameAndParent_DS->execute($parentName, 0);
            my @result = $sql_getIDByNameAndParent_DS->fetchrow_array;
            if (@result != 0) {
                $parentId = $result[0];
            } else {
                die "couldn't find parent for $info{name}: $parentName";
            }
            $sql_getIDByNameAndParent_DS->finish;
        }
        my $sql_insert_DS =  $dbh->prepare_cached(
            "INSERT INTO DataSet (DS_id, DS_name, DS_parent, DS_status, DS_datestamp, DS_ownertag, DS_creationDate, DS_metadataFormat, DS_filePath)"
          . " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)" );
        $sql_insert_DS->execute(
            $dsid,               $info{name},
            $parentId,           $dsStatus,
            $datestamp,          $info{ownertag},
            $info{creationDate}, $info{metadataFormat},
            File::Spec->rel2abs($inputBaseFile)
        );

        if ($dsStatus) {
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
            foreach my $mref (@metaarray) {
                my $mtname = $mref->[0];
                my $mdcontent = $mref->[1];
                my $mdid;
                if ( exists( $shared_metadatatypes{$mtname} ) ) {
                    my $mdkey = $mtname . ':' . cleanContent($mdcontent);
                    if ( $progress_report >= 1 ) {
                        print "mdkey: " . $mdkey . "\n";
                    }
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
                        write_to_log("duplicate metadata: $mdkey");
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
                if ( exists( $searchcategories{$mtname} ) ) {
                    my $skey = $searchcategories{$mtname} . ':' . cleanContent($mdcontent);
                    if ( $progress_report == 1 ) {
                        print "Insert searchdata. Try: '$skey'\n";
                    }
                    if ( exists( $basickeys{$skey} ) ) {
                        my $bkid = $basickeys{$skey};
                        $sql_selectCount_BKDS->execute( $bkid, $dsid);
                        my $count = $sql_selectCount_BKDS->fetchall_arrayref()->[0][0];
                        if ( $count == 0 ) {
                            $sql_insert_BKDS->execute( $bkid, $dsid );
                        } else {
                            write_to_log("duplicate basic key: $skey");
                        }
                        if ( $progress_report == 1 ) {
                            print " -OK: $bkid,$dsid\n";
                        }
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

        #
        #   Insert quadtree nodes:
        #
        {
            my @quadtreenodes = $ds->getQuadtree;
            if ( @quadtreenodes > 0 ) {
                my $sql_getkey_GA = $dbh->prepare_cached("SELECT nextval('GeographicalArea_GA_id_seq')");
                my $sql_insert_GA = $dbh->prepare_cached("INSERT INTO GeographicalArea (GA_id) VALUES (?)");
                my $sql_insert_GAGD = $dbh->prepare_cached("INSERT INTO GA_Contains_GD (GA_id, GD_id) VALUES (?, ?)");
                
                $sql_getkey_GA->execute();
                my @result = $sql_getkey_GA->fetchrow_array;
                my $gaid   = $result[0];
                $sql_getkey_GA->finish;
                $sql_insert_GA->execute($gaid);
                foreach my $node (@quadtreenodes) {
                    if ( length($node) > 0 ) {
                        $sql_insert_GAGD->execute( $gaid, $node );
                    }
                }
            my $sql_insert_GADS = $dbh->prepare_cached("INSERT INTO GA_Describes_DS (GA_id, DS_id) VALUES (?, ?)");
                $sql_insert_GADS->execute( $gaid, $dsid );
            }
        }
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
                my $regionValues = join ',', map {'ST_TRANSFORM(ST_GeomFromText(?,'.$config->get('LONLAT_SRID')."), $_)"} @regions;
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
        
        #
        #   Insert new projectionInformation
        #
        
        my $sql_delete_ProjectionInfo = $dbh->prepare_cached("DELETE FROM ProjectionInfo WHERE DS_id = ?");
        
        $sql_delete_ProjectionInfo->execute($dsid);
        my $projectionInfo = $ds->getProjectionInfo;
        if ($projectionInfo) {
            my $sql_insert_ProjectionInfo = $dbh->prepare_cached("INSERT INTO ProjectionInfo (DS_id, PI_content) VALUES (?, ?)");
            $sql_insert_ProjectionInfo->execute($dsid, $projectionInfo);
        }

        #
        #   Insert new wmsInformation
        #
        my $sql_delete_WMSInfo = $dbh->prepare_cached("DELETE FROM WMSInfo WHERE DS_id = ?");
        $sql_delete_WMSInfo->execute($dsid);
        my $wmsInfo = $ds->getWMSInfo;
        if (exists($info{wmsxml})) {
            my $wmsxml = $info{wmsxml};
            my $sql_insert_WMSInfo = $dbh->prepare_cached("INSERT INTO WMSInfo (DS_id, WI_content) VALUES (?, ?)");
            $sql_insert_WMSInfo->execute($dsid, $wmsxml);
        } elsif ($wmsInfo) {
            my $sql_insert_WMSInfo = $dbh->prepare_cached("INSERT INTO WMSInfo (DS_id, WI_content) VALUES (?, ?)");
            $sql_insert_WMSInfo->execute($dsid, $wmsInfo);
        } else {
           print "No wmsxml\n";
        }
        updateSru2Jdbc($ds, $dsid, $inputBaseFile);
    }
}

{
    my $ownertags;
    sub _get_sru_ownertags {
        unless ($ownertags) {
            my $sru2jdbc_tags = $config->get('SRU2JDBC_TAGS');
            %{ $ownertags } = map {cleanContent($_) => 1} map {s/'//g; $_} split (',', $sru2jdbc_tags);
        }
        return $ownertags;
    }
}

sub updateSru2Jdbc {
    my ($ds, $dsid, $inputBaseFile) = @_;
    my $ownertag = _get_sru_ownertags();
    my $dbh = $config->getDBH();
    my %info = $ds->getInfo();
    if ($ownertag->{cleanContent($info{ownertag})} and not $ds->getParentName()) {
        print "running updateSru2Jdbc on $info{name}\n" if $progress_report == 1;
        # ownertag matches and not a child (no parent)
        # delete existing metadata
        my $deleteSth = $dbh->prepare_cached('DELETE FROM sru.products where id_product = ?');
        $deleteSth->execute($dsid);
        # check status
        if ($info{status} eq 'active') {
            # convert to ISO19115 by reading original format from disk
            my $fds = Metamod::ForeignDataset->newFromFileAutocomplete($inputBaseFile);
            eval {
                $fds = foreignDataset2iso19115($fds);
                isoDoc2SruDb($fds);
            }; if ($@) {
                write_to_log("problems converting to iso19115 and adding to sru-db: $@");
            }
        }
    } else {
        if ( $progress_report == 1 ) {
            print "not including sru-searchdata for $info{name}, $info{ownertag}\n";
        }
    }
}

# read a parsed iso19115 libxml document
# and put it into the sru database 
sub isoDoc2SruDb {
    my ($isods) = @_;
    my %info = $isods->getInfo;
    return unless $info{status} eq 'active';
        
    # find elements
    my $xpc = XML::LibXML::XPathContext->new();
    $xpc->registerNs('gmd', 'http://www.isotc211.org/2005/gmd');
    $xpc->registerNs('d', 'http://www.met.no/schema/metamod/dataset');
        
    my (@params, @values);
    push @params, "dataset_name";
    push @values, $info{name};

    push @params, "ownertag";
    push @values, uc($info{ownertag});
    
    push @params, "created";
    push @values, $info{creationDate};
    
    push @params, "updated";
    push @values, $info{datestamp};
    
    push @params, "metaxml";
    push @values, $isods->getMETA_XML();
    
    push @params, "metatext";
    push @values, $isods->getMETA_DOC()->textContent();

    push @params, "title";
    push @values, uc(scalar _get_text_from_doc($isods->getMETA_DOC(), '//gmd:title', $xpc));

    push @params, "abstract";
    push @values, uc(scalar _get_text_from_doc($isods->getMETA_DOC(), '//gmd:abstract', $xpc));

    push @params, "subject";
    push @values, uc(scalar _get_text_from_doc($isods->getMETA_DOC(), '//gmd:subject', $xpc)); # TODO: does this exist?
    
    push @params, "search_strings";
    push @values, uc(scalar _get_text_from_doc($isods->getMETA_DOC(), '//gmd:keyword', $xpc)); # TODO: word separator?
    
    # TODO, not in document yet ???
    #push @params, "begin_date";
    #push @values, uc(scalar _get_text_from_doc($isods->getMETA_DOC(), '//gmd:XXXX', $xpc));
    
    # TODO, not in document yet ???
    #push @params, "end_date";
    #push @values, uc(scalar _get_text_from_doc($isods->getMETA_DOC(), '//gmd:XXXX', $xpc));

    push @params, "west";
    push @values, min(_get_text_from_doc($isods->getMETA_DOC(), '//gmd:westBoundLongitude', $xpc));
    push @params, "east";
    push @values, max(_get_text_from_doc($isods->getMETA_DOC(), '//gmd:eastBoundLongitude', $xpc));
    push @params, "south";
    push @values, min(_get_text_from_doc($isods->getMETA_DOC(), '//gmd:southBoundLatitude', $xpc));
    push @params, "north";
    push @values, max(_get_text_from_doc($isods->getMETA_DOC(), '//gmd:northBoundLatitude', $xpc));

    # TODO: id_contact parameter

    # insert into db
    if ( $progress_report == 1 ) {
        print "Insert sru-searchdata...";
    }
    my $paramNames = join ', ', @params;
    my $placeholder = join ', ', map {'?'} @values;
    my $sth = $config->getDBH()->prepare_cached(<<"SQL");
INSERT INTO sru.products ( $paramNames ) VALUES ( $placeholder )
SQL
    $sth->execute(@values);
    if ( $progress_report == 1 ) {
        print "Ok\n";
    }

}


# get the minimum of a list of values
sub min {
    my $val = shift;
    foreach my $vn (@_) {
        if ($val > $vn) {
            $val = $vn;
        } 
    }
    return $val;
}

# get the maximum of a list of values
sub max {
    my $val = shift;
    foreach my $vn (@_) {
        if ($val < $vn) {
            $val = $vn;
        } 
    }
    return $val;
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

sub cleanContent {
    my ($content) = @_;
    # trim
    $content =~ s/(^\s+|\s+$)//go;
    # convert several spaces to one space
    $content =~ s/\s+/ /go;
    return lc($content); 
}
