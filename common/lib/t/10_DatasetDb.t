#! /usr/bin/perl
use strict;
use warnings;

use lib "..";
use Test::More tests => 9;
use Data::Dumper;

BEGIN {$ENV{METAMOD_MASTER_CONFIG} = 'master_config.txt' unless exists $ENV{METAMOD_MASTER_CONFIG};}
use Metamod::Config qw(:init_logger);

BEGIN {use_ok('Metamod::DatasetDb')};

my $obj = new Metamod::DatasetDb();
isa_ok($obj, 'Metamod::DatasetDb');

can_ok($obj, qw(get_level1_datasets get_level2_datasets find_dataset get_metadata));

my $haveDb = 0;
my $config = new Metamod::Config();
eval {$config->getDBH(); $haveDb = 1;};
SKIP: {
    skip "no database-connection", 5 unless $haveDb;
    
    my $hirlam12 = $obj->find_dataset('hirlam12');
    ok (defined $hirlam12, "find_dataset(hirlam12)");
    ok (exists $hirlam12->{ds_id}, "got ds_id hirlam12");
    
    my $level1 = $obj->get_level1_datasets;
    ok (5 < @$level1, "get_level1_datasets");
    
    my $level2hirlam = $obj->get_level2_datasets(ds_id => $hirlam12->{ds_id}, max_files => 30);
    is (scalar @$level2hirlam, 30, "get_level2_datasets with max_files restriction"); 
    my $countHash;
    foreach my $row (@$level2hirlam) {
        $countHash++ if (ref $row eq 'HASH');
    }
    is ($countHash, 30, "all level2 datasets are hash-refs");

    my @ds_ids = map {$_->{ds_id}} @$level2hirlam;
    my $metadata = $obj->get_metadata(\@ds_ids, ['title', 'PI_name']);
    is ($metadata->{$ds_ids[0]}{PI_name}[0], "IPYCOORD Team", "got metadata of hirlam12");
}