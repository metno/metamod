#!/usr/bin/env perl
use strict;
use warnings;

use FindBin;

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

