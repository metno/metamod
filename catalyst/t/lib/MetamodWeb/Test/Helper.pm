package MetamodWeb::Test::Helper;

use strict;
use warnings;
use Carp;

use FindBin;
use Log::Log4perl qw(get_logger);
use Moose;
use Try::Tiny;

use Metamod::DBIxSchema::Metabase;
use Metamod::DBIxSchema::Userbase;

extends 'Metamod::Test::Setup';

has 'master_config_file' => ( is => 'ro', default => 'master_config_test.txt' );
#has 'master_config_file' => ( is => 'ro' ); # the default is seriously obsolete and cannot be used as is

has 'master_config_dir' => ( is => 'ro', lazy => 1, builder => '_build_master_config_dir' );

sub _build_master_config_dir {
    my $self = shift;

    return File::Spec->catdir( $self->catalyst_root(), 't' );
}

has 'catalyst_root' => ( is => 'ro', builder => '_build_catalyst_root' );

sub _build_catalyst_root {
    my $self = shift;

    if ( $FindBin::Bin =~ /^(.* \/ catalyst) \/ t (\/)? .* /x ) {
        #print STDERR "Catalyst dir = '$1'\n";
        return $1;
    } else {
        die "Could not determine the path to the catalyst directory from the test script path: $FindBin::Bin";
    }

}

#
# Override the standard way of building Metamod::Config
#
sub _build_mm_config {
    my $self = shift;

    my $path = File::Spec->catfile( $self->master_config_dir, $self->master_config_file );
    die "Can't find master_config in $path" unless -s $path;
    return Metamod::Config->new($path);
}

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

1;
