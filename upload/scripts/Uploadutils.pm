#----------------------------------------------------------------------------
#  METAMOD - Web portal for metadata search and upload
#
#  Copyright (C) 2009 met.no
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

package Uploadutils;
use base qw(Exporter);
use strict;
use warnings;
use Data::Dumper;
use mmTtime;
use Metamod::Config qw(:init_logger);
use Log::Log4perl;
use Metamod::mmUserbase;

my $logger = Log::Log4perl->get_logger('metamod.upload.Uploadutils');

our $VERSION = 0.1;

our @EXPORT_OK = qw(notify_web_system
    get_dataset_institution
    shcommand_scalar
    shcommand_array
    get_basenames
    intersect
    union
    subtract
    get_date_and_time_string
    decodenorm
    string_found_in_file
    current_time syserror
    $config
    $progress_report
    $webrun_directory
    $work_directory
    $uerr_directory
    $upload_ownertag
    $application_id
    $xml_directory
    $target_directory
    $opendap_directory
    $opendap_url
    $days_to_keep_errfiles
    $path_to_syserrors
    $path_to_shell_error
    $local_url
    $shell_command_error
    @user_errors
);

use File::Find qw();
use POSIX qw();
use Fcntl qw(LOCK_SH LOCK_UN LOCK_EX);
use Metamod::Config;

#
#  Global variables (constants after initialization):
#
our $config                = new Metamod::Config();
our $progress_report       = $config->get("TEST_IMPORT_PROGRESS_REPORT");      # If == 1, prints what
                                                                               # is going on to stdout
our $webrun_directory      = $config->get('WEBRUN_DIRECTORY');
our $work_directory        = $webrun_directory . "/upl/work";
our $uerr_directory        = $webrun_directory . "/upl/uerr";
our $upload_ownertag       = $config->get('UPLOAD_OWNERTAG');
our $application_id        = $config->get('APPLICATION_ID');
our $xml_directory         = $webrun_directory . '/XML/' . $application_id;
our $target_directory      = $config->get('TARGET_DIRECTORY');
our $opendap_directory     = $config->get('OPENDAP_DIRECTORY');
our $opendap_url           = $config->get('OPENDAP_URL');
our $days_to_keep_errfiles = 14;
our $path_to_syserrors     = $webrun_directory . "/syserrors";
our $path_to_shell_error   = $webrun_directory . "/upl/shell_command_error";
our $local_url             = $config->get('LOCAL_URL');

#
# Global variable containing error messages from shell commands:
#
our $shell_command_error = "";
our @user_errors         = ();

#
#---------------------------------------------------------------------------------
#
sub notify_web_system {
    my ( $code, $dataset_name, $ref_uploaded_files, $path_to_errors_html ) = @_;
    my @uploaded_basenames = &get_basenames($ref_uploaded_files);
    my @user_filenames     = glob( $webrun_directory . '/u1/*' );

    #
    #  Get file sizees for each uploaded file:
    #
    if ( $logger->is_debug ) {
        my $msg = "notify_web_system: $code,$dataset_name\t";
        $msg .= "$path_to_errors_html\t";
        $msg .= "Uploaded basenames:\t";
        $msg .= join "\t", split( "\n", Dumper( \@uploaded_basenames ) );
        $logger->debug( $msg . "\n" );
    }
    my %file_sizes = ();
    my $i1         = 0;
    foreach my $fname (@$ref_uploaded_files) {
        my $basename = $uploaded_basenames[$i1];
        my @filestat = stat($fname);
        if ( scalar @filestat == 0 ) {
            &syserror( "SYS", "Could not stat $fname", "", "notify_web_system", "" );
            $file_sizes{$basename} = 0;
        } else {
            $file_sizes{$basename} = $filestat[7];
        }
        $i1++;
    }

    #
    #  Find current time
    #
    my @time_arr        = gmtime;
    my $year            = 1900 + $time_arr[5];
    my $mon             = $time_arr[4] + 1;                                                             # 1-12
    my $mday            = $time_arr[3];                                                                 # 1-31
    my $hour            = $time_arr[2];                                                                 # 0-23
    my $min             = $time_arr[1];                                                                 # 0-59
    my $timestring      = sprintf( '%04d-%02d-%02d %02d:%02d UTC', $year, $mon, $mday, $hour, $min );
    my @found_basenames = ();

    #
    my $userbase = Metamod::mmUserbase->new() or die "Could not initialize Userbase object";
    my @infotypes = qw(f_name f_size f_status f_errurl);

    #
    #  Loop through all users
    #
    if ( !$userbase->user_first() ) {
        if ( $userbase->exception_is_error() ) {
            $logger->error( $userbase->get_exception() . "\n" );
        }
    } else {
        do {
            foreach my $basename (@uploaded_basenames) {

                #
                #             Search for an existing file
                #             (owned by the curent user) and make it the current file
                #
                my @infovalues = ( $basename, $file_sizes{$basename}, $code . $timestring, $path_to_errors_html );
                if ( !$userbase->file_find($basename) ) {
                    if ( $userbase->exception_is_error() ) {
                        $logger->error( $userbase->get_exception() . "\n" );
                    }
                } else {
                    for ( my $i1 = 1 ; $i1 < 4 ; $i1++ ) {

                        #
                        #                   Set file property for the current file
                        #
                        if ( ( !$userbase->file_put( $infotypes[$i1], $infovalues[$i1] ) )
                            and $userbase->exception_is_error() ) {
                            $logger->error( $userbase->get_exception() . "\n" );
                        }
                    }
                    push( @found_basenames, $basename );
                }
            }
        } until ( !$userbase->user_next() );
        if ( $userbase->exception_is_error() ) {
            $logger->error( $userbase->get_exception() . "\n" );
        }
    }
    my @rest_basenames = &subtract( \@uploaded_basenames, \@found_basenames );
    if ( scalar @rest_basenames > 0 ) {

        #
        #     Find a dataset in the database
        #
        my $ok_to_now = 1;
        my $result = $userbase->dset_find( $application_id, $dataset_name );
        if ( ( !$result ) and $userbase->exception_is_error() ) {
            $logger->error( $userbase->get_exception() . "\n" );
            $ok_to_now = 0;
        } elsif ( !$result ) {    # No such dataset
            $logger->error("Dataset $dataset_name not found in the User database\n");
            $ok_to_now = 0;
        }
        if ($ok_to_now) {

            #
            #     Synchronize user against the current dataset owner
            #
            if ( ( !$userbase->user_dsync() ) and $userbase->exception_is_error() ) {
                $logger->error( $userbase->get_exception() . "\n" );
                $ok_to_now = 0;
            }
        }

        #
        #    foreach value in an array
        #
        foreach my $basename (@rest_basenames) {
            my @infovalues = ( $basename, $file_sizes{$basename}, $code . $timestring, $path_to_errors_html );
            if ($ok_to_now) {

                #
                #        Create a new file
                #        (for the current user) and make it the current file
                #
                if ( ( !$userbase->file_create($basename) ) and $userbase->exception_is_error() ) {
                    $logger->error( $userbase->get_exception() . "\n" );
                    $ok_to_now = 0;
                }
            }
            for ( my $i1 = 1 ; $i1 < 4 ; $i1++ ) {
                if ($ok_to_now) {

                    #
                    #                   Set file property for the current file
                    #
                    if ( ( !$userbase->file_put( $infotypes[$i1], $infovalues[$i1] ) )
                        and $userbase->exception_is_error() ) {
                        $logger->error( $userbase->get_exception() . "\n" );
                        $ok_to_now = 0;
                    }
                }
            }
        }
    }
    $userbase->close();
}

#
#---------------------------------------------------------------------------------
#
sub get_dataset_institution {

    #
    # Initialize hash connecting each dataset to a reference to a hash with the following
    # elements:
    #
    # ->{'institution'} Name of institution as found in an <heading> element within the webrun/u1
    #       file for the user that owns the dataset.
    # ->{'email'} The owners E-mail address.
    # ->{'name'} The owners name.
    # ->{'key'} The directory key.
    #
    # If found, extra elements are included:
    #
    # ->{'location'} Location
    # ->{'catalog'} Catalog
    # ->{'wmsurl'} URL to WMS
    #
    # The last elements are taken from the line:
    # <dir ... location="..." catalog="..." wmsurl="..."/>)
    #
    my ($ref_dataset_institution) = @_;
    my $ok_to_now = 1;
    my $userbase;
    eval { $userbase = Metamod::mmUserbase->new() or die "Could not initialize Userbase object"; };
    if ($@) {
        $logger->error("Could not connect to User database: $@");
        return 0;
    }

    #
    #  Loop through all users
    #
    if ( !$userbase->user_first() ) {
        if ( $userbase->exception_is_error() ) {
            $logger->error( $userbase->get_exception() . "\n" );
            $ok_to_now = 0;
        }
    } else {
        my @properties  = qw(u_institution u_email u_name);
        my @properties2 = qw(ds_name DSKEY LOCATION CATALOG WMS_URL);
        do {
            my @user_values = ();
            for ( my $i1 = 0 ; $i1 < 3 ; $i1++ ) {
                if ($ok_to_now) {

                    #
                    #          Get user property
                    #
                    my $val = $userbase->user_get( $properties[$i1] );
                    if ( !$val ) {
                        $logger->error( $userbase->get_exception() . "\n" );
                        $ok_to_now = 0;
                    } else {
                        push( @user_values, $val );
                    }
                }
            }

            #
            #          Loop through all datasets owned by current user
            #
            if ( !$userbase->dset_first() ) {
                if ( $userbase->exception_is_error() ) {
                    $logger->error( $userbase->get_exception() . "\n" );
                    $ok_to_now = 0;
                }
            } else {
                do {
                    my @dset_values = ();
                    for ( my $i2 = 0 ; $i2 < 5 ; $i2++ ) {
                        if ($ok_to_now) {

                            #
                            #                  Get content field in current dataset
                            #
                            my $val2 = $userbase->dset_get( $properties2[$i2] );
                            if ( ( !$val2 ) and $userbase->exception_is_error() ) {
                                $logger->error( $userbase->get_exception() );
                                $ok_to_now = 0;
                            }
                            if ( !$val2 ) {
                                $val2 = undef;
                            }
                            push( @dset_values, $val2 );
                        }
                    }
                    if ($ok_to_now) {
                        my $dataset_name = $dset_values[0];
                        if ( !defined($dataset_name) ) {
                            $logger->error("Dataset name (ds_name) not found in DataSet row in the User database\n");
                            $ok_to_now = 0;
                        } else {
                            $ref_dataset_institution->{$dataset_name}                  = {};
                            $ref_dataset_institution->{$dataset_name}->{'institution'} = $user_values[0];
                            $ref_dataset_institution->{$dataset_name}->{'email'}       = $user_values[1];
                            $ref_dataset_institution->{$dataset_name}->{'name'}        = $user_values[2];
                            $ref_dataset_institution->{$dataset_name}->{'key'}         = $dset_values[1];
                            $ref_dataset_institution->{$dataset_name}->{'location'}    = $dset_values[2];
                            $ref_dataset_institution->{$dataset_name}->{'catalog'}     = $dset_values[3];
                            $ref_dataset_institution->{$dataset_name}->{'wmsurl'}      = $dset_values[4];
                        }
                    }
                } until ( !$userbase->dset_next() );
                if ( $userbase->exception_is_error() ) {
                    $logger->error( $userbase->get_exception() . "\n" );
                    $ok_to_now = 0;
                }
            }
        } until ( !$userbase->user_next() );
        if ( $userbase->exception_is_error() ) {
            $logger->error( $userbase->get_exception() . "\n" );
            $ok_to_now = 0;
        }
    }
    $userbase->close();
    if ( !$ok_to_now ) {
        &syserror( "SYS", "Could not create the dataset_institution hash", "", "get_dataset_institution", "" );
    }
}

#
#---------------------------------------------------------------------------------
#
sub shcommand_scalar {
    my ($command) = @_;

    #   open (SHELLLOG,">>$path_to_shell_log");
    #   print SHELLLOG "---------------------------------------------------\n";
    #   print SHELLLOG $command . "\n";
    #   print SHELLLOG "                    ------------RESULT-------------\n";
    my $result = `$command 2>$path_to_shell_error`;
    my $error = $?;

    #   print SHELLLOG $result ."\n";
    #   close (SHELLLOG);
    if ( $error && -s $path_to_shell_error ) {

        #
        #     Slurp in the content of a file
        #
        unless ( -r $path_to_shell_error ) { die "Can not read from file: shell_command_error\n"; }
        open( ERROUT, $path_to_shell_error );
        local $/ = undef;
        $shell_command_error = <ERROUT>;
        #$/                   = "\n";
        close(ERROUT);
        if ( unlink($path_to_shell_error) == 0 ) {
            die "Unlink file shell_command_error did not succeed\n";
        }
        $shell_command_error = $command . "\n" . $shell_command_error;
        #return undef;
    }
    if ($error) {
        return;
    } else {
        return $result;
    }
}

#
#---------------------------------------------------------------------------------
#
sub shcommand_array {
    my ($command) = @_;

    #   open (SHELLLOG,">>$path_to_shell_log");
    #   print SHELLLOG "---------------------------------------------------\n";
    #   print SHELLLOG $command . "\n";
    my $result1 = `$command 2>$path_to_shell_error`;
    my $error = $?;

    #   print SHELLLOG "                    ------------RESULT-------------\n";
    #   print SHELLLOG $result1 . "\n";
    #   close (SHELLLOG);
    my @result = split( /\n/, $result1 );
    if ( $error && -s $path_to_shell_error ) {

        #
        #     Slurp in the content of a file
        #
        unless ( -r $path_to_shell_error ) { die "Can not read from file: shell_command_error\n"; }
        open( ERROUT, $path_to_shell_error );
        local $/ = undef;
        $shell_command_error = <ERROUT>;
        #$/                   = "\n";
        close(ERROUT);
        if ( unlink($path_to_shell_error) == 0 ) {
            die "Unlink file shell_command_error did not succeed\n";
        }
        $shell_command_error = $command . "\n" . $shell_command_error;
    }
    if ($error) {
        return;
    } else {
        return @result;
    }
}

#
#---------------------------------------------------------------------------------
#
sub get_basenames {
    my ($ref) = @_;
    my @result = ();
    foreach my $path1 (@$ref) {
        my $path = $path1;
        $path =~ s:^.*/::;
        push( @result, $path );
    }
    return @result;
}

#
#---------------------------------------------------------------------------------
#
sub intersect {
    my ( $a1, $a2 ) = @_;
    my %h1 = ();
    foreach my $elt (@$a1) {
        $h1{$elt} = 1;
    }
    my @result = ();
    foreach my $elt2 (@$a2) {
        if ( exists( $h1{$elt2} ) ) {
            push( @result, $elt2 );
        }
    }
    return @result;
}

#
#---------------------------------------------------------------------------------
#
sub union {
    my ( $a1, $a2 ) = @_;
    my %h1 = ();
    foreach my $elt ( @$a1, @$a2 ) {
        $h1{$elt} = 1;
    }
    return keys %h1;
}

#
#---------------------------------------------------------------------------------
#
sub subtract {
    my ( $a1, $a2 ) = @_;
    my %h2 = ();
    foreach my $elt (@$a2) {
        $h2{$elt} = 1;
    }
    my @result = ();
    foreach my $elt2 (@$a1) {
        if ( !exists( $h2{$elt2} ) ) {
            push( @result, $elt2 );
        }
    }
    return @result;
}

#
#---------------------------------------------------------------------------------
#
sub get_date_and_time_string {
    my @ta;
    if ( scalar @_ > 0 ) {
        @ta = localtime( $_[0] );
    } else {
        @ta = localtime( mmTtime::ttime() );
    }
    my $year       = 1900 + $ta[5];
    my $mon        = $ta[4] + 1;                                                               # 1-12
    my $mday       = $ta[3];                                                                   # 1-31
    my $hour       = $ta[2];                                                                   # 0-23
    my $min        = $ta[1];                                                                   # 0-59
    my $datestring = sprintf( '%04d-%02d-%02d %02d:%02d', $year, $mon, $mday, $hour, $min );
    return $datestring;
}

#
#---------------------------------------------------------------------------------
#
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
        return $new;
    } else {
        return '';
    }
}

#
#-----------------------------------------------------------------------------------
# Check if string found in file:
#
sub string_found_in_file {
    my ( $searchfor, $fname ) = @_;
    if ( -r $fname ) {
        open( FH, $fname );
        local $/ = undef;
        my $content = <FH>;
        close(FH);
        my $found = index( $content, $searchfor );
        if ( $found >= 0 ) {
            return 1;
        } else {
            return 0;
        }
    } else {
        return 0;
    }
}

#
#-----------------------------------------------------------------------------------
#  Find current time
#
sub current_time {
    my @ta         = localtime();
    my $year       = 1900 + $ta[5];
    my $mon        = $ta[4] + 1;                                                               # 1-12
    my $mday       = $ta[3];                                                                   # 1-31
    my $hour       = $ta[2];                                                                   # 0-23
    my $min        = $ta[1];                                                                   # 0-59
    my $datestring = sprintf( '%04d-%02d-%02d %02d:%02d', $year, $mon, $mday, $hour, $min );
    return $datestring;
}

#
#---------------------------------------------------------------------------------
# $errmsg = (NORMAL TERMINATION | error-message)
#
sub syserror {
    my ( $type, $errmsg, $uploadname, $where, $what ) = @_;
    my ( undef, undef, $baseupldname ) = File::Spec->splitpath($uploadname);

    if ( $type eq "SYS" || $type eq "SYSUSER" ) {
        ( my $msg = $errmsg );# =~ s/\n/ | /g;
        my $errMsg = "$type IN: $where: $msg; ";
        $errMsg .= "Uploaded file: $uploadname; " if $uploadname;
        if ($what) {
            ( $msg = $what );# =~ s/\n/ | /g;
            $errMsg .= "Error: $msg; ";
        }
        if ($shell_command_error) {
            ( $msg = $shell_command_error );# =~ s/\n/ | /g;
            $errMsg .= "Stderr: $msg; ";
        }
        if ( $errmsg eq 'NORMAL TERMINATION' ) {
            $logger->info( $errMsg . "\n" );
        } else {
            if ( $type eq "SYSUSER" ) {
                $logger->info( $errMsg . "\n" );
            } else {
                $logger->error( $errMsg . "\n" );
            }
        }
    }
    if ( $type eq "USER" || $type eq "SYSUSER" ) {

        # warnings about the uploaded data
        push( @user_errors, "$errmsg\nUploadfile: $baseupldname\n$what\n\n" );
    }
    $shell_command_error = "";
}
1;
