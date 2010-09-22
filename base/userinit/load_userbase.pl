#!/usr/bin/perl -w
#----------------------------------------------------------------------------
#  METAMOD - Web portal for metadata search and upload
#
#  Copyright (C) 2010 met.no
#
#  Contact information:
#  Norwegian Meteorological Institute
#  Box 43 Blindern
#  0313 OSLO
#  NORWAY
#  email: Egil.Storen@met.no
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

#
# Set up lib-directories
#
use File::Spec;

# Small routine to get lib-directories relative to the installed file:
sub getTargetDir {
    my ($finalDir) = @_;
    my ( $vol, $dir, $file ) = File::Spec->splitpath(__FILE__);
    $dir = $dir ? File::Spec->catdir( $dir, ".." ) : File::Spec->updir();
    $dir = File::Spec->catdir( $dir, $finalDir );
    return File::Spec->catpath( $vol, $dir, "" );
}
use lib ( '../../common/lib', getTargetDir('lib'), getTargetDir('scripts'), '.' );
use Metamod::Config qw(:init_logger);
use Metamod::mmUserbase;
use Metamod::Utils qw(findFiles);
use Log::Log4perl;
my $logger           = Log::Log4perl->get_logger('metamod.base.load_userbase');
my $config           = new Metamod::Config();
my $webrun_directory = $config->get("WEBRUN_DIRECTORY");
my $application_id   = $config->get("APPLICATION_ID");

#
#  Initialize an mmUserbase object
#
my $userbase = Metamod::mmUserbase->new() or die "Could not initialize Userbase object";
parse_userfiles();
$userbase->close();

sub parse_userfiles {

    #
    # Parse all user files in the webrun/u1 directory and add all information to the User database.
    # The user database has already been opened, and a global object handle is availabel ($userbase).
    # The adding into the database is done through the 'add_*' routines.
    #
    my @files_found = glob( $webrun_directory . '/u1/*' );
    my $usercount   = 0;
    foreach my $filename (@files_found) {
        my $password = get_password($filename);
        if ( !$password ) {
            $logger->warn("Filename: $filename contains no password. File not loaded\n");
            next;
        }

        #
        #        Slurp in the content of a file
        #
        unless ( -r $filename ) {
            $logger->warn("Can not read from file: $filename\n");
            next;
        }
        open( INPUTFILE, $filename );
        local $/;
        my $content = <INPUTFILE>;
        close(INPUTFILE);

        #
        my $institution;
        if ( $content =~ /<heading.* institution=\"([^\"]+)\"/m ) {
            $institution = &decodenorm($1);
        } else {
            $logger->warn("Institution_not_found_in_u1_file: $filename. File not loaded\n");
            next;
        }

        #
        my $email;
        if ( $content =~ /<heading.* email=\"([^\"]+)\"/m ) {
            $email = &decodenorm($1);
        } else {
            $logger->warn("Emailaddress_not_found_in_u1_file: $filename. File not loaded\n");
            next;
        }

        #
        my $username;
        if ( $content =~ /<heading.* name=\"([^\"]+)\"/m ) {
            $username = &decodenorm($1);
        } else {
            $logger->warn("Username_not_found_in_u1_file: $filename. File not loaded\n");
            next;
        }

        #
        my $telephone = "";
        if ( $content =~ /<heading.* telephone=\"([^\"]+)\"/m ) {
            $telephone = &decodenorm($1);
        }
        unless ( add_new_user( $username, $email, $password, $institution, $telephone ) ) {
            next;
        }
        $usercount++;

        #
        #        Collect all matches into an array
        #
        my @datasets = ( $content =~ /<dir dirname=[^>]+>/mg );
        my @attnames  = ( 'key',   'location', 'catalog', 'wmsurl' );
        my @typenames = ( 'DSKEY', 'LOCATION', 'CATALOG', 'WMS_URL' );
        my $dsetcount = 0;
        for ( my $ix = 0 ; $ix < scalar @datasets ; $ix++ ) {
            my $rex1 = '<dir dirname="([^"]*)"';
            my $line = $datasets[$ix];
            if ( $line =~ /$rex1/ ) {
                my $dataset_name = $1;
                my %dset_values  = ();
                for ( my $i1 = 0 ; $i1 < scalar @attnames ; $i1++ ) {
                    my $k1   = $attnames[$i1];
                    my $k2   = $typenames[$i1];
                    my $rex2 = $k1 . '="([^"]*)"';
                    if ( $line =~ /$rex2/ ) {
                        $dset_values{$k2} = &decodenorm($1);
                    }
                }
                if ( add_new_dataset( $dataset_name, \%dset_values ) ) {
                    $dsetcount++;
                }
            } else {
                $logger->warn("Not able to parse dataset name from line '$line' in $filename\n");
            }
        }

        #
        #        Collect all matches into an array
        #
        my @files = ( $content =~ /<file name=[^>]+>/mg );
        my $filecount = 0;
        for ( my $ix = 0 ; $ix < scalar @files ; $ix++ ) {
            my $rex1 = '<file name="([^"]*)"';
            my $line = $files[$ix];
            if ( $line =~ /$rex1/ ) {
                my $file_name   = $1;
                my %file_values = ();
                foreach my $k1 ( 'size', 'status', 'errurl' ) {
                    my $rex2 = $k1 . '="([^"]*)"';
                    if ( $line =~ /$rex2/ ) {
                        $file_values{"f_$k1"} = $1;
                    }
                }
                if ( add_new_file( $file_name, \%file_values ) ) {
                    $filecount++;
                }
            } else {
                $logger->warn("Not able to parse file name from line '$line' in $filename\n");
            }
        }
        $logger->info("User $username ($email) at $institution updated or added to User database");
        $logger->info("Updated/added $dsetcount datasets and $filecount files for user $username");
        my $count;
        if ( $dsetcount < scalar @datasets ) {
            $count = scalar @datasets - $dsetcount;
            $logger->info( "Loading of $count datasets for user $username did not succeed. "
                    . "(See warnings/errors for details)." );
        }
        if ( $filecount < scalar @files ) {
            $count = scalar @files - $filecount;
            $logger->info( "Loading of $count file names for user $username did not succeed. "
                    . "(See warnings/errors for details)." );
        }
    }
    $logger->info("Updated/added $usercount users in User database");
    if ( $usercount < scalar @files_found ) {
        my $count1 = scalar @files_found - $usercount;
        $logger->info("For $count1 users the update did not succeed. (See warnings/errors for details).");
    }
}

sub decodenorm {
    my ($strn) = @_;
    $strn =~ s/^\s+|\s+$//g;
    if ( length($strn) > 0 ) {
        my $new     = "";
        my $numchar = "";
        my @a1      = split( //, $strn );
        foreach my $ch1 (@a1) {
            if ( $ch1 =~ /[0-9A-F]/ ) {
                $numchar .= $ch1;
                if ( length($numchar) == 2 ) {
                    eval( '$new .= chr(0x' . $numchar . ');' );
                    $numchar = '';
                }
            } else {
                $new .= $ch1;
                $numchar = '';
            }
        }
        utf8::encode($new);
        return $new;
    } else {
        return '';
    }
}

sub add_new_user {
    my ( $username, $email, $password, $institution, $telephone ) = @_;

    #
    #     Find existing user by E-mail address
    #
    my $result = $userbase->user_find( $email, $application_id );
    if ( ( !$result ) and $userbase->exception_is_error() ) {
        $logger->error( $userbase->get_exception() );
        return 0;
    } elsif ( !$result ) {    # No such user
        unless ( $userbase->user_create( $email, $application_id ) ) {
            if ( $userbase->exception_is_error() ) {
                $logger->error( $userbase->get_exception() );
                return 0;
            }
        }
    }
    my @properties = qw(u_name u_password u_institution u_telephone);
    my @property_values = ( $username, $password, $institution, $telephone );
    for ( my $i1 = 0 ; $i1 < scalar @properties ; $i1++ ) {
        if ( ( !$userbase->user_put( $properties[$i1], $property_values[$i1] ) ) and $userbase->exception_is_error() ) {
            $logger->error( $userbase->get_exception() );
        }
    }
    return 1;
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

sub add_new_file {
    my ( $file_name, $ref_to_values ) = @_;
    my $current_dset = $userbase->dset_get('ds_name');
    if ( ( !$current_dset ) and $userbase->exception_is_error() ) {
        $logger->error( $userbase->get_exception() );
        return 0;
    }
    my $file_dset;
    if ( $file_name =~ /^([A-Za-z0-9.-]+)_/ ) {
        $file_dset = $1;    # First matching ()-expression
    } else {
        $logger->warn("Filename $file_name contain no dataset name \n");
        return 0;
    }
    if ( $file_dset ne $current_dset ) {
        my $result = $userbase->dset_find( $application_id, $file_dset );
        if ( ( !$result ) and $userbase->exception_is_error() ) {
            $logger->error( $userbase->get_exception() );
            return 0;
        } elsif ( !$result ) {    # No such dataset
            $logger->warn(
                "Dataset $file_dset (with name taken from file name $file_name) not found in User database\n");
            return 0;
        }
    }

    #
    #     Create a new file
    #     (for the current dataset) and make it the current file
    #
    if ( ( !$userbase->file_create($file_name) ) and $userbase->exception_is_error() ) {
        $logger->error( $userbase->get_exception() );
        return 0;
    }

    #
    #    foreach key,value pair in a hash
    #
    while ( my ( $hkey, $hvalue ) = each(%$ref_to_values) ) {
        if ( defined($hvalue) ) {

            #
            #         Set file property for the current file
            #
            if ( ( !$userbase->file_put( $hkey, $hvalue ) ) and $userbase->exception_is_error() ) {
                $logger->error( $userbase->get_exception() );
            }
        }
    }
    return 1;
}

sub get_password {
    my ($filename) = @_;
    if ( $filename =~ /\.(.+)$/ ) {
        my $password = $1;    # First matching ()-expression
        return decodenorm($password);
    } else {
        $logger->warn("No password in user file name: $filename\n");
        return 0;
    }
}
