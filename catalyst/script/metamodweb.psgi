#!/usr/bin/env perl
use strict;
use warnings;

use FindBin;

BEGIN {
    $ENV{CATALYST_SCRIPT_GEN} = 40;

    if( !exists $ENV{METAMOD_MASTER_CONFIG } ){
        $ENV{METAMOD_MASTER_CONFIG} = "../master_config_dev.txt";
    }
}

use lib "../lib";
use lib "../../common/lib";

use MetamodWeb;
use Plack::Builder;


MetamodWeb->setup_engine('PSGI');
my $app = sub { MetamodWeb->run(@_) };

builder {
    enable "Deflater";
    $app;
};

