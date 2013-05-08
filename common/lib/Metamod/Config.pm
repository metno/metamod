=begin licence

----------------------------------------------------------------------------
METAMOD - Web portal for metadata search and upload

Copyright (C) 2009 met.no

Contact information:
Norwegian Meteorological Institute
Box 43 Blindern
0313 OSLO
NORWAY
email: Heiko.Klein@met.no

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

=head1 NAME

Metamod::Config - get runtime configuration environment

=head1 SYNOPSIS

  use Metamod::Config;

  if(!Metamod::Config->config_found($config_file_or_dir)){
    die "Could not find the configuration on the commandline or the in the environment\n";
  }

  my $config = Metamod::Config->new($config_file_or_dir);
  my $var = $config->get("configVar");

=begin OBSOLETE?

  # initialise the logger at compile time
  use Metamod::Config qw( :init_logger );

=end OBSOLETE?

=head1 DESCRIPTION

This module can be used to read the configuration file.

=head1 FUNCTIONS

=cut

package Metamod::Config;

our $VERSION = do { my @r = (q$LastChangedRevision$ =~ /\d+/g); sprintf "0.%d", @r };
our $DEBUG = 0;

use strict;
use warnings;

use Exporter;
our %EXPORT_TAGS = ( init_logger => [] ); # hack for old scipts using Metamod::Config qw(:init_logger)

use Carp qw(cluck croak carp confess);
use Data::Dumper;

#use Data::Dumper;
use File::Basename;
use FindBin;
use File::Spec qw();
use Cwd qw();
# read ABS_PATH early, in case somebody uses a chdir
use constant ABS_PATH => Cwd::abs_path(__FILE__);
BEGIN {
    die "cannot get abs_path from ".__FILE__ unless ABS_PATH;
}

our $_config; #_config{file} => $config

# we only initialise the logger once during the entire run. Different configuration
# files cannot have their own logger config.
our $_logger_initialised;

=head2 new([configfilename], [options]) (is this up to date?)

Initialize the configuration with a config-file. If no config-file is given,
the environment-variable METAMOD_MASTER_CONFIG will be used (useful for testing),
otherwise, the default config-file located in '../../master_config.txt' relative to the
installation of Metamod::Config will be used.

This function will die if the config-file cannot be found.

This function makes sure, that each config-file will only be opened once, even
if the same config file is opened several times.

=head3 Options

=over 4

=item nolog

Skip logging initialization

=back

=cut

sub new {
    my ($class, $file_or_dir, $options) = @_;

    # we already have an object so use that instead.
    return $_config if defined $_config;

    # The environment is only used if the parameter is not supplied.
    if( !$file_or_dir && exists $ENV{METAMOD_MASTER_CONFIG} && $ENV{METAMOD_MASTER_CONFIG} ){
        $file_or_dir = $ENV{METAMOD_MASTER_CONFIG};
    }

    confess "You must supply the path to the configuration directory or the master_config.txt file" if !$file_or_dir;

    my $config_file;
    if( -d $file_or_dir ){
        $config_file = File::Spec->catfile($file_or_dir, 'master_config.txt');
    } else {
        $config_file = $file_or_dir;
    }


    # check file is readable
    if ((! -f $config_file) and (! -r $config_file)) {
        die "Cannot read config-file: $config_file";
    }

    $config_file = _normalizeFile($config_file);

    my $config = {
        mtime => '0',
        filename => $config_file,
        vars => {}, # lazy loading on first get
    };
    $_config = bless $config, $class;
    $_config->initLogger unless $$options{nolog};

    return $_config;
}

sub instance {
    my $class = shift;

    confess "You must call new() once before you can call instance()" if !defined $_config;

    return $_config;

}

=head2 _reset_singleton()

Undefs the current singleton object. The B<ONLY> reason to use this is for testing of
the class it self.

=cut

sub _reset_singleton {
    my $class = shift;

    $_config = undef
}

=head2 $class->config_found($file_or_dir)

Check if the class can find a config either in the supplied parameter or the
enviroment. Dies if the found config does not actually exist.

=over

=item $file_or_dir

A variable (possibly empty) with the path to the config file or directory.

=item return

Returns the path to the config file. If $file_or_dir is a file or directory the
parameter is returned. If that variable is empty the value of METAMOD_MASTER_CONFIG
is returned.

=back

=cut

sub config_found {
    my $class = shift;

    my ($config_file) = @_;

    if( $config_file ){

        if( ! -e $config_file ){
            confess "Config file or directory was given, but it does not exist: " . $config_file;
        }

        return $config_file;
    }

    if( exists $ENV{METAMOD_MASTER_CONFIG} ){

        if( ! -e $ENV{METAMOD_MASTER_CONFIG} ){
            confess "METAMOD_MASTER_CONFIG environment variable set but file does not exist: "
                . $ENV{METAMOD_MASTER_CONFIG};
        }

        return $ENV{METAMOD_MASTER_CONFIG}
    }

    return;
}

## get the file from METAMOD_MASTER_CONFIG or in (source|target)/master_config.txt
#sub _getDefaultConfigFile {
#    # allow the use of none standard location of the config file. This is functionality
#    # is meant primarily for unit testing purposes
#    if ( exists $ENV{ METAMOD_MASTER_CONFIG } ) {
#        # no, we can't use log4perl since haven't been initialized yet
#        #printf STDERR "Config file set in ENV to %s\n", $ENV{ METAMOD_MASTER_CONFIG };
#        return $ENV{ METAMOD_MASTER_CONFIG };
#    }
#    my ($vol, $dir, undef) = File::Spec->splitpath(ABS_PATH());
#    my @dirs = File::Spec->splitdir($dir);
#    pop @dirs; # remove last /
#    print STDERR "dir of Metamod: ".scalar @dirs." ". File::Spec->catdir(@dirs). " $dir\n" if $DEBUG;
#    # go up to dirs
#    pop @dirs;
#    print STDERR "dir of intermediate: ".scalar @dirs." ". File::Spec->catdir(@dirs)."\n" if $DEBUG;
#    pop @dirs;
#    print STDERR "dir of master_config: ".scalar @dirs." ". File::Spec->catdir(@dirs)."\n" if $DEBUG;
#    return File::Spec->catpath($vol, File::Spec->catdir(@dirs), 'master_config.txt');
#}

# normalize the filename
sub _normalizeFile {
    my ($file) = @_;
    return Cwd::abs_path($file);
}

=head2 get("configVar")

return the configuration variable configVar as currently set. This will reread the
config-file each time it has been changed. Gives a warning if not specified in
master_config.

=cut

sub get {
    my ($self, $var) = @_;
    return undef unless $var;

    $self->_checkFile();
    return $self->_substituteVariable($var); # OK, where is the warning triggered?
}

=head2 getall

returns all configuration variables as a hash

=cut

sub getall {
    my ($self) = @_;

    $self->_checkFile();
    my %vars;
    foreach (keys $self->{vars}) {
        $vars{$_} = $self->_substituteVariable($_)
    }
    return \%vars;
}

=head2 has("configVar")

return true if the configuration variable configVar is currently set. This will reread the
config-file each time it has been changed. Does not give any warnings.

=cut

sub has {
    my ($self, $var) = @_;
    return undef unless $var;

    $self->_checkFile();
    return exists $self->{vars}{$var};
}

=head2 is("configVar")

return true if the configuration variable has been set and is not among a list of
false values (0, false, empty string). Does not give any warnings.

=cut

sub is {
    my ($self, $var) = @_;
    return undef unless $var;

    $self->_checkFile();
    return undef unless exists $self->{vars}{$var};
    my $val = $self->_substituteVariable($var);
    #printf STDERR "Config boolean %s = %s\n", $var, $val;
    return ($val && lc($val) ne 'false') ? 1 : 0;
}

=head2 split

Splits a config variable table into a hash of key/value pairs.
Value is either a string or a list of strings.

=cut

sub split {
    my ($self, $var) = @_;
    return undef unless $var;

    my $input = $self->get($var) or return;
    $input =~ s|^\n||; # skip initial blank line
    my @lines = split '\n', $input;

    my %items = ();
    foreach (@lines) {
        s/^\s+//; # remove leading spaces
        #print STDERR "> $_\n";
        my $list =_splitval($_);
        my $key = shift $list; # treat first item as the key
        $items{$key} = (scalar @$list > 1) ? $list : shift $list; # string or list if > 1
    }

    #print STDERR Dumper \%items;
    return \%items;
}

sub _splitval {
    my $_ = shift or return;
    my @vals = ();
    s/^\s+//; # remove leading spaces
    #print STDERR " '$_'\n";
    if ( /^["](.+?)["](.*)$/ or /^['](.+?)['](.*)$/ or /^(\S+)(\s+(.*))?$/ ) {
        return $1 unless $2;
        #print STDERR " |$1|$2|\n";
        push @vals, $1;
        my $rest = _splitval($2);
        push @vals, ref $rest ? @{ $rest } : $rest if defined $rest;
    }
    #print STDERR Dumper \@vals;
    return \@vals;
}

    ## check if there are any single quotes, if so we use them to split. Otherwise we just split by space
    #if ( index( $value, "'" ) ) {
    #    my $extra_params;
    #    ( $mt_name, $shown_name, $extra_params ) = map { $self->trim($_) } split "'", $column;
    #    @extra_params = split " ", $extra_params if $extra_params;
    #} else {
    #    ( $mt_name, $shown_name, @extra_params ) = map { $self->trim($_) } split " ", $column;
    #}
    #
    #my %column_info = ( mt_name => $mt_name, shown_name => $shown_name );
    #
    ## add each extra parameter as its own key/value pair
    #foreach my $param (@extra_params) {
    #    my ( $param_type, $param_value ) = split '=', $param;
    #    $column_info{$param_type} = $param_value;
    #}
    #
    #$items{$key} = $value;
    #

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

    my $default_config = $self->path_to_config_file('default_config.txt');

    my %conf;
    for my $filename (($default_config, $self->{filename})) {

        open my $fh, '<', $filename or confess "Cannot read file".$filename.": $!\n";
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
        close $fh;
    }


    $self->{vars} = \%conf;
}

# get a variable from env or the internal hash, without substitution
sub _getVar {
    my ($self, $var) = @_;

    if (exists $ENV{"METAMOD_".$var}) {
        return $ENV{"METAMOD_".$var};
    }

    if( $var eq 'CONFIG_DIR' ){
        return $self->config_dir();
    } elsif( $var eq 'INSTALLATION_DIR') {
        return $self->installation_dir();
    }

    if (!exists $self->{vars}{$var}) {
        if ($_logger_initialised) {
            Log::Log4perl::get_logger('metamod::common::Metamod::Config')->logcarp("missing config variable in master_config.txt: $var");
        } else {
            carp("missing config variable in master_config.txt: $var");
        }
    }
    return $self->{vars}{$var};
}

# substitute intrinsic values from config
sub _substituteVariable {
    my ($self, $var) = @_;

    return $self->_getVar($var) unless $self->_getVar($var); # return undef/empty

    my $textline = $self->_getVar($var);

    my $maxSubst = 40;
    my $substNo = 0;
    # replace variable with the config-values recursively
    while ($textline =~ s/\[==([A-Z0-9_]+)==\]/$self->_getVar($1)/e && (++$substNo < $maxSubst)) {
        # everything done in loop-header
    }
    if ($substNo >= $maxSubst) {
        die "Circular substitutions in ".$self->{filename}." in $textline\n";
    }
    return $textline;
}

=head2 getDSN()

Return the database source name of the metadata database,
i.e. "dbi:Pg:dbname=damocles;host=localhost;port=5432"

=cut

sub getDSN {
    my ($self) = @_;
    my $dbname = $self->get("DATABASE_NAME");
    my $pgConnectString =  $self->get("PG_CONNECTSTRING_PERL");
    my $dsn = "dbi:Pg:dbname=" . $dbname;
    if ($pgConnectString) {
        $dsn .= ";$pgConnectString"
    }
    return $dsn;
}

=head2 getDSN_Userbase

Return the database source name of the user-database,
i.e. "dbi:Pg:dbname=userbase;host=localhost;port=5432"

=cut

sub getDSN_Userbase {
    my ($self) = @_;
    my $dbname = $self->get("USERBASE_NAME");
    my $pgConnectString =  $self->get("PG_CONNECTSTRING_PERL");
    my $dsn = "dbi:Pg:dbname=" . $dbname;
    if ($pgConnectString) {
        $dsn .= ";$pgConnectString"
    }
    return $dsn;
}

=head2 getDBH()

Return a cached/pooled DBI-handler to the default database of metamod. The handler is in
AutoCommit = 0 and RaiseError = 1, FetchHash mode. This function will die on error. (DBI-connect error)

disconnect will free the database. Be careful when using getDBH and transactions.
A call to getDBH will commit a transaction, and cached connections might be used
several places.

=cut

sub getDBH {
    my ($self) = @_;
    require DBI;
    my $user   = $self->get("PG_ADMIN_USER");
    my $dsn = $self->getDSN();
    my $dbh =  DBI->connect_cached($dsn,
                                   $user, "",
                                   {AutoCommit => 0,
                                    RaiseError => 1,
                                    FetchHashKeyName => 'NAME_lc',
                                   } );
    return $dbh;
}


=head2 initLogger()

Initialise a Log::Log4perl logger.

=cut

sub initLogger {
    my ($self) = @_;

    return if( $_logger_initialised );

    my $config_file = $self->{filename};
    my $config_dir = dirname($config_file);

    my $log_config = File::Spec->catfile($config_dir,'log4perl_config.ini');

    if(exists $ENV{METAMOD_LOG4PERL_CONFIG} && $ENV{METAMOD_LOG4PERL_CONFIG}){
        $log_config = $ENV{METAMOD_LOG4PERL_CONFIG};
    }

    my $system_log = $self->get( 'LOG4ALL_SYSTEM_LOG' );
    my $reinit_period = $self->get( 'LOG4PERL_WATCH_TIME' ) || 10;

    if( !$log_config ) {
        die 'Missing LOG4PERL_CONFIG variable in the config file';
    }

    if( !( -r $log_config ) ){
        croak "Cannot read from '$log_config'";
    }

    $ENV{ 'METAMOD_SYSTEM_LOG' } = $system_log;

    require Log::Log4perl;
    Log::Log4perl->init_and_watch( $log_config, $reinit_period );

    $_logger_initialised = 1;
    return 1;


}

=head2 $self->config_dir()

Get the directory that the master config file is located in. Can be used to get
paths relative to the config file.

=over

=item return

The path to the directory containing the configuration file.

=back

=cut

#=head2 staticInitLogger([$path_to_master_config])
#
#Static/class version of C<initLogger()>. Will first create a config object
#and then initialise the logger with C<initLogger()>.
#
#The $path_to_master_config parameter is optional and if not supplied the default master config
#will be used.
#
#=cut

sub config_dir {
    my $self = shift;

    my ($dummy, $config_dir, $dummy2) = fileparse($self->{filename});
    return Cwd::abs_path($config_dir);

}

=head2 $self->installation_dir()

Get the absolute path to the directory where the METAMOD application is installed.

=over

=item return

Returns the absolute path to the directory where METAMOD is installed. Throws an exception if
the location cannot be determined.

=back

=cut

sub installation_dir {
    my $self = shift;

    my $tries_counter = 0;
    my $curr_dir = $FindBin::Bin;

    while( !(-d File::Spec->catdir( $curr_dir, 'common'))){

        # try one level up
        $curr_dir = File::Spec->catdir($curr_dir, '..');
        $tries_counter++;

        if( $tries_counter > 10 ){
            die 'Could not determine installation dir';
        }
    }

    return Cwd::abs_path($curr_dir);
}

=head2 $self->getVarNames()

=over

=item return

A list of all the variables names in the configuration file.

=back

=cut

sub getVarNames {
    my $self = shift;

    $self->_checkFile();
    my @var_names = keys %{ $self->{vars} };

    push @var_names, 'CONFIG_DIR';
    push @var_names, 'INSTALLATION_DIR';

    return @var_names;
}

=head2 $self->getDSFilePath($ds_name)

Get the file path to where the XML metadata files are stored on disk.

This method will die if one of the directories on the path to the file is not
readable.

=over

=item $ds_name

The name of the dataset on the form '<application>/<dataset name>' or
'<application>/<parent name>/<dataset name>'

=item return

The path to the B<basename> of the XML metadata files. I.e. the .xml or .xmd
ending is not part of it.

=back

=cut

sub getDSFilePath {
    my $self = shift;

    my ($ds_name) = @_;

    my $webrun_dir = $self->get('WEBRUN_DIRECTORY');

    my @dirs = File::Spec->splitdir($ds_name);
    my $base_filename = pop @dirs;
    unshift @dirs, 'XML';
    unshift @dirs, $webrun_dir;

    my $path = '';
    foreach my $dir (@dirs) {
        $path = File::Spec->catdir($path, $dir);
        if( !(-r $path) ){
            die "Tried to find path for '$ds_name', but cannot read '$path'";
        }
    }

    my $ds_path = File::Spec->catfile(@dirs, $base_filename);
    return $ds_path;

}

=head2 $self->path_to_config_file($filename, @dirnames)

Get the path to a file that is either located in the application configuration catalog
or in the config/ catalog.

=over

=item $filename

The name of the file.

=item @dirnames

A list of directory names that gives the location of the file relative to the
application config catalog or the config/ catalog.

=item return

The path to the file in the application configuration catalog if it exists.
Otherwise it returns the path to the file in the config/ catalog.

Dies if the file cannot be found any of the places.

=back

=cut

sub path_to_config_file {
    my $self = shift;

    my ( $filename, @dirnames ) = @_;

    my $path = File::Spec->catfile(@dirnames, $filename);
    if( -f File::Spec->catfile( $self->config_dir(), $path ) ){
        return File::Spec->catfile( $self->config_dir(), $path );
    } elsif( -f File::Spec->catfile( $self->installation_dir(), 'app', 'default', $path ) ) {
        return File::Spec->catfile( $self->installation_dir(), 'app', 'default', $path );
    } else {
        die "The configuration file '$path' you requested is not in the installation dir or the config dir";
    }

}

1;

=head1 AUTHOR

Heiko Klein, E<lt>H.Klein@met.noE<gt>

=head1 SEE ALSO


=cut
