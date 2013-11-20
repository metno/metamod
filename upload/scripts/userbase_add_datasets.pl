#!/usr/bin/perl

=begin licence

----------------------------------------------------------------------------
METAMOD - Web portal for metadata search and upload

Copyright (C) 2011 met.no

Contact information:
Norwegian Meteorological Institute
Box 43 Blindern
0313 OSLO
NORWAY
email: Egil.Storen@met.no

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
----------------------------------------------------------------------------

=end licence

=cut

=pod

=head1 userbase_add_datasets

Adds several datasets to the user database. All datasets will be owned by the
same user. The user name is the single mandatory argument to this program.
The user must already exist in the database.

The name of the datasets are read from standard input. One dataset per line.
Each dataset will be given an empty DSKEY value. No other accosiated information about
the dataset will be loaded into the database.

=head2 INVOCATION

    userbase_add_datasets username <<EOF
    dataset-name1
    dataset-name2
    ...
    EOF

=cut

use strict;

# Set up lib-directories
use FindBin qw($Bin);
use lib "$Bin/../../common/lib";

#use File::Spec;
#
## Small routine to get lib-directories relative to the installed file:
#sub getTargetDir {
#    my ($finalDir) = @_;
#    my ( $vol, $dir, $file ) = File::Spec->splitpath(__FILE__);
#    $dir = $dir ? File::Spec->catdir( $dir, ".." ) : File::Spec->updir();
#    $dir = File::Spec->catdir( $dir, $finalDir );
#    return File::Spec->catpath( $vol, $dir, "" );
#}
#use lib ( '../../common/lib', getTargetDir('lib'), getTargetDir('scripts'), '.' );

use Metamod::Config qw(:init_logger);
use Metamod::mmUserbase;
use Metamod::Utils qw(findFiles);
use Log::Log4perl;
my $logger           = Log::Log4perl->get_logger('metamod.upload.userbase_add_datasets');
my $config           = new Metamod::Config();
my $webrun_directory = $config->get("WEBRUN_DIRECTORY");
my $application_id   = $config->get("APPLICATION_ID");

my $errmsg;
if ( scalar @ARGV != 1) {
    $errmsg = "Illegal number of arguments: " . scalar @ARGV . " Should be 1";
    $logger->error( $errmsg );
    die $errmsg;
}
my $username = $ARGV[0];
my $userbase = Metamod::mmUserbase->new();
if (!$userbase) {
    $errmsg =  "Could not initialize Userbase object";
    $logger->error( $errmsg );
    die $errmsg;
}
my $result = $userbase->user_find( $username, $application_id );
if (!$result) {
    $errmsg =  $userbase->get_exception();
    $logger->error( $errmsg, $username );
    die $errmsg;
}
add_datasets();
$userbase->close();

sub add_datasets {

    #
    # Read lines with dataset names from STDIN.
    # The user database has already been opened, and a global object handle is availabel ($userbase).
    # The adding into the database is done through the 'add_*' routines.
    #
    my $dsetcount = 0;
    my $errcount = 0;
    while (<STDIN>) {
        chomp($_);
        my $dataset_name = $_;
        $dataset_name =~ s/^\s*(\S*)\s*$/$1/mg;
        my %dset_values  = ();
        $dset_values{"DSKEY"} = "";
        if ( add_new_dataset( $dataset_name, \%dset_values ) ) {
            $dsetcount++;
        } else {
            $errcount++;
        }
    }
    if ( $errcount > 0 ) {
        $logger->info( "Loading of $errcount datasets for user $username did not succeed. "
                . "(See warnings/errors for details)." );
    }
    $logger->info("Added $dsetcount datasets for user $username");
}

sub add_new_dataset {
    my ( $dataset_name, $ref_to_values ) = @_;

    #
    #     Create a new dataset
    #
    my $result = $userbase->dset_create( $dataset_name, $ref_to_values->{"DSKEY"} );
    if ( ( !$result ) and $userbase->exception_is_error() ) {
        $logger->error( $userbase->get_exception() );
        return 0;
    } elsif ( !$result ) {    # Dataset already exists
        if ( !$userbase->dset_find( $application_id, $dataset_name ) ) {
            $logger->error( $userbase->get_exception() );
            return 0;
        }
        my $uid_from_dset = $userbase->dset_get('u_id');
        if ( !$uid_from_dset and $userbase->exception_is_error() ) {
            $logger->error( $userbase->get_exception() );
            return 0;
        }
        my $uid_from_user = $userbase->user_get('u_id');
        if ( !$uid_from_user and $userbase->exception_is_error() ) {
            $logger->error( $userbase->get_exception() );
            return 0;
        }
        if ( $uid_from_dset != $uid_from_user ) {
            $logger->warn( "Dataset $dataset_name not added for user with u_id = $uid_from_user. "
                    . "The dataset already exists, owned by another user (u_id = $uid_from_dset)" );
        }
    }
    while ( my ( $hkey, $hvalue ) = each(%$ref_to_values) ) {
        if ( defined($hvalue) ) {

            #
            #         Add or replace content field in current dataset
            #
            if ( ( !$userbase->dset_put( $hkey, $hvalue ) ) and $userbase->exception_is_error() ) {
                $logger->error( $userbase->get_exception() );
            }
        }
    }
    return 1;
}
