package MetamodWeb::Test::Helper;

use strict;
use warnings;

use DBIx::Class::QueryLog;
use DBIx::Class::QueryLog::Analyzer;
use FindBin;
use JSON;
use Log::Log4perl qw(get_logger);
use Moose;
use Try::Tiny;

use MetamodWeb::Schema::Metabase;
use MetamodWeb::Schema::Userbase;
use MetamodWeb::Utils::GenCatalystConf;

has 'master_config_file' => ( is => 'ro', default => 'master_config_test.txt' );

has 'master_config_dir' => ( is => 'ro', builder => '_build_master_config_dir' );

sub _build_master_config_dir {
    my $self = shift;

    return File::Spec->catdir( $self->catalyst_root(), 't' );
}

has 'catalyst_root' => ( is => 'ro', builder => '_build_catalyst_root' );

sub _build_catalyst_root {
    my $self = shift;

    if ( $FindBin::Bin =~ /^(.* \/ catalyst) \/ t (\/)? .* /x ) {
        return $1;
    } else {
        die "Could not determine the path to the catalyst directroy from the test script path: $FindBin::Bin";
    }

}

#
# The Metamod::Config object for the specified master config
#
has 'mm_config' => ( is => 'ro', builder => '_build_mm_config' );

sub _build_mm_config {
    my $self = shift;

    my $path = File::Spec->catfile( $self->master_config_dir, $self->master_config_file );
    return Metamod::Config->new($path);

}

#
# Directory that contains datasets that should be loaded as part of the setup process
#
has 'dataset_dir' => ( is => 'ro' );

#
# Path to the import_dataset.pl script
#
has 'import_dataset_path' => ( is => 'ro', lazy => 1, builder => '_build_import_dataset_path' );

sub _build_import_dataset_path {
    my $self = shift;

    return File::Spec->catfile( $self->catalyst_root(), '..', 'base', 'scripts', 'import_dataset.pl' );

}

#
# The connection to the Metabase
#
has 'metabase' => ( is => 'rw', lazy => 1, builder => '_build_metabase' );

sub _build_metabase {
    my $self = shift;

    my $mm_config = $self->mm_config();

    my $metabase = MetamodWeb::Schema::Metabase->connect(
        $mm_config->getDSN(),
        $mm_config->get('PG_WEB_USER'),
        $mm_config->get('PG_WEB_USER_PASSWORD')
    );

    my $query_log = DBIx::Class::QueryLog->new;
    $metabase->storage->debugobj($query_log);

    return $metabase;

}

#
# The connection to the Userbase
#
has 'userbase' => ( is => 'rw', lazy => 1, builder => '_build_userbase' );

sub _build_userbase {
    my $self = shift;

    my $conf     = $self->mm_config();
    my $userbase = MetamodWeb::Schema::Userbase->connect(
        $conf->getDSN_Userbase(),
        $conf->get('PG_WEB_USER'),
        $conf->get('PG_WEB_USER_PASSWORD')
    );

    my $query_log = DBIx::Class::QueryLog->new;
    $userbase->storage->debugobj($query_log);

    return $userbase;

}

#
# The error message from the previous error.
#
has 'errstr' => ( is => 'rw', isa => 'Str' );

sub BUILD {
    my $self = shift;

    # we enforce the order in which to initialise some of the attributes
    $self->catalyst_root();
    $self->master_config_dir();
    $self->master_config_file();
    $self->mm_config();

}

sub setup_environment {
    my $self = shift;

    $ENV{METAMOD_MASTER_CONFIG} = File::Spec->catfile( $self->master_config_dir, $self->master_config_file );
    $ENV{CATALYST_DEBUG} = 0;

    $ENV{METAMOD_LOG4PERL_CONFIG} = File::Spec->catfile($self->catalyst_root(), 't', 'log4perl_config.ini');

    return 1;
}



sub run_import_dataset {
    my $self = shift;

    my $import_script = $self->import_dataset_path;
    my $dataset_dir   = $self->dataset_dir;
    my $output        = `$import_script $dataset_dir`;

    print $output;
}

sub valid_metabase {
    my $self = shift;

    my $metabase = $self->metabase();
    return $self->_valid_base($metabase);

}

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

sub DEMOLISH {
    my $self = shift;

    my @clean_tables = qw(
        bk_describes_ds
        dataset
        dataset_location
        ds_has_md
        ga_contains_gd
        ga_describes_ds
        geographicalarea
        geometry_columns
        metadata
        numberitem
        projectioninfo
        sessions
        wmsinfo
    );

    my $dbh;
    try {
        $dbh = $self->mm_config->getDBH();
    }
    catch {
        get_logger()->error("Failed to get database handle");
    };

    if ($dbh) {
        foreach my $table (@clean_tables) {

            try {
                $dbh->do("DELETE FROM $table");
                $dbh->commit();
            }
            catch {
                get_logger()->error("Failed to delete table '$table': $_");
            };
        }

        my @reset_sequence = qw(
            dataset_ds_id_seq
        );

        foreach my $sequence (@reset_sequence) {

            try {
                $dbh->do("SELECT setval('$sequence', 1, false)");
                $dbh->commit();
            }
            catch {
                get_logger()->error("Failed to reset sequence '$sequence': $_");
            };
        }
    }

}

1;
