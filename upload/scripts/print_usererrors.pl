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

=cut

use strict;
use Data::Dumper;

#
#  Check number of command line arguments
#
if ( scalar @ARGV != 3 ) {
    print STDERR "Usage: $0 <config_file> <usererror_file> <errorinfo_file>\n";
    exit 2;
}

my $config_file    = $ARGV[0];
my $usererror_file = $ARGV[1];
my $errorinfo_file = $ARGV[2];

#
open( ERRORINFO, "<$errorinfo_file" );
my $output_html_file = <ERRORINFO>;
chomp $output_html_file;
my $uploaded_file = <ERRORINFO>;
chomp $uploaded_file;
my $upload_time = <ERRORINFO>;
chomp $upload_time;
close(ERRORINFO);

#
#  Read the content of the usererror_file. Place the lines in array @errors_found_arr:
#  Slurp in the content of a file
#
unless ( -r $usererror_file ) { die "Can not read from file: $usererror_file\n"; }
open( USERERRORS, $usererror_file );
undef $/;
my $errors_found = <USERERRORS>;
$/ = "\n";
close(USERERRORS);
my @errors_found_arr = split( /\n/, $errors_found );
push( @errors_found_arr, "" );

#
my $errorkey        = "";
my $errorproperties = "";
my $file_in_error;
my %inputhash = ();

#
# Parse the usererror_file.
#
foreach my $line (@errors_found_arr) {
    if ( $line =~ /^\s*$/ ) {

        #
        # Digest user error stored in temporary variables:
        #
        # $errorkey:         The current error_code.
        # $errorproperties:  The concatenated property lines except a "File:"
        #                    property line.
        # $file_in_error:    The value of the "File:" property, if found.
        #
        if ( length($errorkey) > 0 && length($errorproperties) > 0 ) {
            if ( !exists( $inputhash{$errorkey} ) ) {

                #
                # Create a new entry in %inputhash:
                #
                $inputhash{$errorkey}      = [];
                $inputhash{$errorkey}->[0] = {};
                $inputhash{$errorkey}->[1] = {};
            }
            $inputhash{$errorkey}->[0]->{$errorproperties} = 1;
            if ( defined($file_in_error) ) {
                $inputhash{$errorkey}->[1]->{$file_in_error} = 1;
            }
            undef $file_in_error;
            $errorkey        = "";
            $errorproperties = "";
        }
    } else {
        if ( $errorkey eq "" ) {

            #
            # The line contains the error_code:
            #
            $errorkey        = $line;
            $errorproperties = "";
        } elsif ( $line =~ /^([^:]+): (.+)$/ ) {

            #
            # The line is a property line:
            #
            my $keyword = $1;
            my $value   = $2;
            if ( $keyword eq "File" ) {
                $file_in_error = $value;
                $file_in_error =~ s:^.*/::;
            } elsif ( defined($errorproperties) ) {
                $errorproperties .= $line . "\n";
            } else {
                die '$errorproperties is undefined';
            }
        }
    }
}

# print Dumper(\%inputhash);
#
#  Read the content of the config_file. Place the lines in array @config_arr:
#  Slurp in the content of a file
#
unless ( -r $config_file ) { die "Can not read from the config file: $config_file\n"; }
open( CONFIG, $config_file );
undef $/;
my $config_content = <CONFIG>;
$/ = "\n";
close(CONFIG);
my @config_arr = split( /\n/, $config_content );

#
# Parse the config_file. The structure of this file is documented in the file
# itself.
#
# The following arrays are used to hold the parsed content of the config_file:
#
my @html_start    = ();    # The initial HTML
my @html_final    = ();    # The final HTML
my @html_errcodes = ();    # Error codes
my @html_errors   = ();    # HTML corresponding to the error codes. Indexed
                           # as @html_errcodes.
my $errcode_index = -1;    # Index for @html_errcodes and @html_errors.

#
foreach my $line (@config_arr) {

    if ( $line !~ /^\s*$/ && substr( $line, 0, 1 ) ne '#' ) {
        my $firstchar = substr( $line, 0, 1 );
        my $rest = '';
        if ( length($line) > 2 ) {
            $rest = substr( $line, 2 );
        }
        if ( $firstchar eq "0" ) {
            push( @html_start, $rest );
        } elsif ( $firstchar eq "E" ) {
            $errcode_index++;
            $html_errcodes[$errcode_index] = $rest;
            $html_errors[$errcode_index]   = "";
        } elsif ( $firstchar eq "1" || $firstchar eq "R" ) {
            $html_errors[$errcode_index] .= $line . "\n";
        } elsif ( $firstchar eq "9" ) {
            push( @html_final, $rest );
        }
    }
}

#
#  Create hash holding all encountered file names (i.e. values of the "File:"
#  property). The keys to this hash are the file names, and the values are
#  comma-separated strings comprising references to the errors (<a href="#...">)
#
my %all_files = ();

#
#  Write to the HTML output file:
#
open( HTMLOUT, ">$output_html_file" );

#
#  Write the initial HTML:
#
foreach my $line (@html_start) {
    $line =~ s/\$\(uploadfile\)/$uploaded_file/mg;
    $line =~ s/\$\(uploadtime\)/$upload_time/mg;
    print HTMLOUT $line . "\n";
}
my $number = 1;

#
# foreach distinct error_code (from the config_file):
#
my $errcode_count = scalar @html_errcodes;
for ( my $errcode_index = 0 ; $errcode_index < $errcode_count ; $errcode_index++ ) {
    my $code = $html_errcodes[$errcode_index];
    if ( exists( $inputhash{$code} ) ) {
        my $errortexts = $html_errors[$errcode_index];
        chomp $errortexts;
        my @errortexts_arr  = split( /\n/, $errortexts );
        my $aref            = $inputhash{$code};
        my $href_properties = $aref->[0];
        my $href_files      = $aref->[1];

        #
        # Output anchor tag with label (name):
        #
        print HTMLOUT '<a name="E' . $number . '">&nbsp</a>' . "\n";

        #
        # Foreach line in the HTML-like error text taken from the config file:
        #
        foreach my $line (@errortexts_arr) {
            my $firstchar = substr( $line, 0, 1 );
            my $rest = '';
            if ( length($line) > 2 ) {
                $rest = substr( $line, 2 );
            }
            if ( $firstchar eq "1" ) {

                #
                # Substitute any occurence of the special $(number) variable with
                # the error number $number:
                #
                $rest =~ s/\$\(number\)/$number/mg;
                print HTMLOUT $rest . "\n";
            } elsif ( $firstchar eq "R" ) {

                #
                # HTML line that shall be repeated for each occurence of the error
                # in the usererror_file:
                #
                # First, divide the line into pieces, where each piece is either
                # a variable like $(Attribute), or a text that should be copied
                # unmodified to the output:
                #
                my @pieces   = ();
                my $restrest = $rest;
                while ( $restrest ne "" ) {
                    my $s1;
                    my $keyword;
                    if ( $restrest =~ /^([^\$]*)(\$\([^\$\(\)]+\))(.*)$/ ) {
                        $s1       = $1;    # First matching ()-expression
                        $keyword  = $2;
                        $restrest = $3;
                    } else {
                        $s1       = $restrest;
                        $restrest = "";
                        $keyword  = "";
                    }
                    push( @pieces, $s1 );
                    if ( $keyword ne "" ) {
                        push( @pieces, $keyword );
                    }
                }

                #
                # Next, loop through all distinct property-strings that were
                # encountered for the current error_code in the usererror_file.
                # One property-string is a concatenation of newline-separated
                # "Property: value" pairs.
                #
                my $separator = '';
                foreach my $propertystring ( sort( keys %$href_properties ) ) {
                    chomp $propertystring;

                    #
                    # Convert the $propertystring to a hash:
                    #
                    my %properties_hash = ();
                    foreach my $property ( split( /\n/, $propertystring ) ) {
                        if ( $property =~ /^([^:]+): (.*)$/ ) {
                            my $keyword = $1;    # First matching ()-expression
                            my $value   = $2;
                            $properties_hash{$keyword} = $value;
                        }
                    }
                    print HTMLOUT $separator;

                    #
                    # Loop through the pieces of the HTML-like template line:
                    #
                    foreach my $piece (@pieces) {
                        if ( substr( $piece, 0, 1 ) eq '$' ) {
                            if ( $piece =~ /^\$\(([^():]+)\)$/ ) {

                                #
                                # This piece is a variable of the form: $(Property)
                                #
                                my $property = $1;    # First matching ()-expression
                                if ( exists( $properties_hash{$property} ) ) {
                                    print HTMLOUT $properties_hash{$property};
                                } else {
                                    print HTMLOUT '&nbsp;';
                                }
                            } elsif ( $piece =~ /^\$\(separator:([^():]+)\)$/ ) {

                                #
                                # This piece is a special variable: $(separator:xxx)
                                #
                                $separator = $1;      # Matching ()-expression (i.e. xxx)
                            }
                        } else {

                            #
                            # This piece is ordinary text
                            #
                            print HTMLOUT $piece;
                        }
                    }
                    print HTMLOUT "\n";
                }
            }
        }
        foreach my $filename ( keys %$href_files ) {
            if ( exists( $all_files{$filename} ) ) {
                $all_files{$filename} .= ', <a href="#E' . $number . '">' . $number . '</a>';
            } else {
                $all_files{$filename} = '<a href="#E' . $number . '">' . $number . '</a>';
            }
        }
        $number++;
    } elsif ( $code eq 'FILES' ) {
        my $errortexts = $html_errors[$errcode_index];
        chomp $errortexts;
        my @errortexts_arr = split( /\n/, $errortexts );

        #
        # Foreach line in the HTML-like error text taken from the config file:
        #
        foreach my $line (@errortexts_arr) {
            my $firstchar = substr( $line, 0, 1 );
            my $rest = '';
            if ( length($line) > 2 ) {
                $rest = substr( $line, 2 );
            }
            if ( $firstchar eq "1" ) {
                print HTMLOUT $rest . "\n";
            } elsif ( $firstchar eq "R" ) {

                #
                # HTML line that shall be repeated for each encountered value of the
                # File property (i.e. filenames) in the usererror_file:
                #
                # First, divide the line into pieces, where each piece is either
                # a variable like $(file), or a text that should be copied
                # unmodified to the output:
                #
                my @pieces   = ();
                my $restrest = $rest;
                while ( $restrest ne "" ) {
                    my $s1;
                    my $keyword;
                    if ( $restrest =~ /^([^\$]*)(\$\([^\$\(\)]+\))(.*)$/ ) {
                        $s1       = $1;    # First matching ()-expression
                        $keyword  = $2;
                        $restrest = $3;
                    } else {
                        $s1       = $restrest;
                        $restrest = "";
                        $keyword  = "";
                    }
                    push( @pieces, $s1 );
                    if ( $keyword ne "" ) {
                        push( @pieces, $keyword );
                    }
                }

                #
                # Next, loop through all file names encountered in the usererror_file:
                #
                my $separator = '';
                foreach my $filename ( sort( keys %all_files ) ) {
                    print HTMLOUT $separator;

                    #
                    # Loop through the pieces of the HTML-like template line:
                    #
                    foreach my $piece (@pieces) {
                        if ( substr( $piece, 0, 1 ) eq '$' ) {
                            if ( $piece eq '$(file)' ) {
                                print HTMLOUT $filename;
                            } elsif ( $piece eq '$(numberreferences)' ) {
                                print HTMLOUT $all_files{$filename};
                            } elsif ( $piece =~ /^\$\(separator:([^():]+)\)$/ ) {

                                #
                                # This piece is a special variable: $(separator:xxx)
                                #
                                $separator = $1;    # Matching ()-expression (i.e. xxx)
                            }
                        } else {

                            #
                            # This piece is ordinary text
                            #
                            print HTMLOUT $piece;
                        }
                    }
                    print HTMLOUT "\n";
                }
            }
        }
    }
}

#
#  Write the final HTML:
#
foreach my $line (@html_final) {
    print HTMLOUT $line . "\n";
}
close(HTMLOUT);

# END

=head1 NAME

print_usererrors.pl

=head1 USAGE

Processes the usererror file. This file has the following structure:

One user error is a sequence of non-empty lines. The first empty line
marks the end of the user error:

   error_code              <--- allways the first line in the sequence
   Property: value         <--- "Property" and "value" have various content
   Property: value
   ...
   <empty line>

Build the %inputhash, which is a more structured
version of the usererror_file. This hash has the following content:

For each distinct error_code found in the usererror_file, a corresponding
entry in %inputhash is found:

   $inputhash{error_code}

This entry is a reference to an anonymous array of two elements:

   ->[0]:   A reference to an anonymous hash ($href_properties):

            This hash has one entry for each user error with the given
            error_code. The key for one entry is a concatenation of the
            property lines (newlines included) of the user error. "File:"
            property lines are not included in the key.

   ->[1]:   A reference to an anonymous hash ($href_files):

            Also a hash with one entry for each user error with the given
            error_code. A key to this hash is the value of the "File:"
            property found for the given error_code.

   For both hashes, the values for any entry is "1", and ignored.

=cut
