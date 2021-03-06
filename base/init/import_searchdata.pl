#!/usr/bin/perl -w

=begin LICENSE

METAMOD - Web portal for metadata search and upload

Copyright (C) 2008 met.no

Contact information:
Norwegian Meteorological Institute
Box 43 Blindern
0313 OSLO
NORWAY
email: egil.storen@met.no

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

=end LICENSE

------------ Importing searchdata:
DBD::Pg::st execute failed: ERROR:  insert or update on table "hierarchicalkey" violates foreign key constraint "hierarchicalkey_sc_id_fkey"
DETAIL:  Key (sc_id)=(4) is not present in table "searchcategory". at /home/geira/metamod/trunk/base/init/import_searchdata.pl line 357.
DBD::Pg::st execute failed: ERROR:  insert or update on table "hierarchicalkey" violates foreign key constraint "hierarchicalkey_sc_id_fkey"
DETAIL:  Key (sc_id)=(4) is not present in table "searchcategory". at /home/geira/metamod/trunk/base/init/import_searchdata.pl line 357.

=cut

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../common/lib";

use File::Spec;
use File::Basename;
use XML::Simple qw(:strict);
use mmTtime;
use Data::Dumper;
use DBI;
use Getopt::Long;
use Pod::Usage;
use Metamod::Config;

# global variables
use vars qw($dbh %searchdata @ancestors
    $sql_insert_SC $sql_getkey_BK $sql_insert_BK $sql_insert_MT
    $sql_getkey_HK $sql_insert_HK $sql_insert_HKBK
); #@logarr

my $config_file_or_dir;
GetOptions( 'config=s' => \$config_file_or_dir ) or pod2usage(1);

if ( !Metamod::Config->config_found($config_file_or_dir) ) {
    pod2usage(1);
}

my $config = new Metamod::Config($config_file_or_dir);
my $searchdataxml = $config->path_to_config_file( 'searchdata.xml', 'staticdata' );

#  Connect to PostgreSQL database:
my $dbname = $config->get("DATABASE_NAME");
my $user   = $config->get("PG_ADMIN_USER");
my $constr = $config->has("PG_CONNECTSTRING_PERL") ? $config->get("PG_CONNECTSTRING_PERL") : '';

$dbh = DBI->connect( "dbi:Pg:dbname=$dbname $constr", $user, "" );
#  Use full transaction mode. The changes has to be committed or rolled back:
$dbh->{AutoCommit} = 0;
$dbh->{RaiseError} = 1;

#  Initialize log array. This will be appended to the logfile at the end of a successful run.
#@logarr = ();

#  Evaluate block to catch runtime errors (including "die()")
my $exitcode = 0;
eval { &update_database; };

#  Check error string returned from eval
#  If not empty, an error has occured
if ($@) {
    warn $@;
    $exitcode = 2;
    $dbh->rollback or die $dbh->errstr;
    my @utctime   = gmtime( mmTtime::ttime() );
    my $year      = 1900 + $utctime[5];
    my $mon       = $utctime[4];                                           # 0-11
    my $mday      = $utctime[3];                                           # 1-31
    my $datestamp = sprintf( '%04d-%02d-%02d', $year, $mon + 1, $mday );
    print STDERR"========= $datestamp: Load static searchdata failed. Database rolled back =========\n$@";
} else {
    $dbh->commit or die $dbh->errstr;
    $dbh->disconnect or warn $dbh->errstr;
    print(STDERR "========= Load static searchdata finished =========\n" );
}

# Redicting here does not work. create_and_load_all.sh is already capturing stdout/stderr
# into a file with the same name in webrun, whereas this opens the file in the config directory!
# Better to print as normal and let create_and_load_all handle all logging
#open (LOG,">> create_and_load_all.out");
#foreach my $line (@logarr) {
#
#    #print LOG $line . "\n";
#    print $line . "\n";
#}
exit $exitcode;

# ------------------------------------------------------------------
sub update_database {
    #
    #  Convert XML file to a hash (using XML::Simple): [why? use XPath instead]
    #  First, read the whole XML file into the string variable $xmlcontent. Then
    #  substitute all occurences of '&' with '&amp;'. Otherwise, XML::Simple
    #  will decode all XML entities into their Latin-1 equivalents.
    #  [actually this makes it illegal XML and should be avoided]
    #  The XML entities should be preserved to avoid difficult-to-debug character
    #  conversions while the text is sent to the database and later retrieved.
    #  [one should never store escaped XML entities in a database (unless as a document)]
    #  [escaping is only part of XML syntax, when parsed into separate strings they will disappear]
    #
    unless ( -r $searchdataxml ) { die "Can not read from file: $searchdataxml\n"; }
    #
    #   open (XMLINPUT,$searchdataxml);
    #   undef $/;
    #   my $xmlcontent = <XMLINPUT>;
    #   $/ = "\n";
    #   close (XMLINPUT);
    #   $xmlcontent =~ s/&/&amp;/mg;
    my $xmlref = XMLin(
        $searchdataxml,
        KeyAttr => {
            sc     => "id",
            hkhead => "sc",
            hk     => "name",
            mt     => "name"
        },
        ForceArray => 1
    );
    $xmlref->{mt}->{dataset_name} = {
        share => 'FALSE',
        def   => 'Dataset name (automatically included)',
    };

    #print Dumper($xmlref);
    #die;
    #
    my @utctime   = gmtime( mmTtime::ttime() );
    my $year      = 1900 + $utctime[5];
    my $mon       = $utctime[4];                                           # 0-11
    my $mday      = $utctime[3];                                           # 1-31
    my $datestamp = sprintf( '%04d-%02d-%02d', $year, $mon + 1, $mday );
    print(STDERR "========== Load static search data. $datestamp ==========\n" );
    #
    #  Create hash with all static search data in the database:
    #
    %searchdata = ();
    @ancestors  = ();
    my $stm;
    $stm = $dbh->prepare("SELECT SC_id FROM SearchCategory");
    $stm->execute();
    while ( my @row = $stm->fetchrow_array ) {
        my $key1 = "SC:" . join( ":", @row );
        $searchdata{$key1} = 1;
    }
    $stm = $dbh->prepare("SELECT BK_id, SC_id, BK_name FROM BasicKey");
    $stm->execute();
    while ( my @row = $stm->fetchrow_array ) {
        my $bkid = shift(@row);
        my $key1 = "BK:" . join( ":", @row );
        $searchdata{$key1} = $bkid;
    }
    $stm = $dbh->prepare("SELECT HK_id, SC_id, HK_parent, HK_name FROM HierarchicalKey");
    $stm->execute();
    while ( my @row = $stm->fetchrow_array ) {
        my $hkid = shift(@row);
        my $key1 = "HK:" . join( ":", @row );
        $searchdata{$key1} = $hkid;
    }
    $stm = $dbh->prepare("SELECT MT_name FROM MetadataType");
    $stm->execute();
    while ( my @row = $stm->fetchrow_array ) {
        my $key1 = "MT:" . join( ":", @row );
        $searchdata{$key1} = 1;
    }
    $stm = $dbh->prepare("SELECT HK_id, BK_id FROM HK_Represents_BK");
    $stm->execute();
    while ( my @row = $stm->fetchrow_array ) {
        my $key1 = "HKBK:" . join( ":", @row );
        $searchdata{$key1} = 1;
    }

    #  Prepare SQL statements for repeated use.
    #  Use "?" as placeholders in the SQL statements:
    $sql_insert_SC =
        $dbh->prepare("INSERT INTO SearchCategory (SC_id, SC_idname, SC_type, SC_fnc) VALUES (?, ?, ?, ?)");
    $sql_getkey_BK = $dbh->prepare("SELECT nextval('BasicKey_BK_id_seq')");
    $sql_insert_BK = $dbh->prepare("INSERT INTO BasicKey (BK_id, SC_id, BK_name) VALUES (?, ?, ?)");
    $sql_insert_MT = $dbh->prepare("INSERT INTO MetadataType (MT_name, MT_share, MT_def) VALUES (?, ?, ?)");
    $sql_getkey_HK = $dbh->prepare("SELECT nextval('HierarchicalKey_HK_id_seq')");
    $sql_insert_HK = $dbh->prepare(
        "INSERT INTO HierarchicalKey (HK_id, HK_parent, SC_id, HK_level, HK_name) " . "VALUES (?, ?, ?, ?, ?)" );
    $sql_insert_HKBK = $dbh->prepare("INSERT INTO HK_Represents_BK (HK_id, BK_id) VALUES (?, ?)");
    #
    # Loop through a given level of tags
    # rooted in a hash reference $xmlref.
    # Each $ref1 is a new reference to HASH, ARRAY or SCALAR
    #
    #foreach my $key1 ( keys %$xmlref ) { # FIXME *** this will fail randomly if sc is not processed first! ***
    # ERROR - keys are returned in random order, so no guarantee that sc is processed before hk
    foreach my $key1 ( qw(mt sc hkhead bk) ) {

        my $ref1 = $xmlref->{$key1} or next; # skip if key not used in xml
        print STDERR "Processing <$key1> entries...\n";
        if ( $key1 eq "sc" ) {

            # Check if reference is a HASH
            if ( ref($ref1) ne "HASH" ) {
                die "$0: XML hash: Top level value (key 'sc') is not a hash reference\n";
            }

            # Loop through all SearchCategories in the XML file:
            foreach my $key2 ( keys %$ref1 ) {
                print STDERR "- SC SearchCategory: $key2\n";
                my $ref2 = $ref1->{$key2};

                # Execute prepared SQL statement
                # Each argument below replaces a "?" placeholder in the $sqlstatement:
                if ( ref($ref2) ne "HASH" ) {
                    die "$0: XML hash: sc element is not a hash reference\n";
                }
                if ( !exists( $searchdata{ "SC:" . $key2 } ) ) {
                    my $idname = $ref2->{"idname"};
                    my $type   = $ref2->{"type"};
                    my $fnc    = $ref2->{"fnc"};
                    $sql_insert_SC->execute( $key2, $idname, $type, $fnc );
                    $searchdata{ "SC:" . $key2 } = 1;
                    # print(STDERR "Added to SC: $key2,$type,$fnc\n");
                }
            }
        } elsif ( $key1 eq "hkhead" ) {

            # Check if reference is a HASH
            if ( ref($ref1) ne "HASH" ) {
                die "$0: XML hash: Top level value (key 'hkhead') is not a hash reference\n";
            }

            # Loop through a given level of tags
            foreach my $scid ( keys %$ref1 ) {
                print STDERR "- HK SearchCategory: $scid\n";
                my $ref2 = $ref1->{$scid};

                # Check if reference is a HASH
                if ( ref($ref2) ne "HASH" ) {
                    die "$0: XML hash: 'hkhead' element is not a hash reference\n";
                }
                if ( !exists( $ref2->{'hk'} ) ) {
                    die "$0: XML hash: 'hk' element not found in 'hkhead'\n";
                }
                my $ref3  = $ref2->{'hk'};
                my $level = 1;

                # Subroutine call: hkloop
                &hkloop( $level, $ref3, $scid, 0 );
            }

        } elsif ( $key1 eq "bk" ) {

            if ( ref($ref1) ne "ARRAY" ) {
                die "$0: XML hash: Top level value (key 'bk') is not an array reference\n";
            }

            # Loop through all 'bk' elements at the top XML level
            foreach my $ref2 (@$ref1) {
                local $Data::Dumper::Terse = 1;
                local $Data::Dumper::Indent  = 0;
                printf STDERR "- BK: %s\n", Dumper $ref2;
                if ( ref($ref2) ne "HASH" ) {
                    die "$0: XML hash: Error in 'bk' element at the top XML level\n";
                }
                my $name = $ref2->{'content'};
                my $scid = $ref2->{'sc'};
                if ( !exists( $searchdata{ "BK:" . $scid . ":" . $name } ) ) {
                    # Get new primary key ($bkid) and insert into the BasicKey table:
                    $sql_getkey_BK->execute();
                    my @result = $sql_getkey_BK->fetchrow_array;
                    my $bkid   = $result[0];
                    $sql_getkey_BK->finish();
                    #print(STDERR "Adding to BK: $bkid,$scid,$name\n" );
                    $sql_insert_BK->execute( $bkid, $scid, $name );
                    $searchdata{ "BK:" . $scid . ":" . $name } = $bkid;
                }
            }

        } elsif ( $key1 eq "mt" ) {

            if ( ref($ref1) ne "HASH" ) {
                die "$0: XML hash: Top level value (key 'mt') is not a hash reference\n";
            }

            # Loop through all 'mt' elements at the top XML level
            foreach my $name ( keys %$ref1 ) {
                print STDERR "- MT: $name\n";
                my $ref2 = $ref1->{$name};
                if ( ref($ref2) ne "HASH" || !exists( $ref2->{'def'} ) ) {
                    die "$0: XML hash: Error in 'mt' element\n";
                }

                # Execute prepared SQL statement
                my $def   = $ref2->{'def'};
                my $share = $ref2->{'share'};
                if ( !exists( $searchdata{ "MT:" . $name } ) ) {
                    $sql_insert_MT->execute( $name, $share, $def );
                    $searchdata{ "MT:" . $name } = 1;
                    # print(STDERR "Added to MT: $name,$share,$def\n");
                }
            }

        }
    }
}

# ------------------------------------------------------------------
#
#  Recursive subroutine to digest 'hk' tags inside toplevel 'hkhead' tags:
#  -----------------------------------------------------------------------
#
sub hkloop {
    my ( $level, $ref1, $scid, $hkparent ) = @_;
    $ancestors[$level] = $hkparent;

    # Loop through all 'hk' tags at the current level
    foreach my $name ( keys %$ref1 ) {
        print STDERR "- HK tag: $name\n";
        my $ref2 = $ref1->{$name};

        # Get primary key for HK ($hkid):
        my $hkid;
        my $hashkey = "HK:" . $scid . ":" . $hkparent . ":" . $name;
        if ( !exists( $searchdata{$hashkey} ) ) {
            $sql_getkey_HK->execute();
            my @result = $sql_getkey_HK->fetchrow_array;
            $hkid = $result[0];
            $sql_getkey_HK->finish();
            #print(STDERR "Adding to HK: $hkid,$hkparent,$scid,$level,$name\n" );
            $sql_insert_HK->execute( $hkid, $hkparent, $scid, $level, $name );
            $searchdata{$hashkey} = $hkid;
        } else {
            $hkid = $searchdata{$hashkey};
        }

        #  The next level in the XML hash is either a reference to a set
        #  of 'hk' nodes (one level below current node), a reference to a
        #  set of 'bk' nodes or both:
        foreach my $key1 ( keys %$ref2 ) {
            print STDERR "- HK/BK: $key1\n";
            my $ref3 = $ref2->{$key1};

            if ( $key1 eq "hk" ) {

                # Recursive call to hkloop:
                &hkloop( $level + 1, $ref3, $scid, $hkid );

            } elsif ( $key1 eq "bk" ) {

                # Loop through all 'bk' elements within a 'hk' element:
                foreach my $ref4 (@$ref3) {

                    if ( ref($ref4) ne "HASH" ) {
                        die "$0: XML hash: Error in 'bk' element within a 'hk' element\n";
                    }
                    # Get primary key for BasicKey ($bkid):
                    my $bkid;
                    my $name    = $ref4->{'content'};
                    my $scid    = $ref4->{'sc'};
                    my $hashkey = "BK:" . $scid . ":" . $name;

                    if ( !exists( $searchdata{$hashkey} ) ) {
                        $sql_getkey_BK->execute();
                        my @result = $sql_getkey_BK->fetchrow_array;
                        $bkid = $result[0];
                        $sql_getkey_BK->finish();
                        $sql_insert_BK->execute( $bkid, $scid, $name );
                        $searchdata{$hashkey} = $bkid;
                        # print(STDERR "Added to BK: $bkid,$scid,$name\n");
                    } else {
                        $bkid = $searchdata{$hashkey};
                    }

                    if ( !exists( $searchdata{ "HKBK:" . $hkid . ":" . $bkid } ) ) {
                        # Add to HK_represent_BK relationship:
                        $sql_insert_HKBK->execute( $hkid, $bkid );
                        $searchdata{ "HKBK:" . $hkid . ":" . $bkid } = 1;
                        # print(STDERR "Added to HKBK: $hkid,$bkid\n");
                    }

                    for ( my $lev = $level ; $lev > 1 ; $lev-- ) {
                        my $hkid1 = $ancestors[$lev];
                        if ( !exists( $searchdata{ "HKBK:" . $hkid1 . ":" . $bkid } ) ) {
                            # Add to HK_represent_BK relationship:
                            $sql_insert_HKBK->execute( $hkid1, $bkid );
                            $searchdata{ "HKBK:" . $hkid1 . ":" . $bkid } = 1;
                            # print(STDERR "Added to HKBK: $hkid1,$bkid\n");
                        }
                    }

                }
            }
        }
    }
}

=head1 NAME

B<import_searchdata.pl> - Update static search data in the database from an XML file

=head1 DESCRIPTION

More later...

=head1 SYNOPSIS

More later...

=head1 TODO

Rewrite using log4perl (just wasted a whole day trying to figure out why the script crashed with no error msgs to be found)

=head1 LICENSE

Copyright (C) 2010 The Norwegian Meteorological Institute.

METAMOD is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

=cut
