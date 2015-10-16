package Metamod::Test::Setup;

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
use Carp;

use DBIx::Class::QueryLog;
use DBIx::Class::QueryLog::Analyzer;
use FindBin;
use JSON;
use Log::Log4perl qw(get_logger);
use Moose;
use Try::Tiny;

use Metamod::DBIxSchema::Metabase;
use Metamod::DBIxSchema::Userbase;

=head1 NAME

Metamod::Test::Setup - Module that helps initialise the environment for testing.

=head1 DESCRIPTION

Mainly routines for setting up database for unit tests.
Must be told which config file to use when initialized.

=head1 SYNOPSIS

    my $config_file = "$FindBin::Bin/../../master_config.txt";
    my $test_setup  = Metamod::Test::Setup->new( master_config_file => $config_file );
    my $config      = $test_setup->mm_config();
    my $metabase    = $test_setup->metabase();

=head1 ATTRIBUTES

=over 4

=item master_config_file

Path to config dir

=item mm_config

# The Metamod::Config object for the specified master config

=item dataset_dir

Directory that contains datasets that should be loaded as part of the setup process

=item import_dataset_path

Path to the import_dataset.pl script

=item metabase

The connection to the Metabase

=item userbase

The connection to the Userbase

=item errstr

The error message from the previous error

=back

=cut

has 'master_config_file' => ( is => 'ro', required => 1 );
has 'mm_config' => ( is => 'ro', builder => '_build_mm_config' );
has 'dataset_dir' => ( is => 'ro' );
has 'import_dataset_path' => ( is => 'ro', lazy => 1, builder => '_build_import_dataset_path' );
has 'metabase' => ( is => 'rw', lazy => 1, builder => '_build_metabase' );
has 'userbase' => ( is => 'rw', lazy => 1, builder => '_build_userbase' );
has 'errstr' => ( is => 'rw', isa => 'Str' );

sub _build_mm_config {
    my $self = shift;

    my $conf = $self->master_config_file or die "Master config not specified!";
    confess "Missing config file: " . $conf unless -f -s -r $conf;
    my $path = File::Spec->catfile( $conf ) or die "No has cheezburger"; # Why cat when only one param?
    my $config = Metamod::Config->new($path);
    get_logger()->info("Metamod::Test::Setup using $path");
    return $config;
}

sub _build_import_dataset_path {
    my $self = shift;

    if ( $FindBin::Bin =~ /^(.* \/ catalyst|common) \/ t (\/)? .* /x ) {
        return File::Spec->catfile( $1, '..', 'base', 'scripts', 'import_dataset.pl' );
    } else {
        die "Could not determine the path to the catalyst directroy from the test script path: $FindBin::Bin";
    }

}

sub _build_metabase {
    my $self = shift;

    my $conf = $self->mm_config();

    my $metabase = Metamod::DBIxSchema::Metabase->connect(
        $conf->getDSN(),
        $conf->get('PG_ADMIN_USER'),
        $conf->has('PG_ADMIN_USER_PASSWORD') ? $conf->get('PG_ADMIN_USER_PASSWORD') : ''
    );

    my $query_log = DBIx::Class::QueryLog->new;
    $metabase->storage->debugobj($query_log);

    return $metabase;

}

=head1 METHODS

=cut

sub _build_userbase {
    my $self = shift;

    my $conf     = $self->mm_config();
    my $userbase = Metamod::DBIxSchema::Userbase->connect(
        $conf->getDSN_Userbase(),
        $conf->get('PG_ADMIN_USER'),
        $conf->has('PG_ADMIN_USER_PASSWORD') ? $conf->get('PG_ADMIN_USER_PASSWORD') : ''
    );

    my $query_log = DBIx::Class::QueryLog->new;
    $userbase->storage->debugobj($query_log);

    return $userbase;

}

=head2 $self->run_import_dataset()

Blah blah blah

=cut

sub run_import_dataset {
    my $self = shift;

    my $import_script = $self->import_dataset_path;
    my $dataset_dir   = $self->dataset_dir;
    my $config_path   = File::Spec->catfile($self->mm_config->config_dir, $self->master_config_file);
    my $output        = `$import_script --config $config_path $dataset_dir`;

    print $output;

}

=head2 $self->valid_metabase()

Blah blah blah

=cut

sub valid_metabase {
    my $self = shift;

    my $metabase = $self->metabase();
    return $self->_valid_base($metabase);

}

=head2 $self->valid_userbase()

Blah blah blah

=cut

sub valid_userbase {
    my $self = shift;

    my $userbase = $self->userbase();
    return $self->_valid_base($userbase);

}

sub _valid_base {
    my $self = shift;

    my ( $dbic_schema ) = @_;

    my $success = try {
        $dbic_schema->storage()->ensure_connected();
        return 1;
    }
    catch {

        # need to stringify the DBIx::Class::Exception object otherwise the validation
        # fails.
        my $error = "$_";

        $self->errstr($error);
        return;
    };

    return $success;

}

=head2 $self->get_query_log($schema)

Blah blah blah

=cut

sub get_query_log {
    my $self = shift;

    my ($schema) = @_;

    my $query_log = $schema->storage->debugobj();
    my $ana = DBIx::Class::QueryLog::Analyzer->new({ querylog => $query_log });

    # We use SQL::Beautify to get more readable SQL if it is available, but we
    # do not want to have SQL::Beautify as a requirement for MetamodWeb
    my $beautifier;
    try {
        require SQL::Beautify;
        $beautifier = SQL::Beautify->new();
    };

    my $queries = $ana->get_totaled_queries();
    my $log_string = '';
    while( my ( $sql, $info ) = each %$queries ){

        if( $beautifier){
            $beautifier->query($sql);
            $sql = $beautifier->beautify();
        }

        my $sql_msg = <<END_MSG;
SQL:
$sql
count: $info->{ count }
time_elapsed: $info->{ time_elapsed }
END_MSG

        $log_string .= $sql_msg;
    }

    return $log_string;

}

=head2 $self->populate_metabase($dump_file)

Populate the metabase with the contents of a SQL dump file.

=over

=item $dump_file

Path to the sql dump file.

=item return

Return true on success and false otherwise. If there is an error it also sets errstr().

=back

=cut

sub populate_metabase {
    my $self = shift;

    my ($dump_file) = @_;

    #print STDERR "Trying to read $dump_file";

    my $success = $self->populate_database($dump_file, 'metamod_unittest' );

    return $success;

}

=head2 $self->populate_userbase($dump_file)

Populate the userbase with the contents of a SQL dump file.

=over

=item $dump_file

Path to the sql dump file.

=item return

Return true on success and false otherwise. If there is an error it also sets errstr().

=back

=cut

sub populate_userbase {
    my $self = shift;

    my ($dump_file) = @_;

    my $success = $self->populate_database( $dump_file, 'metamod_unittest_userbase' );

    return $success;

}

=head2 $self->populate_database( $dump_file, $db_name )

Populate the database based on a PostgreSQL dump file.

=over 4

=item $dump_file

A PostgreSQL dump file that is used to populate the database. This dump file
should B<NOT> contain any structure commands (DDL), only data.

=item $db_name

The name of the database.

=item return

Returns false on success and an error message otherwise.

=back

=cut

sub populate_database {
    my $self = shift;

    my ( $dump_file, $db_name ) = @_;

    my $output_file = "$FindBin::Bin/postgresql.out";

    my $command = "psql -U admin --dbname $db_name --file $dump_file -o $output_file";
    my $success = system $command;

    if ( $? == -1 ) {
        $self->errstr("Failed to execute '$command': $!\n");
        return;
    } elsif ( $? & 127 ) {
        $self->errstr("PostgreSQL command died with a signal\n");
        return;
    } else {
        return 1;
    }
}

sub DEMOLISH {
    my $self = shift;

    my ( $is_global_destruction ) = @_;

    # under global destruction we have no controll over which attributes will still be
    # defined and therefore cleanup might not work.
    # You should rather call "undef" on the object before the script ends.
    if( $is_global_destruction ){
        print STDERR "We are in global destruction. Cleanup of database might fail!\n";
    }

    $self->clean_metabase();
    $self->clean_userbase();

}

=head2 $self->clean_metabase()

Cleans the metabase be deleting all data from the tables that do not contain
configuration data. Also resets sequences.

=cut

sub clean_metabase {
    my $self = shift;

    my @clean_tables = qw(
        bk_describes_ds
        dataset
        dataset_location
        ds_has_md
        metadata
        numberitem
        oaiinfo
        projectioninfo
        wmsinfo
        sru.meta_contact
        sru.products
    );
    # geometry_columns must not be deleted since it's part of postgis
    # table 'sessions' doesn't exist

    my @reset_sequences = qw(
        dataset_ds_id_seq
        sru.meta_contact_id_contact_seq
    );

    try {
        my $metabase_schema = $self->metabase();
        my $dbh = $metabase_schema->storage()->dbh();

        $self->_clean_database($dbh, \@clean_tables, \@reset_sequences)
    }
    catch {
        get_logger()->error("Failed to clean metabase: $_");
    };

}

=head2 $self->clean_userbase()

Clean the userbase by deleting data from all tables and resetting all sequences.

=cut

sub clean_userbase {
    my $self = shift;

    my @clean_tables = qw(
        dataset
        error
        exitstatus
        file
        funcmap
        infods
        infou
        infouds
        job
        note
        userrole
        usertable
    );

    my @reset_sequences = qw(
        dataset_ds_id_seq
        funcmap_funcid_seq
        infods_i_id_seq
        infou_i_id_seq
        infouds_i_id_seq
        job_jobid_seq
        usertable_u_id_seq
    );

    try {
        my $userbase_schema = $self->userbase();
        my $dbh = $userbase_schema->storage()->dbh();
        $self->_clean_database($dbh, \@clean_tables, \@reset_sequences)
    }
    catch {
        get_logger()->error("Failed to clean userbase: $_");
    };

}

sub _clean_database {
    my $self = shift;

    my ($dbh, $tables, $sequences) = @_;


    foreach my $table (@$tables) {

        try {
            $dbh->do("DELETE FROM $table");
        }
        catch {
            get_logger()->error("Failed to delete table '$table': $_");
        };
    }

    foreach my $sequence (@$sequences) {

        try {
            $dbh->do("SELECT setval('$sequence', 1, false)");
        }
        catch {
            get_logger()->error("Failed to reset sequence '$sequence': $_");
        };
    }
}

1;

=head1 AUTHOR

Oystein Torget, E<lt>oysteint@met.noE<gt>

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut
