package Metamod::UploadHelper;

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

=head1 NAME

Metamod::UploadHelper - Helper module for processing file uploads

=head1 DESCRIPTION

Monitor file uploads from data providers. Start digest_nc() on uploaded files.

=head1 USAGE

Files are either uploaded to an FTP area, or interactively to an HTTP area
using the web interface. The top level directory pathes for these two areas are
given by FIXME [was: the global variables $ftp_dir_path and $upload_dir_path].

=head1 METHODS

=cut

use Cwd;
use Data::Dump qw(dump);
use Data::Dumper;
use File::Basename;
use File::Copy;
use File::Path;
use Try::Tiny;
use Log::Log4perl qw( get_logger );
use Metamod::Email;
use Moose;

use Metamod::Config;
use Metamod::mmUserbase;
use Metamod::PrintUsererrors;
use Metamod::Utils qw(getFiletype findFiles remove_cr_from_file);
use MetNo::NcDigest;

has 'config'                => ( is => 'ro', default => sub { Metamod::Config->instance() } );
has 'logger'                => ( is => 'ro', default => sub { get_logger(__PACKAGE__) } ); # set to ro later
has 'shell_command_error'   => ( is => 'rw', default => '' );
has 'file_in_error_counter' => ( is => 'rw', default => 1 );
# This is potentially a source of errors when running as a library called from several scripts.
# Worst-case scenario is files being overwritten since FTP and web upload has separate counters
# (even worse if initing UploadHelper more than once in a script).

#has 'system_error'          => ( is => 'ro', writer  => '_log_error' );
has 'user_errors'           => ( is => 'rw', default => sub { [] } );
has 'days_to_keep_errfiles' => ( is => 'rw', default => 14 );
has 'all_ftp_datasets'      => ( is => 'rw', default => sub { {} } );
# Initialized in sub read_ftp_events. For each dataset found in the ftp_events file, this hash contains the
# number of days to keep the files in the repository. If this number == 0, the files are kept indefinitely.

has 'ftp_events'            => ( is => 'rw', default => sub { {} } );

our ($webrun_directory, $work_directory, $work_expand, $work_flat, $work_start);

sub BUILD { # ye olde init "constructor"
    my $self = shift;

    ## Make sure static directories exists - FIXME
    $webrun_directory      = $self->config->get('WEBRUN_DIRECTORY');
    $work_directory        = $webrun_directory . "/upl/work" . $$;
    $work_expand           = $work_directory . "/expand";
    $work_flat             = $work_directory . "/flat";
    $work_start            = $work_directory . "/start";

    #foreach my $directory ( $work_directory, $work_start, $work_expand, $work_flat, $uerr_directory,
    #    $xml_directory, $xml_history_directory, $problem_dir_path ) {
    #    mkpath($directory);
    #}
    #
    ##  Change to work directory
    #unless ( chdir $work_directory ) {
    #    die "Could not cd to $work_directory: $!\n";
    #}

    #  Initialize hash (ftp_events) from text file
    $self->read_ftp_events();
    # $self->logger->debug( "Dump of hash ftp_events:" . join( "\t", split "\n", Dumper( $self->ftp_events() ) ) ); # Data::Dumper works poorly in log4perl
    #print STDERR "Dump of hash ftp_events:\n" . Dumper( $self->ftp_events() );

    #  Initialize hash that contain the institution code for each dataset.
    #  The hash will be filled with updated info from the directory
    #  $webrun_directory/u1 at the beginning of each repetition of the loop.
    $self->get_dataset_institution();
}

=head2 read_ftp_events

Load the content of the ftp_events file into a hash.

=cut

sub read_ftp_events {
    my $self = shift;
    my $eventsref = $self->ftp_events;
    my $eventsfile = $webrun_directory . '/ftp_events';
    if ( -r $eventsfile ) {
        open( EVENTS, $eventsfile );
        while (<EVENTS>) {
            chomp($_);
            my $line = $_;
            $line =~ s/^\s+//;
            my @tokens = split( /\s+/, $line );
            if ( scalar @tokens >= 4 ) {
                my $dataset_name       = $tokens[0];
                my $wait_minutes       = $tokens[1];
                my $days_to_keep_files = $tokens[2];
                $self->all_ftp_datasets->{$dataset_name} = $days_to_keep_files;
                for ( my $ix = 3 ; $ix < scalar @tokens ; $ix++ ) {
                    my $hour     = $tokens[$ix];
                    my $eventkey = "$dataset_name $hour";
                    $eventsref->{$eventkey} = $wait_minutes;
                }
            }
        }
        close(EVENTS);
    }
}


=head2 ftp_process_hour

Check the FTP upload area.

For all datasets scheduled to be processed at the current hour, check if the
newest file in the dataset have large enough age. If so, process the files in
that dataset.

Does not return any sensible value since not checked on return.

=head3 TODO

Make unit tests

=cut

sub ftp_process_hour {

    my $self = shift;
    my @ltime = localtime( time() );
    my $current_hour = $ltime[2];                    # 0-23
    my $eventsref = $self->ftp_events or die "Missing ftp_events file";

    #die unless $self->config; # remove when stable
    my $ftp_dir_path = $self->config->get('UPLOAD_FTP_DIRECTORY');
    my $logger = $self->logger or die "Missing logger object";
    $logger->info("Processing FTP upload area");
    $logger->debug("ftp_process_hour: Entered at current_hour: $current_hour");

    # Hash containing, for each uploaded file to be processed (full path), the
    # modification time of that file. This hash is re- initialized for each new
    # batch of files to be processed for the same dataset.
    my %files_to_process = ();

    # search the events table for scheduled datasets and iterate
    my $rex = " 0*$current_hour" . '$';
    my @matches = grep( /$rex/, keys %$eventsref );
    foreach my $eventkey (@matches) {
        my ( $dataset_name, $hour ) = split( /\s+/, $eventkey );
        my $wait_minutes = $eventsref->{$eventkey};
        $logger->debug("[ftp_process_hour] Dataset=$dataset_name, hour=$hour, wait_minutes=$wait_minutes");
        my @files_found = findFiles( $ftp_dir_path, eval 'sub {$_[0] =~ /^\Q$dataset_name\E_/o;}' );
        if ( scalar @files_found == 0 && length($self->shell_command_error) > 0 ) {
            $self->syserrorm( "SYS", "find_fails", "", "ftp_process_hour", "" );
            next;
        }
        my $current_epoch_time = time();
        my $age_seconds        = 60 * 60 * 24;
        %files_to_process = ();
        foreach my $filename (@files_found) {
            if ( -r $filename ) {
                my @file_stat = stat($filename);
                if ( scalar @file_stat == 0 ) {
                    die "Could not stat new file $filename\n"; # should never occur since -r is implemented via stat()
                }

                # Get last modification time of file (seconds since the epoch)
                my $modification_time = $file_stat[9];
                if ( $current_epoch_time - $modification_time < $age_seconds ) {
                    $age_seconds = $current_epoch_time - $modification_time;
                }
                $files_to_process{$filename} = $modification_time;
                $logger->debug("[ftp_process_hour] File $filename (" . localtime($modification_time) . ") scheduled");
            }
        }
        my $filecount = scalar( keys %files_to_process );
        if ( $filecount > 0 ) {
            $logger->debug("[ftp_process_hour] $filecount files from $dataset_name with age $age_seconds");
        }
        if ( $filecount > 0 && $age_seconds > 60 * $wait_minutes ) {
            my $datestring = _get_date_and_time_string( $current_epoch_time - $age_seconds );
            try {
                $self->makeworkdir();
                $self->process_files( \%files_to_process, $dataset_name, 'FTP', $datestring );
            } catch {
                $self->logger->error("FTP processing died: $_");
            } finally {
                $self->cleanworkdir() or $logger->warn("Couldn't clean up working dirs in ftp_process_hour");
            };
        }
    }
    $logger->info("Finished processing files, started housecleaning");

    #print STDERR "Dump av hash all_ftp_datasets:\n";
    #print STDERR Dumper($self->all_ftp_datasets);

    #  Move any file in the ftp upload area not belonging to a dataset to the
    #  $problem_dir_path directory (the actual moving is done in the syserror
    #  routine). Only move files older than 5 hours. Newer files may be temporary
    #  files waiting to be renamed by the uploading software:
    #
    my @all_files_found = findFiles($ftp_dir_path);
    if ( scalar @all_files_found == 0 && length($self->shell_command_error) > 0 ) {
        $self->syserrorm( "SYS", "find_fails_2", "", "ftp_process_hour", "" );
    } else {
        foreach my $filename (@all_files_found) {
            my $dataset_name;
            if ( $filename =~ /([^\/_]+)_[^\/]*$/ ) {
                $dataset_name = $1;    # First matching ()-expression
            }
            if (  !defined($dataset_name)
                || scalar grep( $dataset_name eq $_, keys %{ $self->all_ftp_datasets } ) == 0 ) {
                my @file_stat = stat($filename);
                if ( scalar @file_stat == 0 ) {

                    # egils: Should not die, because uploaded files may have temporary names while uploading:
                    #die "Could not stat $filename\n";
                    $self->syserrorm( "SYS", "Could not stat problem file $filename", "", "ftp_process_hour", "" );
                } else {

                    # Get last modification time of file (seconds since the epoch)
                    my $current_epoch_time = time();
                    my $modification_time  = $file_stat[9];
                    if ( $current_epoch_time - $modification_time > 60 * 60 * 5 ) {
                        $self->syserrorm( "SYS", "file_with_no_dataset", $filename, "ftp_process_hour", "" );
                    }
                }
            }
        }
    }
    #$self->cleanworkdir() or $logger->warn("Couldn't clean up working dirs in ftp_process_hour");
    $logger->info("Finished processing FTP upload area");
}

=head2 process_upload

Not sure what this does except call process_files() ...

Returns error string if failed, otherwise nothing.

=cut

sub process_upload {
    my ($self, $inputfile, $upload_type) = @_;

    my $upload_age_threshold = $self->config->get('UPLOAD_AGE_THRESHOLD');
    $self->logger->info( "Processing web upload " . $inputfile );

    my %datasets    = ();
    my $dataset_name;
    if ( $inputfile =~ /([^\/_]+)_[^\/]*$/ ) {
        $dataset_name = $1;    # First matching ()-expression
        if ( !exists( $datasets{$dataset_name} ) ) {
            $datasets{$dataset_name} = [];
        }
        push( @{ $datasets{$dataset_name} }, $inputfile );
    }

    my $current_epoch_time = time();
    my $age_seconds        = 60 * $upload_age_threshold + 1;

    my $datestring = _get_date_and_time_string( $current_epoch_time - $age_seconds );
    my $error = try {
        $self->makeworkdir();
        $self->process_files( $inputfile, $dataset_name, $upload_type, $datestring );
    } catch {
        $self->logger->error("Upload processing died: $_");
        #$self->_log_error($_);
        $_;
    } finally {
        $self->cleanworkdir() ? '' : "Couldn't clean up working dirs in process_upload";
    };
    return $error;
}

=head2 $self->makeworkdir

Create temporary working dirs

Die on failure

=cut

sub makeworkdir {
    my ( $self ) = @_;
    #  Create the necessary directories
    $self->logger->info("Creating work dir $work_start");
    foreach my $dir ( $work_start, $work_expand, $work_flat ) {
        #$self->logger->debug("Creating work dir $dir if not exists");
        #mkpath($dir) or die "Failed to create $dir: $!" unless -d $dir && -w $dir;    # create a fresh directory if not exists
        mkpath($dir) or die "Failed to create $dir: $!";    # create a fresh directory if not exists
    }
}

=head2 $self->cleanworkdir

Remove temporary working dirs

Returns true on success, false on failure

=cut

sub cleanworkdir {
    my $self = shift;
    #  Clean up the work_start, work_flat and work_expand directories:
    my @all_errors;
    foreach my $dir ( $work_start, $work_expand, $work_flat ) {
        $self->logger->debug("Deleting work dir $dir");
        my $errors;
        rmtree($dir, error => \$errors);
        foreach (@$errors) {
            $self->logger->error("cleanworkdir failed: $_");
            push @all_errors, $_;
        }
    }
    return @all_errors == 0;
}

=head2 process_files

Process uploaded files for one dataset from either the FTP or web area.
Names of the uploaded files are found in the global %files_to_process hash.

This routine may also be used to test a file against the repository requirements.
Then, a dataset for the file need not exist.

Uploaded files are either single files or archives (tar). Archives are expanded
and one archive file will produce many expanded files. Both single files
and archives can be compressed (gzip). All such files are uncompressed.
The uncompressed expanded files are either netCDF (*.nc) or CDL (*.cdl).
CDL files are converted to netCDF.

=head3 Arguments

    $dataset_name     - Name of the dataset
    $ftp_or_web       - ='FTP' if the files are uploaded through FTP,
                        ='WEB' if files are uploaded through the web application.
                        ='TAF' if the file is uploaded just for testing.
    $datestring       - Date/time of the last uploaded file as "YYYY-MM-DD HH:MM"

=cut

sub process_files { # rewrite this 800-line monster into small, more manageable modules which can be tested separately ... FIXME

    my ( $self, $input_files, $dataset_name, $ftp_or_web, $datestring ) = @_;

    my $problem_dir_path      = $webrun_directory . "/upl/problemfiles";
    my $starting_dir          = getcwd();

    # need to reset the user error messages for each upload.
    $self->reset_user_errors();

    # also need to empty the error file
    my $usererrors_path = "$work_directory/nc_usererrors.out";
    if( -f $usererrors_path ){
        unlink $usererrors_path or die $!;
    }

    # called with multiple files (ftp) or single (web)?
    my %files_to_process = ref $input_files ? %$input_files : ( $input_files => 1 );

    my %dataset_institution = %{ $self->get_dataset_institution() };

    my %orignames = ();    # Connects the names of the expanded files to the full path of the
                           # original names of the uploaded files.
    my $errors    = 0;
    if ( $self->logger->is_debug ) {
        my $msg       = "Files to process for dataset $dataset_name at $datestring: ";
        my @files_arr = keys %files_to_process;
        $msg .= join "\t", split( "\n", Dumper( \@files_arr ) );
        $self->logger->debug( $msg );
    }

    my @originally_uploaded = keys %files_to_process;
    if ( $ftp_or_web ne 'TAF' && !defined( $dataset_institution{$dataset_name} ) ) {
        foreach my $uploadname ( keys %files_to_process ) {
            $self->move_to_problemdir($uploadname);
        }
        $self->syserrorm( "SYSUSER", "dataset_not_initialized", "", "process_files", "Dataset: $dataset_name" );
        return;
    }


    my $taf_basename;    # Used if uploaded file is only for testing
    foreach my $uploadname ( keys %files_to_process ) {
        $errors = 0;
        my ( undef, undef, $baseupldname ) = File::Spec->splitpath($uploadname);
        $taf_basename = $baseupldname;
        my $extension;
        if ( $baseupldname =~ /(\.[^.]+)$/ ) {
            $extension = $1;    # First matching ()-expression
        }

        # Copy uploaded file to the work_start directory
        my $newpath = File::Spec->catfile( $work_start, $baseupldname );
        if ( copy( $uploadname, $newpath ) == 0 ) {
            die "Copy to workdir did not succeed. Uploaded file: $uploadname, $newpath Error code: $!";
        }

        # Get type of file and act accordingly:
        my $filetype = getFiletype($newpath);
        $self->logger->info("Processing $newpath Filtype: $filetype");

        if ( $filetype =~ /^gzip/ ) {    # gzip or gzip-compressed

            my $uncompressed_path = eval { $self->gunzip_file($newpath) };
            if( !defined $uncompressed_path){
                $self->syserrorm( "SYSUSER", "gunzip_problem_with_uploaded_file: $@", $uploadname, "process_files", "" );
                $errors = 1;
                next;
            }
            (undef, undef, $extension) = fileparse($uncompressed_path, qr/\.[^.]*/);
            $newpath = $uncompressed_path;
            $filetype = getFiletype($newpath);

        }

        #
        if ( $filetype eq "tar" ) {
            if ( !defined($extension) || ( $extension ne ".tar" && $extension ne ".TAR" ) ) {
                $self->syserrorm( "SYSUSER", "uploaded_filename_with_missing_tar_ext", $uploadname, "process_files", "" );
                $errors = 1;
                next;
            }

            my $tar_orignames = $self->validate_tar_components($newpath, $uploadname, $dataset_name);
            if( !defined $tar_orignames ){
                $errors = 1;
            } else {
                %orignames = (%orignames, %$tar_orignames);
            }

            if ( $errors == 0 ) {

                $errors = $self->unpack_tar_archive($newpath, $uploadname, $work_expand, $work_flat);

                if ( $errors == 1 ) {
                    $self->syserrorm( "SYS", "uploaded_tarfile_with_components_already_encountered",
                        $uploadname, "process_files", "" );
                }
            } else {
                $self->syserrorm( "SYS", "errors_in_tar_components", $uploadname, "process_files", "" );
                next;
            }
        } else {

            # Move file directly to $work_flat:
            if ( -e File::Spec->catfile( $work_flat, $baseupldname ) ) {
                $self->syserrorm( "SYSUSER", "uploaded_file_already_encountered", $uploadname, "process_files", "" );
                next;
            } else {
                if ( move( $newpath, $work_flat ) == 0 ) {
                    $self->syserrorm( "SYS", "move_newpath_tp_work_flat_did_not_succeed",
                        "", "process_files", "Newpath: $newpath Error code: $!" );
                    next;
                }
                $orignames{$baseupldname} = $uploadname;
            }
        }
    }

    #   print "Original upload names of expanden files:\n";
    #   print Dumper(\%orignames);

    #  All files are now unpacked/expanded and moved to the $work_flat directory:
    #
    unless ( chdir $work_flat ) {
        die "Could not cd to $work_flat: $!\n";
    }
    $self->purge_current_directory( \%orignames, \%files_to_process );
    my @expanded_files = glob("*");
    if ( $self->logger->is_debug ) {
        my $msg = "Unpacked files in the work_flat directory: ";
        $msg .= join "\t", split( "\n", Dumper( \@expanded_files ) );
        $self->logger->debug( $msg );
    }

    #
    #  Convert CDL files to netCDF and then check that all files are netCDF:
    #
    $errors = 0;
    my %not_accepted = ();
    foreach my $expfile (@expanded_files) {
        my $expandedfile = $expfile;
        my $uploadname;
        if ( exists( $orignames{$expandedfile} ) ) {
            $uploadname = $orignames{$expandedfile};
        } else {
            $self->syserrorm( "SYS", "expandedfile_has_no_corresponding_upload_file",
                "", "process_files", "Expanded file: $expandedfile" );
            next;
        }
        my $extension;
        if ( $expandedfile =~ /\.([^.]+)$/ ) {
            $extension = $1;    # First matching ()-expression
        }
        my $filetype = getFiletype($expandedfile);
        $self->logger->debug("Processing $expandedfile: $filetype");
        if ( $filetype eq 'ascii' ) { # this logic is awful - rewrite asap! FIXME

            my $errorMsg = remove_cr_from_file($expandedfile);
            if ( length($errorMsg) > 0 ) { # error
                $self->syserrorm( "SYS", "remove_cr_failed: $errorMsg", $uploadname, "process_files", "" );
                $not_accepted{$expandedfile} = 1;
                $errors = 1;
            }
            elsif ( defined($extension) && ( $extension eq 'cdl' || $extension eq 'CDL' ) ) { # presumably CDL file

                # get the first line of the file, think 'head'
                if ( !open( FH, $expandedfile ) ) {
                    $self->syserrorm( "SYS", "head_command_fails_on_expandedfile",
                        "", "process_files", "Expanded file: $expandedfile" );
                    next;
                }
                my $firstline = <FH>;
                close FH;
                $self->logger->debug("Possible CDL-file. Firstline: $firstline");

                if ( $firstline =~ /^\s*netcdf\s/ ) {
                    my $ncname = substr( $expandedfile, 0, length($expandedfile) - 3 ) . 'nc';
                    if ( scalar grep( $_ eq $ncname, @expanded_files ) > 0 ) { # error, name taken
                        $self->syserrorm( "SYSUSER", "cdlfile_collides_with_ncfile_already_encountered",
                            $uploadname, "process_files", "File: $expandedfile" );
                        $not_accepted{$expandedfile} = 1;
                        $errors = 1;
                        next;
                    }
                    else { # not error
                        # run ncgen on CDL file
                        my $result = $self->shcommand_scalar("ncgen $expandedfile -o $ncname");
                        if ( length($self->shell_command_error) > 0 ) { # ncgen failed
                            my $diagnostic = $self->shell_command_error;
                            $diagnostic =~ s/^[^\n]*\n//m;
                            $diagnostic =~ s/\n/ /mg;
                            $self->syserrorm( "SYSUSER", "ncgen_fails_on_cdlfile", $uploadname, "process_files",
                                "File: $expandedfile\nCDLfile: $expandedfile\nDiagnostic: $diagnostic" );
                            if ( -e $ncname && unlink($ncname) == 0 ) {
                                $self->syserrorm( "SYS", "unlink_fails_on_ncfile", "", "process_files",
                                    "Ncfile file: $ncname" );
                            }
                            $not_accepted{$expandedfile} = 1;
                            $errors = 1;
                            next;
                        }
                        if ( unlink($expandedfile) == 0 ) {
                            $self->syserrorm( "SYS", "unlink_fails_on_expandedfile",
                                "", "process_files", "Expanded file: $expandedfile" );
                        }
                        $filetype     = getFiletype($ncname); # presumably setting to 'nc3'
                        $expandedfile = $ncname;
                        $self->logger->debug("Ncgen OK");
                    }
                }
                else { # not valid CDL
                    $self->syserrorm( "SYSUSER", "text_file_with_cdl_extension_not_a_cdlfile",
                        $uploadname, "process_files", "File: $expandedfile" );
                    $not_accepted{$expandedfile} = 1;
                    $errors = 1;
                    next;
                }
            }
        }
        if ( $filetype ne 'nc3' and $filetype ne 'nc4' ) { # something unexpected must have happened
            $self->syserrorm( "SYSUSER", "file_not_netcdf", $uploadname, "process_files",
                "File: $expfile\nBadfile: $expandedfile\nFiletype: $filetype" );
            $not_accepted{$expandedfile} = 1;
            $errors = 1;
        }
    }
    if ( $errors == 1 ) { # CDL batch conversion failed
        foreach my $expandedfile ( keys %not_accepted ) {
            if ( unlink($expandedfile) == 0 ) {
                $self->syserrorm( "SYS", "could_not_unlink", "", "process_files", "File: $expandedfile" );
            }
        }
    }
    $self->purge_current_directory( \%orignames, \%files_to_process );

    #
    unless ( chdir $work_directory ) {
        die "Could not cd to $work_directory: $!\n";
    }

    #  Decide if this batch of netCDF files are all new files, or if some of them has been
    #  uploaded before. If any re-uploads, find the XML-file representing most of the existing
    #  files in the repository that are not affected by re-uploads. Base the digest_nc.pl run
    #  on this XML file.
    my @uploaded_files = findFiles( $work_flat, eval 'sub {$_[0] =~ /^\Q$dataset_name\E_/o;}' ); # ouch! rewrite ASAP ZULU! FIXME

    #   print "Uploaded files:\n";
    #   print Dumper(\@uploaded_files);
    if ( length($self->shell_command_error) > 0 ) {
        $self->syserrorm( "SYS", "find_fails", "", "process_files", "" );
        return;
    }
    my @digest_input = ();
    my $destination_url;
    my $xmlpath;
    my $destination_dir;
    my $opendap_directory = $self->config->get('OPENDAP_DIRECTORY');
    my $opendap_url       = $self->config->get('OPENDAP_URL');
    my $application_id    = $self->config->get('APPLICATION_ID');
    if ( $ftp_or_web ne 'TAF' ) {
        my $institution = $dataset_institution{$dataset_name}->{'institution'};
        $destination_dir = File::Spec->catdir( $opendap_directory, $institution, $dataset_name );
        if (! -e $destination_dir) {
            mkpath($destination_dir) or $self->logger->error("unable to mkdir $destination_dir");
            $self->logger->info("Created directory " . $destination_dir);
        }
        $xmlpath = File::Spec->catfile( $webrun_directory, 'XML', $application_id, $dataset_name . '.xml' );

        $destination_url = $opendap_url;
        if ( $destination_url !~ /\/$/ ) {
            $destination_url .= '/';
        }
        my $opendap_basedir = $self->config->get('OPENDAP_BASEDIR');
        unless ($opendap_basedir) {
            die "undefined OPENDAP_BASEDIR variable\n";
        }

        # last for for / at end
        $destination_url .= join( '/', $opendap_basedir, $institution, $dataset_name, "" );
    } else {
        $destination_url = 'TESTFILE';
        $xmlpath         = 'TESTFILE';
    }

    @digest_input = @uploaded_files;

    open( DIGEST, ">digest_input" );
    print DIGEST $destination_url . "\n";
    foreach my $fname (@digest_input) {
        print DIGEST $fname . "\n";
    }
    close(DIGEST);

    # change back to script dir or else lib path searching will fail
    #chdir $starting_dir or die "Could not cd to script dir '$starting_dir': $!"; # not working... FIXME

    #
    #  Digest the NetCDF file(s?) and process user errors if found:
    #
    my $upload_ownertag = $self->config->get('UPLOAD_OWNERTAG');
    MetNo::NcDigest::digest("$work_directory/digest_input", $upload_ownertag, $xmlpath ); # at least no longer running via shell

#    my $command = "$path_to_digest_nc $path_to_etc digest_input $upload_ownertag $xmlpath";
#    $self->logger->debug("RUN:    $command");
#    my $result = $self->shcommand_scalar($command);
#    if ( defined($result) ) {
#        open( DIGOUTPUT, ">digest_out" );
#        print DIGOUTPUT $result . "\n";
#        close(DIGOUTPUT);
#    }

    open( USERERRORS, ">>$usererrors_path" ) or die "Cannot open $usererrors_path for output!";
    my @user_errors = @{ $self->user_errors() };
    foreach my $line (@user_errors) {
        print USERERRORS $line;
    }
    close(USERERRORS);

    #
    if ( length($self->shell_command_error) > 0 ) {
        $self->logger->error("digest_nc_fails: " . $self->shell_command_error);
        if ( $ftp_or_web ne 'TAF' ) {
            foreach my $uploadname ( keys %files_to_process ) {
                $self->move_to_problemdir($uploadname);
            }
        }
        return;
    } else {
        if ( $ftp_or_web ne 'TAF' ) {

            # Generate destination paths for all data files
            my %destination_paths = ();
            foreach my $filepath (@digest_input) {
                my ( undef, undef, $basename ) = File::Spec->splitpath($filepath);
                $destination_paths{$filepath} = File::Spec->catfile($destination_dir, $basename);
            }

            # run digest_nc again for each file with output to dataset/file.xml
            # this creates the level 2 (children) xml-files
            foreach my $filepath (@uploaded_files) {
                my ( undef, undef, $basename ) = File::Spec->splitpath($filepath);
                my $destination_path = $destination_paths{$filepath};
                my $thredds_dataset_prefix = '';
                if ($self->config->get('THREDDS_DATASET_PREFIX')) {
                    $thredds_dataset_prefix = $self->config->get('THREDDS_DATASET_PREFIX');
                }
                my $fileURL =
                      $destination_url
                    . "catalog.html?dataset="
                    . $thredds_dataset_prefix
                    . join( '/', $dataset_institution{$dataset_name}->{'institution'}, $dataset_name, $basename );
                open( my $digest, ">$work_directory/digest_input" );
                print $digest $fileURL,  "\n";
                print $digest $filepath . " ";
                print $digest $destination_path . "\n";
                close $digest;
                my $pureFile = $basename;
                $pureFile =~ s/\.[^.]*$//;    # remove extension
                my $xmlFileDir = substr $xmlpath, 0, length($xmlpath) - 4;    # remove .xml

                if ( !-d $xmlFileDir ) {
                    if ( !mkdir($xmlFileDir) ) {
                        $self->syserrorm( "SYS", "mkdir_fails", $filepath, "process_files", "mdkir $xmlFileDir" );
                        return;
                    }
                }
                my $xmlFilePath = File::Spec->catfile( $xmlFileDir, $pureFile . '.xml' );
                MetNo::NcDigest::digest( "$work_directory/digest_input", $upload_ownertag, $xmlFilePath, 'isChild');
                #$self->shcommand_scalar($digestCommand);
                #if ( length($self->shell_command_error) > 0 ) {
                #    $self->logger->error("digest_nc_file_fails $filepath");
                #    return;
                #}
            }

            # Move new files to the data repository:
            my $movecount = 0;
            foreach my $filepath (@digest_input) {
                my $destination_path = $destination_paths{$filepath};
                if ( $filepath ne $destination_path ) {
                    if ( move( $filepath, $destination_dir ) == 0 ) {
                        $self->syserrorm( "SYS", "Move $filepath to $destination_dir did not succeed. Error code: $!",
                            "", "process_files", "" );
                    } else {
                        $movecount++;
                    }
                }
            }
            $self->logger->info("Upload_monitor has moved " . $movecount . " files for dataset " .
                          $dataset_name . " to the data repository");
        }
        my $url_to_errors_html = "";
        my $mailbody;
        my $subject = $self->config->get('EMAIL_SUBJECT_WHEN_UPLOAD_ERROR');
        if ( $ftp_or_web eq 'TAF' ) {
            $subject = 'File test report';
        }
        my $dont_send_email_to_user =
            $self->string_found_in_file( $dataset_name, $webrun_directory . '/' . 'datasets_for_silent_upload' );

        if ( -z $usererrors_path ) { # No user errors:
            my @no_error_files = keys %files_to_process;    # files not moved to problem_dir
            if ( $ftp_or_web ne 'TAF' ) {
                if ($dont_send_email_to_user) {
                    $self->notify_web_system( 'Operator reload ', $dataset_name, \@no_error_files, "" );
                } else {
                    $self->notify_web_system( 'File accepted ', $dataset_name, \@no_error_files, "" );
                }
            } else {
                my @bnames = $self->get_basenames( \@no_error_files );
                my $bnames_string = join( ", ", @bnames );
                $mailbody = "Dear [OWNER],\n\nNo errors found in file(s) $bnames_string .\n\n";
            }
        } else { # User errors found (by digest_nc.pl or this script):
            my $local_url = $self->config->get('LOCAL_URL');
            my $uerr_directory = $webrun_directory . "/upl/uerr";

            $mailbody = $self->config->get('EMAIL_BODY_WHEN_UPLOAD_ERROR');
            my @bnames = $self->get_basenames( \@originally_uploaded );
            my $bnames_string = join( ", ", @bnames );
            my $name_html_errfile   = $self->html_error_file($dataset_name, $uerr_directory, $datestring);
            my $path_to_errors_html = File::Spec->catfile( $uerr_directory, $name_html_errfile );

            my $errorinfo_path      = "errorinfo";
            open( ERRORINFO, ">$work_directory/$errorinfo_path" );
            print ERRORINFO $path_to_errors_html . "\n";
            print ERRORINFO $bnames_string . "\n";
            print ERRORINFO $datestring . "\n";
            close(ERRORINFO);
            $url_to_errors_html = $local_url . '/upl/uerr/' . $name_html_errfile;
            my $path_to_usererrors_conf  = $self->config->path_to_config_file('usererrors.conf', 'etc');

            # Run the print_usererrors.pl script:
            Metamod::PrintUsererrors::print_errors($path_to_usererrors_conf, $usererrors_path, $errorinfo_path);
#            my $result = $self->shcommand_scalar(
#                "$path_to_print_usererrors " . "$path_to_usererrors_conf " . "$usererrors_path " . "$errorinfo_path " );
#            if ( length($self->shell_command_error) > 0 ) {
#                $self->logger->error("print_usererrors_fails");
#                return;
#            }
            my @no_error_files = keys %files_to_process;    # files not moved to problem_dir
            if ( $ftp_or_web ne 'TAF' ) {
                if ($dont_send_email_to_user) {
                    $self->notify_web_system( 'Operator reload ', $dataset_name, \@no_error_files, "" );
                } else {
                    $self->notify_web_system( 'Errors found ', $dataset_name, \@no_error_files, $url_to_errors_html );
                }
            }
        }

        # Send mail to owner of the dataset:
        if ( defined($mailbody) ) {
            my $recipient;
            my $username;
            if ( $ftp_or_web ne 'TAF' ) {
                $recipient = $dataset_institution{$dataset_name}->{'email'};
                $username  = $dataset_institution{$dataset_name}->{'name'} . " ($recipient)";
            } else {
                my $identfile = File::Spec->catfile($webrun_directory, 'upl', 'etaf', $taf_basename);
                unless ( -r $identfile ) {
                    $self->logger->error("email_file_not_found: $identfile" );
                    return;
                }
                open( IDENT, $identfile );
                undef $/;
                my $identstring = <IDENT>;
                $/ = "\n";
                close(IDENT);
                chomp($identstring);
                if ( $identstring =~ /^(\S+)\s+(.+)$/ ) {
                    $recipient = $1;                     # First matching ()-expression
                    $username  = $2 . " ($recipient)";
                }
            }
            if ( ( !$self->config->get('TEST_EMAIL_RECIPIENT') ) || $dont_send_email_to_user ) {
                $recipient = $self->config->get('OPERATOR_EMAIL');
            }
            if ( $self->config->get('TEST_EMAIL_RECIPIENT') ne '0' ) {
                my $external_url = $url_to_errors_html;
                if ( substr( $external_url, 0, 7 ) ne 'http://' ) {
                    $external_url = $self->config->get('BASE_PART_OF_EXTERNAL_URL') . $url_to_errors_html;
                }
                $mailbody =~ s/\[OWNER\]/$username/mg;
                $mailbody =~ s/\[DATASET\]/$dataset_name/mg;
                $mailbody =~ s/\[URL\]/$external_url/mg;
                $mailbody .= "\n";
                $mailbody .= $self->config->get('EMAIL_SIGNATURE');
                my $sender  = $self->config->get('FROM_ADDRESS');

                Metamod::Email::send_simple_email(
                    to => [ $recipient ],
                    from => $sender,
                    subject => $subject,
                    body => $mailbody,
                );

            }
        }
        foreach my $uploadname ( keys %files_to_process ) {
            if ( unlink($uploadname) == 0 ) {
                $self->syserrorm( "SYS", "Unlink file $uploadname did not succeed", "", "process_files", "" );
            }
        }
        if ( $ftp_or_web eq 'TAF' ) {
            my @bnames = $self->get_basenames( \@originally_uploaded );
            foreach my $bn (@bnames) {
                if ( unlink( "$webrun_directory/upl/etaf/$bn" ) == 0 ) {
                    $self->syserrorm( "SYS", "Unlink TAF file etaf/$bn did not succeed", "", "process_files", "" );
                }
            }
        }
    }

}

=head2 get_dataset_institution

Initialize hash connecting each dataset to a reference to a hash with the following elements:

=over 4

=item institution

Name of institution as found in an <heading> element within the webrun/u1 file for the user that owns the dataset.

=item email

The owners E-mail address

=item name

The owners name

=item key

The directory key

=back

If found, extra elements are included:

=over 4

=item location

Location

=item catalog

Catalog

=item wmsurl

URL to WMS

=back

The last elements are taken from the line:

  <dir ... location="..." catalog="..." wmsurl="..."/>)

=cut

sub get_dataset_institution {
    my $self = shift;

    my $dataset_institution = {};

    my $ok_to_now = 1;
    my $userbase;
    eval { $userbase = Metamod::mmUserbase->new() or die "Could not initialize Userbase object"; };
    if ($@) {
        $self->logger->error("Could not connect to User database: $@");
        return 0;
    }

    # Loop through all users
    if ( !$userbase->user_first() ) {
        if ( $userbase->exception_is_error() ) {
            $self->logger->error( $userbase->get_exception() . "\n" );
            $ok_to_now = 0;
        }
    } else {
        my @properties  = qw(u_institution u_email u_name);
        my @properties2 = qw(ds_name DSKEY LOCATION CATALOG);
        do {

            my @user_values = ();
            for ( my $i1 = 0 ; $i1 < 3 ; $i1++ ) {
                if ($ok_to_now) {

                    # Get user property
                    my $val = $userbase->user_get( $properties[$i1] );
                    if ( !$val ) {
                        $self->logger->warn( $userbase->get_exception() . "\n" );
                        $ok_to_now = 0;  # not a fatal error - u_institution is not required
                        @user_values = (); # empty the fields list
                        #last;              # we're ignoring this user
                    } else {
                        push( @user_values, $val );
                        #$self->logger->debug( "User: " . join('|', @user_values) );
                    }
                }
            }

            if (@user_values) { # skip users w/ missing info (like admins)
                # Loop through all datasets owned by current user
                if ( !$userbase->dset_first() ) {
                    if ( $userbase->exception_is_error() ) {
                        $self->logger->error( $userbase->get_exception() . "\n" );
                        $ok_to_now = 0;
                    }
                } else {
                    do {
                        my @dset_values = ();
                        for ( my $i2 = 0 ; $i2 < 4 ; $i2++ ) {
                            if ($ok_to_now) {

                                # Get content field in current dataset
                                my $val2 = $userbase->dset_get( $properties2[$i2] );
                                if ( ( !$val2 ) and $userbase->exception_is_error() ) {
                                    $self->logger->error( $userbase->get_exception() . " (*ACTUALLY*, $properties2[$i2] is not set)" );
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
                                $self->logger->error("Dataset name (ds_name) not found in DataSet row in the User database\n");
                                $ok_to_now = 0;
                            } else {
                                $dataset_institution->{$dataset_name}                  = {};
                                $dataset_institution->{$dataset_name}->{'institution'} = $user_values[0];
                                $dataset_institution->{$dataset_name}->{'email'}       = $user_values[1];
                                $dataset_institution->{$dataset_name}->{'name'}        = $user_values[2];
                                $dataset_institution->{$dataset_name}->{'key'}         = $dset_values[1];
                                $dataset_institution->{$dataset_name}->{'location'}    = $dset_values[2];
                                $dataset_institution->{$dataset_name}->{'catalog'}     = $dset_values[3];
                            }
                        }
                    } until ( !$userbase->dset_next() );
                    if ( $userbase->exception_is_error() ) {
                        $self->logger->error( $userbase->get_exception() . "\n" );
                        $ok_to_now = 0;
                    }
                }
            }

        } until ( !$userbase->user_next() );

        if ( $userbase->exception_is_error() ) {
            $self->logger->error( $userbase->get_exception() . "\n" );
            $ok_to_now = 0;
        }
    }

    $userbase->close();
    if ( !$ok_to_now ) {
        $self->logger->error("Could not create the dataset_institution hash");
    }

    return $dataset_institution;
}

=head2 shcommand_scalar

Run command via shell (in most cases needlessly as should be Perl modules instead)

=cut

sub shcommand_scalar {
    my $self = shift;

    my ($command) = @_;
    $self->logger->debug( 'shcommand_scalar running: ', $command );

    my $path_to_shell_error   = $webrun_directory . "/upl/shell_command_error";

    #   open (SHELLLOG,">>$path_to_shell_log");
    #   print SHELLLOG "---------------------------------------------------\n";
    #   print SHELLLOG $command . "\n";
    #   print SHELLLOG "                    ------------RESULT-------------\n";

    my $result = `$command 2>$path_to_shell_error`; # FIXME
    my $error = $?;

    #   print SHELLLOG $result ."\n";
    #   close (SHELLLOG);
    if ( $error && -s $path_to_shell_error ) {

        # Slurp in the content of a file
        unless ( -r $path_to_shell_error ) { die "Can not read from file: shell_command_error\n"; }
        open( ERROUT, $path_to_shell_error );
        local $/ = undef;
        my $shell_command_error = <ERROUT>;
        #$/                   = "\n";
        close(ERROUT);
        if ( unlink($path_to_shell_error) == 0 ) {
            die "Unlink file shell_command_error did not succeed\n";
        }
        $shell_command_error = $command . "\n" . $shell_command_error;
        $self->shell_command_error($shell_command_error);
        #return undef;
    }
    if ($error) {
        $self->logger->warn("unable to execute: $command");
        return;
    } else {
        return $result;
    }
}

=head2 shcommand_array

Run command via shell (in most cases needlessly as should be Perl modules instead)

Returns output split into array on newlines (did that really deserve a copypasted method?)

=cut

sub shcommand_array {
    my $self = shift;

    my ($command) = @_;
    $self->logger->debug( 'shcommand_array running: ', $command );

    my $path_to_shell_error   = $webrun_directory . "/upl/shell_command_error";

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
        my $shell_command_error = <ERROUT>;
        #$/                   = "\n";
        close(ERROUT);
        if ( unlink($path_to_shell_error) == 0 ) {
            die "Unlink file shell_command_error did not succeed\n";
        }
        $shell_command_error = $command . "\n" . $shell_command_error;
        $self->shell_command_error($shell_command_error);
    }
    if ($error) {
        return;
    } else {
        return @result;
    }
}

=head2 move_to_problemdir

Move away file, log error

=cut

sub move_to_problemdir {
    my $self = shift;

    my $problem_dir_path = $webrun_directory . "/upl/problemfiles";

    my ($uploadname) = @_;
    if ( -e $uploadname ) {
        my $baseupldname = $uploadname;
        if ( $uploadname =~ /\/([^\/]+)$/ ) {
            $baseupldname = $1;    # First matching ()-expression
        }

        #  Move upload file to problem file directory:
        my @file_stat = stat($uploadname);
        if ( scalar @file_stat == 0 ) {
            die "In move_to_problemdir: Could not stat $uploadname\n";
        }
        my $modification_time = $file_stat[9];
        my @ltime             = localtime( time() );
        my $current_day       = $ltime[3];                         # 1-31

        my $destname = sprintf( '%02d%04d', $current_day, $self->file_in_error_counter) . "_" . $baseupldname;
        $self->file_in_error_counter($self->file_in_error_counter() + 1);
        my $destpath = $problem_dir_path . "/" . $destname;
        if ( move( $uploadname, $destpath ) == 0 ) {
            die "In move_to_problemdir: Moving '$uploadname' to '$destpath' did not succeed. Error code: $!\n";
        }

        # Write message to files_with_errors log:
        my $datestring = _get_date_and_time_string($modification_time);
        my $path       = $problem_dir_path . "/files_with_errors";
        open( OUT, ">>$path" );
        print OUT "File: $uploadname modified $datestring copied to $destname\n";
        close(OUT);

        #
        #if ( exists( $files_to_process{$uploadname} ) ) {
        #    delete $files_to_process{$uploadname};
        #}
    }
}

=head2 purge_current_directory

Delete a bunch of files

=cut

sub purge_current_directory {
    my $self = shift;

    my ($ref_orignames, $files_to_process) = @_;
    foreach my $basename ( keys %$ref_orignames ) {
        my $upldname = $ref_orignames->{$basename};
        if ( !exists( $files_to_process->{$upldname} ) ) {
            if ( -e $basename ) {
                if ( unlink($basename) == 0 ) {
                    $self->syserrorm( "SYS", "Unlink file $basename did not succeed", "", "purge_current_directory", "" );
                }
            }
            delete $ref_orignames->{$basename};
        }
    }
}

# ------------------------------------------------------------------------------
#  various local helper methods below
# ------------------------------------------------------------------------------

#
# add another error message to the queue
#
sub add_user_error {
    my ($self, $error) = @_;

    my $user_errors = $self->user_errors();
    push @{ $user_errors }, $error;
    $self->user_errors($user_errors);
}

#
# delete all error messages
#
sub reset_user_errors {
    my $self = shift;

    $self->user_errors([]);
}

=head2 $self->gunzip_file( $filename )

Unzip gzipped file, returning basename minus extension (or .tar if .tgz)

=cut

sub gunzip_file {
    my $self = shift;

    my ($filename) = @_;

    # Uncompress file:
    $self->logger->debug( "gunziping $filename ..." );
    my $result = $self->shcommand_scalar("gunzip $filename"); # FIXME - use Gzip::Faster instead
    if ( !defined($result) ) {
        $self->syserrorm( "SYSUSER", "gunzip_problem_with_uploaded_file", $filename, "process_files", "" );
        return;
    }

    my ($basename, $dirs, $extension) = fileparse($filename, qr/\.[^.]*/);
    my $newfilename = File::Spec->catfile($dirs, $basename);
    if ($extension eq '.tgz') {
        $newfilename = "$newfilename.tar";
    }
    $self->logger->debug( "Filename after gunzip: $newfilename" );
    if ( -r $newfilename) {
        return $newfilename;
    } else {
        #$self->syserrorm( "Can't find $newfilename after unpacking $filename" );
        #return;
        die "Can't find $newfilename after unpacking $filename";
    }
}

=head2 $tar_orignames = $self->validate_tar_components($newpath, $uploadname, $dataset_name)

extract filenames in tarball

=cut

sub validate_tar_components {
    my $self = shift;

    my ($tarfile, $orig_name, $dataset_name) = @_;

    # Get all component file names in the tar file:
    my @tarcomponents = $self->shcommand_array("tar tf $tarfile");
    if ( length($self->shell_command_error) > 0 ) {
        $self->syserrorm( "SYSUSER", "unable_to_unpack_tar_archive", $orig_name, "process_files", "" );
        return;
    }
    if ( $self->logger->is_debug ) {
        my $msg = "Components of the tar file $tarfile : ";
        $msg .= join "\t", split( "\n", Dumper( \@tarcomponents ) );
        $self->logger->debug( $msg );
    }
    my %basenames    = ();
    my %orignames    = ();
    my $errcondition = "";

    # Check the component file names:
    foreach my $component (@tarcomponents) {
        if ( substr( $component, 0, 1 ) eq "/" ) {
            $self->syserrorm( "USER", "uploaded_tarfile_with_abs_pathes",
                $orig_name, "process_files", "Component: $component" );
            return;
        }
        my $basename = $component;
        if ( $component =~ /\/([^\/]+)$/ ) {
            $basename = $1;    # First matching ()-expression
        }
        if ( exists( $basenames{$basename} ) ) {
            $self->syserrorm( "USER", "uploaded_tarfile_with_duplicates",
                $orig_name, "process_files", "Component: $basename" );
            return;
        }
        $basenames{$basename} = 1;
        $orignames{$basename} = $orig_name;
        if ( index( $basename, $dataset_name . '_' ) < 0 ) {
            $self->syserrorm( "USER", "uploaded_tarfile_with_illegal_component_name",
                $orig_name, "process_files", "Component: $basename" );
            return;
        }
    }

    return \%orignames;

}

=head2 $errors = $self->unpack_tar_archive($newpath, $uploadname, $work_expand, $work_flat);

Expand the tar file onto the $work_expand directory.
Move all expanded files to the $work_flat directory, which
will not contain any subdirectories. Check that no duplicate
file names arise.

=cut

sub unpack_tar_archive {
    my $self = shift;

    my ($tar_file, $uploadname, $work_expand, $work_flat) = @_;

    # Expand the tar file onto the $work_expand directory
    unless ( chdir $work_expand ) {
        die "Could not cd to $work_expand: $!\n";
    }
    my $tar_results = $self->shcommand_scalar("tar xf $tar_file"); # FIXME - use  Archive::Tar
    if ( length($self->shell_command_error) > 0 ) {
        $self->syserrorm( "SYSUSER", "tar_xf_fails", $uploadname, "process_files", "" );
        next;
    }

    my @tarcomponents = $self->shcommand_array("tar tf $tar_file");
    if ( length($self->shell_command_error) > 0 ) {
        $self->syserrorm( "SYSUSER", "unable_to_unpack_tar_archive", $uploadname, "process_files", "" );
        next;
    }

    my $errors = 0;

    # Move all expanded files to the $work_flat directory, which
    # will not contain any subdirectories. Check that no duplicate
    # file names arise.
    foreach my $component (@tarcomponents) {
        my $bname = $component;
        if ( $component =~ /\/([^\/]+)$/ ) {
            $bname = $1;    # First matching ()-expression
        }
        if ( -e File::Spec->catfile( $work_flat, $bname ) ) {
                $self->syserrorm( "USER", "uploaded_tarfile_with_component_already_encountered",
                    $uploadname, "process_files", "Component: $bname" );
                $errors = 1;
            next;
        }
        if ( move( $component, $work_flat ) == 0 ) {
            $self->syserrorm( "SYS", "move_tar_component_did_not_succeed",
                "", "process_files", "Component: $component Error code: $!" );
            next;
        }
    }

    return $errors;

}

#
# poor man's reimplementation of DateTime->now->datetime...
#
sub _get_date_and_time_string {
    my $notnow = shift;
    my @ta = localtime( $notnow || time() );
    my $year       = 1900 + $ta[5];
    my $mon        = $ta[4] + 1;                                                               # 1-12
    my $mday       = $ta[3];                                                                   # 1-31
    my $hour       = $ta[2];                                                                   # 0-23
    my $min        = $ta[1];                                                                   # 0-59
    my $datestring = sprintf( '%04d-%02d-%02d %02d:%02d', $year, $mon, $mday, $hour, $min );
    return $datestring;
}

=head1 $self->get_basenames( $arrayref )

Apparently strips paths from a list of filenames

=cut

sub get_basenames {
    my ($self, $ref) = @_;
    my @result = ();
    foreach my $path1 (@$ref) {
        my $path = $path1;
        $path =~ s:^.*/::; # stripping path from filename? better use fileparse()
        #eval { print STDERR " >> basename = '$path' was '$path1'\n"; };
        push( @result, $path );
    }
    return @result;
}

sub subtract {
    my $self = shift;

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
# Check if string found in file:
#
sub string_found_in_file {
    my $self = shift;

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
# send email to users (?)
#
sub notify_web_system {
    my $self = shift;

    my ( $code, $dataset_name, $ref_uploaded_files, $path_to_errors_html ) = @_;
    my @uploaded_basenames = $self->get_basenames($ref_uploaded_files);

    #
    #  Get file sizes for each uploaded file:
    #
    if ( $self->logger->is_debug ) {
        my $msg = "notify_web_system: $code,$dataset_name\t";
        $msg .= "$path_to_errors_html\t";
        $msg .= "Uploaded basenames:\t";
        $msg .= join "\t", split( "\n", Dumper( \@uploaded_basenames ) );
        $self->logger->debug( $msg );
    }
    my %file_sizes = ();
    my $i1         = 0;
    foreach my $fname (@$ref_uploaded_files) {
        my $basename = $uploaded_basenames[$i1];
        my @filestat = stat($fname);
        if ( scalar @filestat == 0 ) {
            $self->logger->error("Could not stat uploaded file $fname");
            $file_sizes{$basename} = 0;
        } else {
            $file_sizes{$basename} = $filestat[7];
        }
        $i1++;
    }

    #
    # Find current time
    #
    my @time_arr        = gmtime;
    my $year            = 1900 + $time_arr[5];
    my $mon             = $time_arr[4] + 1;                                                             # 1-12
    my $mday            = $time_arr[3];                                                                 # 1-31
    my $hour            = $time_arr[2];                                                                 # 0-23
    my $min             = $time_arr[1];                                                                 # 0-59
    # rewrite to use DateTime->now->datetime
    my $timestring      = sprintf( '%04d-%02d-%02d %02d:%02d UTC', $year, $mon, $mday, $hour, $min );
    my @found_basenames = ();

    my $userbase = Metamod::mmUserbase->new() or die "Could not initialize Userbase object";
    my @infotypes = qw(f_name f_size f_status f_errurl);

    #
    #  Loop through all users
    #
    if ( !$userbase->user_first() ) {
        if ( $userbase->exception_is_error() ) {
            $self->logger->error( $userbase->get_exception() . "\n" );
        }
    } else {
        do {
            foreach my $basename (@uploaded_basenames) {

                # Search for an existing file (owned by the current user) and make it the current file
                my @infovalues = ( $basename, $file_sizes{$basename}, $code . $timestring, $path_to_errors_html );
                if ( !$userbase->file_find($basename) ) {
                    if ( $userbase->exception_is_error() ) {
                        $self->logger->error( $userbase->get_exception() . "\n" );
                    }
                } else {
                    for ( my $i1 = 1 ; $i1 < 4 ; $i1++ ) {

                        # Set file property for the current file
                        if ( ( !$userbase->file_put( $infotypes[$i1], $infovalues[$i1] ) )
                            and $userbase->exception_is_error() ) {
                            $self->logger->error( $userbase->get_exception() . "\n" );
                        }
                    }
                    push( @found_basenames, $basename );
                }
            }
        } until ( !$userbase->user_next() );
        if ( $userbase->exception_is_error() ) {
            $self->logger->error( $userbase->get_exception() . "\n" );
        }
    }

    #
    # now doing what?
    #
    my $application_id = $self->config->get('APPLICATION_ID');
    my @rest_basenames = $self->subtract( \@uploaded_basenames, \@found_basenames );
    if ( scalar @rest_basenames > 0 ) {

        # Find a dataset in the database
        my $ok_to_now = 1;
        my $result = $userbase->dset_find( $application_id, $dataset_name );
        if ( ( !$result ) and $userbase->exception_is_error() ) {
            $self->logger->error( $userbase->get_exception() . "\n" );
            $ok_to_now = 0;
        } elsif ( !$result ) {    # No such dataset
            $self->logger->error("Dataset $dataset_name not found in the User database\n");
            $ok_to_now = 0;
        }
        if ($ok_to_now) {

            # Synchronize user against the current dataset owner
            if ( ( !$userbase->user_dsync() ) and $userbase->exception_is_error() ) {
                $self->logger->error( $userbase->get_exception() . "\n" );
                $ok_to_now = 0;
            }
        }

        # foreach value in an array
        foreach my $basename (@rest_basenames) {
            my @infovalues = ( $basename, $file_sizes{$basename}, $code . $timestring, $path_to_errors_html );
            if ($ok_to_now) {

                # Create a new file (for the current user) and make it the current file
                if ( ( !$userbase->file_create($basename) ) and $userbase->exception_is_error() ) {
                    $self->logger->error( $userbase->get_exception() . "\n" );
                    $ok_to_now = 0;
                }
            }
            for ( my $i1 = 1 ; $i1 < 4 ; $i1++ ) {
                if ($ok_to_now) {

                    # Set file property for the current file
                    if ( ( !$userbase->file_put( $infotypes[$i1], $infovalues[$i1] ) )
                        and $userbase->exception_is_error() ) {
                        $self->logger->error( $userbase->get_exception() . "\n" );
                        $ok_to_now = 0;
                    }
                }
            }
        }
    }
    $userbase->close();
}


#
# Delete problem files older than 14 days (or whatever)
#
sub clean_up_problem_dir {
    my $self = shift;
    my $problem_dir_path = $webrun_directory . "/upl/problemfiles";

    my @files_found = findFiles( $problem_dir_path, sub { $_[0] =~ /^\d/; } );
    if ( scalar @files_found == 0 && length($self->shell_command_error) > 0 ) {
        $self->syserrorm( "SYS", "find_fails", "", "clean_up_problem_dir", "" );
    }

    # Find current time (epoch) as number of seconds since the epoch (1970)
    my $current_epoch_time = time(); # no more relativistic time machine wizardry
    my $age_seconds        = 60 * 60 * 24 * $self->days_to_keep_errfiles;
    foreach my $filename (@files_found) {
        if ( -r $filename ) {
            my @file_stat = stat($filename);
            if ( scalar @file_stat == 0 ) {
                $self->syserrorm( "SYS", "Could not stat old problem file $filename", "", "clean_up_problem_dir", "" );
            }

            # Get last modification time of file (seconds since the epoch)
            my $modification_time = $file_stat[9];
            if ( $current_epoch_time - $modification_time > $age_seconds ) {
                if ( unlink($filename) == 0 ) {
                    $self->syserrorm( "SYS", "Unlink file $filename did not succeed", "", "clean_up_problem_dir", "" );
                }
            }
        }
    }
}


=head2 $upload_helper->clean_up_repository()

Delete files in repo (only FTP?)

This method is only called from ftp_monitor...

=cut

sub clean_up_repository {
    my $self = shift;
    my $current_epoch_time = time();
    my $logger = $self->logger;
    my %dataset_institution = %{ $self->get_dataset_institution() };
    my $opendap_directory = $self->config->get('OPENDAP_DIRECTORY');

    foreach my $dataset ( keys %{ $self->all_ftp_datasets } ) {
        my $days_to_keep_files = $self->all_ftp_datasets->{$dataset};
        if ( $days_to_keep_files > 0 ) {
            if ( !defined( $dataset_institution{$dataset} ) ) {
                $self->syserrorm( "SYS", "$dataset not in any userfiler", "", "clean_up_repository", "" );
                next;
            }
            my $directory = $opendap_directory . "/" . $dataset_institution{$dataset}->{'institution'} . "/" . $dataset;
            my @files     = glob( $directory . "/" . $dataset . "_*" );
            $logger->debug("clean_up_repository directory: $directory");
            foreach my $fname (@files) {
                my @file_stat = stat($fname);
                if ( scalar @file_stat == 0 ) {
                    $self->syserrorm( "SYS", "Could not stat old repo file $fname", "", "clean_up_repository", "" );
                    next;
                }

                # Get last modification time of file (seconds since the epoch)
                my $modification_time = $file_stat[9];
                if ( $current_epoch_time - $modification_time > 60 * 60 * 24 * $days_to_keep_files ) {
                    $logger->debug($fname);
                    my @cdlcontent = &shcommand_array("ncdump -h $fname");
                    if ( length($self->shell_command_error) > 0 ) {
                        $self->syserrormm( "SYS", "Could not ncdump -h $fname", "", "clean_up_repository", "" );
                        next;
                    }
                    my $lnum = 0;
                    my $lmax = scalar @cdlcontent;
                    $logger->debug("Line count of CDL file (lmax) = $lmax");
                    while ( $lnum < $lmax ) {
                        if ( $cdlcontent[$lnum] eq 'dimensions:' ) {
                            last;
                        }
                        $lnum++;
                    }
                    $logger->debug("'dimensions:' found at line = $lnum");
                    $lnum++;
                    while ( $lnum < $lmax ) {
                        if ( $cdlcontent[$lnum] eq 'variables:' ) {
                            last;
                        }
                        $cdlcontent[$lnum] =~ s/=\s*\d+\s*;$/= 1 ;/;
                        $lnum++;
                    }
                    $logger->debug("'variables:' found at line = $lnum");
                    if ( $lnum >= $lmax ) {
                        $self->syserrorm( "SYS", "Error while changing CDL content from $fname",
                            "", "clean_up_repository", "" );
                        next;
                    }
                    open( CDLFILE, ">tmp_file.cdl" );
                    print CDLFILE join( "\n", @cdlcontent );
                    close(CDLFILE);
                    &shcommand_scalar("ncgen tmp_file.cdl -o $fname");
                    if ( length($self->shell_command_error) > 0 ) {
                        $self->syserrorm( "SYS", "Could not ncgen tmp_file.cdl -o $fname", "", "clean_up_repository", "" );
                        next;
                    }
                }
            }
        }
    }
}

=head2 $upload_helper->syserrorm( $type, $error, $uploadname, $where, $what );

Log error and move problem file

=cut

sub syserrorm {
    my $self = shift;

    my ( $type, $error, $uploadname, $where, $what ) = @_;

    #
    if ( $type eq "SYS" || $type eq "SYSUSER" ) {
        if ( $uploadname ne "" ) {

            # Move upload file to problem file directory
            $self->move_to_problemdir($uploadname);
        }
    }
    $self->syserror( $type, $error, $uploadname, $where, $what );
}

=head2 $upload_helper->syserrorm( $type, $error, $uploadname, $where, $what );

Log errors in the most complicated way possible

Apparently resets shell_command_error attr and returns blank string

=over 4

=item type

can be SYS, USER, SYSUSER ... no idea what that means

=item errmsg

could be 'NORMAL TERMINATION', in which case it's not an error after all (!)
(this is only done by ftp_monitor and upload_monitor)

=back

=cut

sub syserror {
    my $self = shift;

    my ( $type, $error, $uploadname, $where, $what ) = @_;
    my ( undef, undef, $baseupldname ) = File::Spec->splitpath($uploadname);

    if ( $type eq "SYS" || $type eq "SYSUSER" ) {
        ( my $msg = $error );# =~ s/\n/ | /g;
        my $errMsg = "$type IN: $where: $msg; ";
        $errMsg .= "Uploaded file: $uploadname; " if $uploadname;
        if ($what) {
            ( $msg = $what );# =~ s/\n/ | /g;
            $errMsg .= "Error: $msg; ";
        }
        if ($self->shell_command_error) {
            ( $msg = $self->shell_command_error );# =~ s/\n/ | /g;
            $errMsg .= "Stderr: $msg; ";
        }
        if ( $error eq 'NORMAL TERMINATION' ) {
            $self->logger->info( $errMsg );
        } else {
            if ( $type eq "SYSUSER" ) {
                $self->logger->info( $errMsg );
            } else {
                $self->logger->error( $errMsg );
            }
        }
    }
    if ( $type eq "USER" || $type eq "SYSUSER" ) {
        # warnings about the uploaded data
        $self->add_user_error("$error\nUploadfile: $baseupldname\n$what\n\n" );
    }
    $self->shell_command_error("");
}

sub html_error_file {
    my $self = shift;

    my ($dataset_name, $uerr_directory, $datestring) = @_;

    my $timecode = substr( $datestring, 8, 2 ) . substr( $datestring, 11, 2 ) . substr( $datestring, 14, 2 );
    my $name_html_errfile   = $dataset_name . '_' . $timecode . '.html';

    # need to check if file exists to avoid overwriting existing files.
    my $file_counter = 1;
    while( -f File::Spec->catfile( $uerr_directory, $name_html_errfile ) ){
        $name_html_errfile   = $dataset_name . '_' . $timecode . '_' . $file_counter . '.html';
        $file_counter++;
    }

    return $name_html_errfile;
}

=head1 DETAILED OPERATION

=head2 FTP uploads:

Uploads to the FTP area are only done by data providers having an agreement
with the data repository authority to do so. This agreement designates which
datasets the data provider will upload data to. Typically, such agreements
are made for operational data uploaded by automatic processes at the data
provider site. The names of the datasets covered by such agreements are
found in the text file [==WEBRUN_DIRECTORY==]/ftp_events described below.

The script ftp_monitor.pl will search for files at any directory level beneath the
$ftp_dir_path directory. Any file that have a basename matching glob pattern
'<dataset_name>_*' (where <dataset_name> is the name of the dataset) will
be treated as containing a possible addition to that dataset.

=head2 HTTP uploads:

Files uploaded via the web interface are processed with the upload_monitor.pl script.
Normally running as a daemon, this starts a worker which waits for events in
the job queue.

The directory structure of the HTTP upload area mirrors the directory
structure of the final data repository (the $opendap_directory defined
below). Thus, any HTTP-uploaded file will end up in a directory where both
the institution acronym and the dataset name are found in the directory
path. Even so, all file names are required to match the '<dataset_name>_*'
pattern (this requirement is enforced by the web interface).

=head2 Overall operation:

The ftp_events file contains, for each of the datasets, the hours at which
the FTP area should be checked for additions. The HTTP area will not be checked
– now all uploads must register a job in the queue system.

In order to avoid processing of incomplete files, the age of any file has
to be above a threshold. This threshold is given in the ftp_events file for
files uploaded with FTP, and may vary between datasets. For files uploaded
with HTTP, this threshold is a configurable constant ($upload_age_threshold).

Uploaded files are either individual netCDF files (or CDL files), or they are
archive files (tar) containing several netCDF/CDL files. Both file types may
be gzip compressed. The data provider may upload several files for the same
dataset within a short period of time. The digest_nc.pl script will work best
if it can, during one invocation, digest all the files uploaded during such
a period. To achieve this, the script will not process a file if any other
file are found for the same dataset that have not reached the age prescribed
by the threshold.

When a new set of files for a given dataset is found to be ready for processing
(either from the FTP area or from the HTTP area), the file names are sent to
the process_files subroutine.

The process_files subroutine will copy the files to the $work_expand directory
where any archive files are expanded. An archive file may contain a directory
tree. All files in a directory tree (and all the other files in the $work_expand
directory) are copied to another directory, $work_flat. This directory has a
flat structure (no subdirectories). A name collision arising from files with same
basename but from different parts of a directory tree, is considered an error.

Any CDL file now found in the $work_flat directory is converted to netCDF. The
set of uncompressed netCDF-files that now populate the $work_flat directory, is
sent to the digest_nc.pl script for checking.

=head1 ERROR HANDLING

Various errors may arise during this file processing operation. The errors are
divided into four different categories:

1. Errors arising from external system environment. Such errors will usually not
   occur. They will only arise if system resources are exhausted, or if anything
   happens to the file system (like permission changes on important files and
   directories). If any such error arise, the script will die and an abortion error
   message will be recorded in the system error log.

2. Internal system errors. These errors are mainly caused by failing shell commands
   (file, tar, gunzip etc.). They may also arise when any inconsistency are found
   that may indicate bugs in the script. The script will continue, but the
   processing of the offending uploaded file will be discontinued. The file will
   be moved to the F<$problem_dir_path> directory and an error message will be
   recorded in the system error log. In addition, the user will be notified
   about an internal system error that prohibited processing of the file.
   These errors may be caused by uploaded files that are corrupted,
   or not of the expected format. (Note to myself: In that case the error category
   should be changed to category 3 below).

3. User errors that makes furher prosessing of an uploaded file impossible. The
   file will be moved to the $problem_dir_path directory and an error message will
   be recorded in the system error log. In addition, the user will be notified
   with an indication of the nature of the error.

4. Other user errors. These are mainly caused by non-complience with the
   requirements found in the F<conf_digest_nc.xml> file. All such errors are conveyed
   to the user through the F<nc_usererrors.out> file. A summary of this file is
   constructed in the form of a self-explaining HTML file (using the
   print_usererrors.pl script).

All uploaded files that were processed with no errors, or with only
category 4 errors, are deleted after the expanded version of the files are
copied to the data repository. The status of the files are recorded in the
appropriate file in the u1 subdirectory of the $webrun_directory directory.

In the F<$problem_dir_path> directory the files are renamed according to the following
scheme: A 6 digit number, I<DDNNNN>, are constructed where I<DD> is the day number in
the month and I<NNNN> is starting on 0001 each new day, and increments with 1 for
each file copied to the directory. The new file name will be:

   DDNNNN_<basename>

where <basename> is the basename of the uploaded file name.

Files older than a prescribed number of days will be deleted from the
$problem_dir_path directory.

=head1 FTP events config file

The FTP events config file regulates which datasets are uploaded through
FTP, and how often this script will check for new files for these datasets.

This is a text file which must contain lines of the following format:

   dataset_name wait_minutes days_to_keep_files hour1 hour2 hour3 ...

=over 4

=item wait_minutes

The minimum age of a new ftp file. If a file has less age
than this value, the file is left for later processing.

=item days_to_keep_files

Number of days where the files are to remain
unchanged on the repository. When this period
expires, the files will be deleted and substituted
with files containing only metadata. This is done
in sub 'clean_up_repository'.
If this number == 0, the files are kept indefinitely.

=item hourN

These numbers (0-23) represents the times during a day
where checking for new files take place.

=back

For each hourN, a hash key is constructed as "dataset_name hourN" and the
corresponding value is set to wait_minutes.

=head1 SEE ALSO

L<MetNo::NcDigest>

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

__PACKAGE__->meta->make_immutable();

1;
