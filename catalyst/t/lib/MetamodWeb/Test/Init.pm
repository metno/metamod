package MetamodWeb::Test::Init;

use strict;
use warnings;

use FindBin;
use JSON;
use Log::Log4perl qw(get_logger);
use Moose;
use Try::Tiny;

use MetamodWeb::Schema::Metabase;
use MetamodWeb::Utils::GenCatalystConf;

has 'master_config_file' => ( is => 'ro', default => 'master_config_test.txt' );

has 'master_config_dir' => ( is => 'ro', default => "$FindBin::Bin" );

has 'catalyst_root' => ( is => 'ro', required => 1 );

#
# The Metamod::Config object for the specified master config
#
has 'mm_config' => ( is => 'ro', lazy => 1, builder => '_build_mm_config' );

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
has 'import_dataset_path' => ( is => 'ro' );

sub setup_environment {
    my $self = shift;

    $ENV{METAMOD_MASTER_CONFIG} = File::Spec->catfile( $self->master_config_dir, $self->master_config_file );
    $ENV{CATALYST_DEBUG} = 0;

    my %catalyst_conf = MetamodWeb::Utils::GenCatalystConf::catalyst_conf();
    my $json = JSON->new();
    my $json_conf = $json->pretty(1)->encode(\%catalyst_conf);

    open my $CONF, '>', $self->catalyst_conf_file or die $!;
    print $CONF $json_conf;

    $self->run_import_dataset();
}

sub catalyst_conf_file {
    my $self = shift;

    return File::Spec->catfile( $self->catalyst_root, 'metamodweb_local.json' );
}

sub run_import_dataset {
    my $self = shift;

    my $import_script = $self->import_dataset_path;
    my $dataset_dir   = $self->dataset_dir;
    my $output        = `$import_script $dataset_dir`;

    print $output;
}

sub connect_to_metabase {
    my $self = shift;

    my $mm_config = $self->mm_config();

    my $metabase = MetamodWeb::Schema::Metabase->connect( $mm_config->getDSN(), $mm_config->get('PG_WEB_USER'), $mm_config->get('PG_WEB_USER_PASSWORD' ) );

    return $metabase;

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
    } catch {
        get_logger()->error("Failed to get database handle")
    };

    if( $dbh ){
        foreach my $table (@clean_tables) {

            try {
                $dbh->do( "DELETE FROM $table" );
                $dbh->commit();
            } catch {
                get_logger()->error("Failed to delete table '$table': $_");
            };
        }

        my @reset_sequence = qw(
                dataset_ds_id_seq
        );

        foreach my $sequence (@reset_sequence) {

            try {
                $dbh->do( "SELECT setval('$sequence', 1, false)" );
                $dbh->commit();
            } catch {
                get_logger()->error("Failed to reset sequence '$sequence': $_");
            };
        }
    }

    unlink $self->catalyst_conf_file() or warn $!;

}

1;
