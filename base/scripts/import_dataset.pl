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
use Metamod::Utils qw(findFiles);
use Metamod::Config;
use Data::Dumper;
use DBI;
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
#  Connect to PostgreSQL database:
#
my $dbname = $config->get("DATABASE_NAME");
my $user   = $config->get("PG_ADMIN_USER");
my $dbh =
  DBI->connect( "dbi:Pg:dbname=" . $dbname . " ". $config->get("PG_CONNECTSTRING_PERL"),
	$user, "" );

#
#  Use full transaction mode. The changes has to be committed or rolled back:
#
$dbh->{AutoCommit} = 0;
$dbh->{RaiseError} = 1;

#
#  Set up a conversion table (hash) for
#  converting characters >159 to HTML entities:
#
my %html_conversions = ();
for ( my $jnum = 160 ; $jnum < 256 ; $jnum++ ) {
	$html_conversions{ chr($jnum) } = '&#' . $jnum . ';';
}

#
if ( defined($inputfile) ) {

	#
	#  Evaluate block to catch runtime errors
	#  (including "die()")
	#
	eval { &update_database($inputfile); };

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
      utime($checkTime, $checkTime, $path_to_import_updated);
		sleep($sleeping_seconds);
	}

	#
	#     Subroutine call: write_to_log
	#
	&write_to_log("Check for new datasets stopped");
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
			@files_to_consume = findFiles( $xmldir1, sub {$_[0] =~ /\.xm[ld]$/;},
			                                         sub {(stat(_))[9] >= $last_updated;} );
         if ( $progress_report == 1 ) {
			   foreach my $file (@files_to_consume) {
					print "      $file -accepted\n";
				}
			}
		}

		#
		# generate a list of unique basenames,
		# i.e. file.xml and file.xmd will only processed once
		my %uniqueBaseFiles;
		@files_to_consume =
		  map { s^\.\w*$^^; $uniqueBaseFiles{$_}++ ? $_ : () } @files_to_consume;
		foreach my $xmlfile (@files_to_consume) {
			eval { &update_database( $xmlfile ); };
			if ($@) {
				$dbh->rollback or die $dbh->errstr;
				my $stm = $dbh->{"Statement"};
				&write_to_log("$xmlfile database error: $@\n   Statement: $stm");
			}
			else {
				$dbh->commit or die $dbh->errstr;
				&write_to_log("$xmlfile successfully imported");
			}
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
	my ($inputBaseFile) = @_;

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
	my $stm       = $dbh->prepare("SELECT BK_id,SC_id,BK_name FROM BasicKey");
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
	  $dbh->prepare(
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
	  $dbh->prepare("SELECT MT_name FROM MetadataType WHERE MT_share = TRUE");
	$stm->execute();
	while ( my @row = $stm->fetchrow_array ) {
		$shared_metadatatypes{ $row[0] } = 1;
	}

	#
	#  Create hash with the rest of the MetadataTypes (i.e. no sharing).
	#
	my %rest_metadatatypes = ();
	$stm =
	  $dbh->prepare("SELECT MT_name FROM MetadataType WHERE MT_share = FALSE");
	$stm->execute();
	while ( my @row = $stm->fetchrow_array ) {
		$rest_metadatatypes{ $row[0] } = 1;
	}

	#
	#  Prepare SQL statements for repeated use.
	#  Use "?" as placeholders in the SQL statements:
	#
	my $sql_getkey_DS = $dbh->prepare("SELECT nextval('DataSet_DS_id_seq')");
	my $sql_getkey_GA =
	  $dbh->prepare("SELECT nextval('GeographicalArea_GA_id_seq')");
	my $sql_getIDByNameAndParent_DS = $dbh->prepare("SELECT DS_id FROM Dataset WHERE DS_name = ? AND DS_parent = ?");
	my $sql_getIDByName_DS = $dbh->prepare("SELECT DS_id FROM Dataset WHERE DS_name = ?");
	my $sql_delete_DS =
	  $dbh->prepare("DELETE FROM DataSet WHERE DS_id = ?");
	my $sql_delete_GA =
	  $dbh->prepare( "DELETE FROM GeographicalArea WHERE GA_id IN "
		  . "(SELECT GA_id FROM GA_Describes_DS AS g, DataSet AS d WHERE "
		  . "g.DS_id = d.DS_id AND (d.DS_id = ?))" );
	my $sql_insert_DS =
	  $dbh->prepare(
"INSERT INTO DataSet (DS_id, DS_name, DS_parent, DS_status, DS_datestamp, DS_ownertag, DS_creationDate, DS_metadataFormat, DS_filePath)"
		  . " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)" );
    my $sql_insert_ProjectionInfo = $dbh->prepare("INSERT INTO ProjectionInfo (DS_id, PI_content) VALUES (?, ?)");
    my $sql_delete_ProjectionInfo = $dbh->prepare("DELETE FROM ProjectionInfo WHERE DS_id = ?");
    my $sql_insert_WMSInfo = $dbh->prepare("INSERT INTO WMSInfo (DS_id, WI_content) VALUES (?, ?)");
    my $sql_delete_WMSInfo = $dbh->prepare("DELETE FROM WMSInfo WHERE DS_id = ?");
	my $sql_insert_GA =
	  $dbh->prepare("INSERT INTO GeographicalArea (GA_id) VALUES (?)");
	my $sql_insert_BKDS =
	  $dbh->prepare("INSERT INTO BK_Describes_DS (BK_id, DS_id) VALUES (?, ?)");
	my $sql_selectCount_BKDS=
	  $dbh->prepare("SELECT COUNT(*) FROM BK_Describes_DS WHERE BK_id = ? AND DS_id = ?");
	my $sql_insert_NI =
	  $dbh->prepare(
"INSERT INTO NumberItem (SC_id, NI_from, NI_to, DS_id) VALUES (?, ?, ?, ?)"
	  );

	#
	my $sql_getkey_MD = $dbh->prepare("SELECT nextval('Metadata_MD_id_seq')");
	my $sql_insert_MD = $dbh->prepare(
		"INSERT INTO Metadata (MD_id, MT_name, MD_content) VALUES (?, ?, ?)");
	my $sql_selectCount_DSMD = $dbh->prepare(
		"SELECT COUNT(*) FROM DS_Has_MD WHERE DS_id = ? AND MD_id = ?");
	my $sql_insert_DSMD =
	  $dbh->prepare("INSERT INTO DS_Has_MD (DS_id, MD_id) VALUES (?, ?)");
	my $sql_insert_GAGD =
	  $dbh->prepare("INSERT INTO GA_Contains_GD (GA_id, GD_id) VALUES (?, ?)");
	my $sql_insert_GADS =
	  $dbh->prepare("INSERT INTO GA_Describes_DS (GA_id, DS_id) VALUES (?, ?)");
	{
		my %metadata      = $ds->getMetadata;
		my @quadtreenodes = $ds->getQuadtree;
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
			}
			elsif ( $name eq 'datacollection_period_from' ) {
				$period_from = $ref2->[0];
				if ( $period_from =~ /(\d\d\d\d-\d\d-\d\d)/ ) {
					$period_from =
					  $1;    # Remove HH:MM UTC originating from questionnaire data.
				}
				else {
					undef $period_from;
				}
			}
			elsif ( $name eq 'datacollection_period_to' ) {
				$period_to = $ref2->[0];
				if ( $period_to =~ /(\d\d\d\d-\d\d-\d\d)/ ) {
					$period_to =
					  $1;    # Remove HH:MM UTC originating from questionnaire data.
				}
				else {
					undef $period_to;
				}
			}
			elsif ( $name eq 'topic' ) {
				foreach my $topic (@$ref2) {
					my $variable = $topic . ' > HIDDEN';
					my $mref = [ 'variable', $variable ];
					push( @metaarray, $mref );
				}
			}
			elsif ( $name eq 'area' ) {
				foreach my $str1 (@$ref2) {
					my $area = $str1;
					$area =~ s/^.*>\s*//
					  ; # Remove upper components of hierarchical name originating from
					    # questionnaire data.
					my $mref = [ 'area', $area ];
					push( @metaarray, $mref );
				}
			}
			else {
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

		$sql_getIDByName_DS->execute( $info{name} );
		my $dsid;
		while ( my @row = $sql_getIDByName_DS->fetchrow_array ) {
			$dsid = $row[0];
		}
		if ( defined $dsid ) {

		 #
		 #  Delete existing dataset and corresponding GeographicalArea (if found).
		 #  This will cascade to BK_Describes_DS, GA_Describes_DS, GD_Ispartof_GA
		 #  and also DS_Has_MD:
		 #
			$sql_delete_GA->execute( $dsid );
			$sql_delete_DS->execute( $dsid );
		}
		else {
			$sql_getkey_DS->execute();
			my @result = $sql_getkey_DS->fetchrow_array;
			$dsid = $result[0];
		}
		my $dsStatus = ( $info{status} eq 'active' ) ? 1 : 0;
		my $parentId = 0;
		my $parentName = $ds->getParentName;
		if ($parentName) {
			$sql_getIDByNameAndParent_DS->execute($parentName, 0);
			my @result = $sql_getIDByNameAndParent_DS->fetchrow_array;
			if (@result != 0) {
				$parentId = $result[0];
			} else {
				die "couldn't find parent for $info{name}: $parentName";
			}
		}
		$sql_insert_DS->execute(
			$dsid,               $info{name},
			$parentId,           $dsStatus,
			$datestamp,          $info{ownertag},
			$info{creationDate}, $info{metadataFormat},
			File::Spec->rel2abs($inputBaseFile)
		);

		if ($dsStatus) {

			#
			#  Insert metadata:
			#  Metadata with metadata type name not in the database are ignored.
			#
			foreach my $mref (@metaarray) {
				my $mtname = $mref->[0];
				my $mdcontent =
				  &convert_to_htmlentities( $mref->[1], \%html_conversions );
				my $mdid;
				if ( exists( $shared_metadatatypes{$mtname} ) ) {
					my $mdkey = $mtname . ':' . cleanContent($mdcontent);
					if ( $progress_report >= 1 ) {
						print "mdkey: " . $mdkey . "\n";
					}
					if ( exists( $dbMetadata{$mdkey} ) ) {
						$mdid = $dbMetadata{$mdkey};
					}
					else {
						$sql_getkey_MD->execute();
						my @result = $sql_getkey_MD->fetchrow_array;
						$mdid = $result[0];
						$sql_insert_MD->execute( $mdid, $mtname, $mdcontent );
						$dbMetadata{$mdkey} = $mdid;
					}
					$sql_selectCount_DSMD->execute( $dsid, $mdid );
					my $count = $sql_selectCount_DSMD->fetchall_arrayref()->[0][0];
					if ( $count == 0 ) {
						$sql_insert_DSMD->execute( $dsid, $mdid );
					}
					else {
						write_to_log("duplicate metadata: $mdkey");
					}
				}
				elsif ( exists( $rest_metadatatypes{$mtname} ) ) {
					$sql_getkey_MD->execute();
					my @result = $sql_getkey_MD->fetchrow_array;
					$mdid = $result[0];
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
                        my $count = $sql_selectCount_DSMD->fetchall_arrayref()->[0][0];
                        if ( $count == 0 ) {
                            $sql_insert_BKDS->execute( $bkid, $dsid );
                        } else {
                            write_to_log("duplicate basic key: $skey");
                        }
						if ( $progress_report == 1 ) {
							print " -OK: $bkid,$dsid\n";
						}
					}
					elsif ( $mtname eq 'datacollection_period' ) {
						my $scid = $searchcategories{$mtname};
						if ( $mdcontent =~
/(\d{4,4})-(\d{2,2})-(\d{2,2}) to (\d{4,4})-(\d{2,2})-(\d{2,2})/
						  )
						{
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
		if ( @quadtreenodes > 0 ) {
			$sql_getkey_GA->execute();
			my @result = $sql_getkey_GA->fetchrow_array;
			my $gaid   = $result[0];
			$sql_insert_GA->execute($gaid);
			foreach my $node (@quadtreenodes) {
				if ( length($node) > 0 ) {
					$sql_insert_GAGD->execute( $gaid, $node );
				}
			}
			$sql_insert_GADS->execute( $gaid, $dsid );
		}
		
		#
		#   Insert new projectionInformation
		#
		$sql_delete_ProjectionInfo->execute($dsid);
		my $projectionInfo = $ds->getProjectionInfo;
		if ($projectionInfo) {
			$sql_insert_ProjectionInfo->execute($dsid, $projectionInfo);
		}

        #
        #   Insert new wmsInformation
        #
        $sql_delete_WMSInfo->execute($dsid);
        my $wmsInfo = $ds->getWMSInfo;
        if ($projectionInfo) {
            $sql_insert_WMSInfo->execute($dsid, $wmsInfo);
        }

	}
}

sub convert_to_htmlentities {
	my ( $str, $conversions ) = @_;
	my @contarr = split( //, $str );
	my $result = "";
	foreach my $ch1 (@contarr) {
		if ( exists( $conversions->{$ch1} ) ) {
			$result .= $conversions->{$ch1};
		}
		else {
			$result .= $ch1;
		}
	}
	return $result;
}

sub cleanContent {
	my ($content) = @_;
	# trim
	$content =~ s/^\s+//;
	$content =~ s/\s+$//;
	# convert several spaces to one space
	$content =~ s/\s+/ /;
	return lc($content); 
}
