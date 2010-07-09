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
#  email: Heiko.Klein@met.no
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

package Metamod::Config;

our $VERSION = do { my @r = (q$LastChangedRevision$ =~ /\d+/g); sprintf "0.%d", @r };
our $DEBUG = 0;

use strict;
use warnings;

use File::Spec qw();
use Cwd qw();
# read ABS_PATH early, in case somebody uses a chdir
use constant ABS_PATH => Cwd::abs_path(__FILE__);
BEGIN {
    die "cannot get abs_path from ".__FILE__ unless ABS_PATH;
}

our %_config; #_config{file} => $config

# we only initialise the logger once during the entire run. Different configuration
# files cannot have their own logger config.
our $_logger_initialised;

sub new {
	my ($class, $file) = @_;
    my $fileFlag = "";
	unless ($file) {
		$file = _getDefaultConfigFile();
		$fileFlag = "default";
	}
	if ((! -f $file) and (! -r _)) {
        die "Cannot read $fileFlag config-file: $file";
	}
    $file = _normalizeFile($file);
	unless (exists $_config{$file}) {
		my $config = {
			mtime => '0',
			filename => $file,
			vars => {}, # lazy loading on first get
		};
		$_config{$file} = bless $config, $class;
	}
	return $_config{$file};
}

# get the file in ../../master_config.txt
sub _getDefaultConfigFile {
    my ($vol, $dir, undef) = File::Spec->splitpath(ABS_PATH());
    my @dirs = File::Spec->splitdir($dir);
    pop @dirs; # remove last /
    print STDERR "dir of Metamod: ".scalar @dirs." ". File::Spec->catdir(@dirs). " $dir\n" if $DEBUG;
    # go up to dirs
    pop @dirs;
    print STDERR "dir of intermediate: ".scalar @dirs." ". File::Spec->catdir(@dirs)."\n" if $DEBUG;
    pop @dirs;
    print STDERR "dir of master_config: ".scalar @dirs." ". File::Spec->catdir(@dirs)."\n" if $DEBUG;
    return File::Spec->catpath($vol, File::Spec->catdir(@dirs), 'master_config.txt');
}

# normalize the filename
sub _normalizeFile {
	my ($file) = @_;
	return Cwd::abs_path($file);
}

sub get {
	my ($self, $var) = @_;
	return undef unless $var;

	$self->_checkFile();
	return $self->_substituteVariable($var);
}

# check for updates of config and reread
sub _checkFile {
	my ($self) = @_;
	my @stat = stat $self->{filename};
	die "stat on ". $self->{filename}. " failed" unless @stat;
    my $mtime = $stat[9];
    if ($self->{mtime} < $mtime) {
    	$self->{mtime} = $mtime;
    	$self->_readConfig;
    }
}

sub _readConfig {
	my ($self) = @_;
	open my $fh, $self->{filename} or die "Cannot read file".$self->{filename}.": $!\n";
    my %conf;
    #
    #  Loop through all lines read from a file:
    my %newfilenames = ();
    my $value = "";
    my $varname = "";
    my $origname = "";
    my $newname = "";
    my $line = "";
    while (defined (my $line = <$fh>)) {
        chomp($line);
        #
        #     Check if expression matches RE:
        #
        if ($line =~ /^[A-Z0-9_#!]/ && $varname ne "") {
            if (length($origname) > 0) {
                $conf{$varname . ':' . $origname . ':' . $newname} = $value;
                $newfilenames{$origname . ':' . $newname} = 1;
            } else {
                $conf{$varname} = $value;
            }
            $varname = "";
        }
        if ($line =~ /^([A-Z0-9_]+)\s*=(.*)$/) {
            $varname = $1; # First matching ()-expression
            $value = $2; # Second matching ()-expression
            $value =~ s/^\s*//;
            $value =~ s/\s*$//;
        } elsif ($line =~ /^!substitute_to_file_with_new_name\s+(\S+)\s+=>\s+(\S+)\s*$/) {
            $origname = $1;
            $newname = $2;
        } elsif ($line =~ /^!end_substitute_to_file_with_new_name\s*$/) {
            $origname = "";
            $newname = "";
        } elsif ($line !~ /^#/ && $line !~ /^\s*$/) {
            $value .= "\n" . $line;
        }
    }
    if ($varname ne "") {
        $conf{$varname} = $value;
    }


	$self->{vars} = \%conf;
	close $fh;
}

# substitute intrinsic values from config
sub _substituteVariable {
	my ($self, $var) = @_;
	my %conf = %{ $self->{vars} };
	return $conf{$var} unless $conf{$var}; # return undef/empty

    my $textline = $conf{$var};

    my $maxSubst = 40;
    my $substNo = 0;
    # replace variable with the config-values recursively
    while ($textline =~ s/\[==([A-Z0-9_]+)==\]/$conf{$1}/ && (++$substNo < $maxSubst)) {
        # everything done in loop-header
    }
    if ($substNo >= $maxSubst) {
        die "Circular substitutions in ".$self->{filename}." in $textline\n";
    }
    return $textline;
}

sub getDBH() {
    my ($self) = @_;
    require DBI;
    my $dbname = $self->get("DATABASE_NAME");
    my $user   = $self->get("PG_ADMIN_USER");
    my $connect = "dbi:Pg:dbname=" .
                  $dbname .
                  " ".
                  $self->get("PG_CONNECTSTRING_PERL");
    my $dbh =  DBI->connect_cached($connect,
                                   $user, "",
                                   {AutoCommit => 0, RaiseError => 1} );
    return $dbh;
}

sub initLogger {
    my ($self) = @_;

    return if( $_logger_initialised );

    my $log_config = $self->get( 'LOG4PERL_CONFIG' );
    my $system_log = $self->get( 'LOG4ALL_SYSTEM_LOG' );
    my $reinit_period = $self->get( 'LOG4PERL_WATCH_TIME' ) || 10;

    if( !$log_config ) {
        die 'Missing LOG4PERL_CONFIG variable in the config file';
    }

    if( !( -r $log_config ) ){
        die "Cannot read from '$log_config'";
    }

    $ENV{ 'METAMOD_SYSTEM_LOG' } = $system_log;

    require Log::Log4perl;
    Log::Log4perl->init_and_watch( $log_config, $reinit_period );

    $_logger_initialised = 1;
    return 1;


}

sub staticInitLogger {
    my ($filename) = @_;

    my $config = __PACKAGE__->new($filename);

    return $config->initLogger();

}

sub import {
    my $package = shift;

    foreach my $parameter ( @_ ){

        if( $parameter =~ /:init_logger/ ){

            my $config_file;

            # allow the use of none standard location of the config file. This is functionality
            # is meant primarily for unit testing purposes
            if( exists $ENV{ METAMOD_MASTER_CONFIG } ){
                $config_file = $ENV{ METAMOD_MASTER_CONFIG };
            }

            staticInitLogger($config_file);
        }
    }
}

1;
__END__

=head1 NAME

Metamod::Config - get runtime configuration environment

=head1 SYNOPSIS

  use Metamod::Config;

  my $config = new Metamod::Config("configFilePath");
  my $var = $config->get("configVar");

  # initialise the logger at compile time
  use Metamod::Config qw( :init_logger );

=head1 DESCRIPTION

This module can be used to read the configuration file.

=head1 FUNCTIONS

=over 4

=item new([configfilename])

Initialize the configuration with a config-file. If no config-file is given,
the default config-file located in '../../master_config.txt' relative to the
installation of Metamod::Config will be used.

This function will die if the config-file cannot be found.

This function makes sure, that each config-file will only be opened once, even
if the same config file is opened several times.

=head1 FUNCTIONS

=over 4

=item get("configVar")

return the configuration variable configVar as currently set. This will reread the
config-file each time it has been changed.

=item initLogger()

Initialise a Log::Log4perl logger.

=item staticInitLogger([$path_to_master_config])

Static/class version of C<initLogger()>. Will first create a config object
and then initialise the logger with C<initLogger()>.

The $path_to_master_config parameter is optional and if not supplied the default master config
will be used.

=back

=item getDBH()

<<<<<<< .mine
Return a cached/pooled DBI-handler to the default database of metamod. The handler is in 
AutoCommit = 0 and RaiseError = 1 mode. This function will die on error. (DBI-connect error)

=======


>>>>>>> .r694
=head1 AUTHOR

Heiko Klein, E<lt>H.Klein@met.noE<gt>

=head1 SEE ALSO


=cut

