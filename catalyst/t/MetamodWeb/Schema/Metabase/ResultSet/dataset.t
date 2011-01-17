#!/usr/bin/env perl
use strict;
use warnings;

use FindBin;

use lib "$FindBin::Bin/../../../../lib";
use lib "$FindBin::Bin/../../../../../lib";
use lib "$FindBin::Bin/../../../../../../common/lib";

use MetamodWeb::Test::Init;

use Test::More tests => 29;

my $init;
my $metabase;

BEGIN {
    $init = MetamodWeb::Test::Init->new(
        catalyst_root       => "$FindBin::Bin/../../../../../",
        import_dataset_path => "$FindBin::Bin/../../../../../../base/scripts/import_dataset.pl",
        dataset_dir         => "$FindBin::Bin/datasets"
    );
    $init->setup_environment();
    $metabase = $init->connect_to_metabase();
}

#Teste med s�k
# - Resultater p� bare en side
# - Resultater over flere sider. Ha f�rste side
# - Resultater over flere sider. Ikke ha f�rste side.
# - Et s�ke kriterium
# - Flere s�ke kriterium innen samme kategori
# - Flere kategorier.
# - Test alle kategorier

test_metadata_search( {}, 1, [qw( TEST/dataset4 TEST/dataset2 TEST/dataset3 )], 'No search criteria. First page' );

test_metadata_search( {}, 2, [qw( TEST/dataset1 )], 'No search criteria. Second page' );

test_metadata_search( {}, 3, [], 'No search criteria. Non existant third page' );

test_metadata_search( { basickey => [ [1616] ] }, 1, [qw( TEST/dataset2 )], 'Search for single basic key' );

test_metadata_search(
    { basickey => [ [ 1616, 1619, 1613 ] ] },
    1,
    [qw( TEST/dataset2 TEST/dataset3 TEST/dataset1 )],
    'Search for several basic keys in same category'
);

test_metadata_search(
    { basickey => [ [ 1616, 1619, 1613 ], [1605] ] },
    1,
    [qw( TEST/dataset3 TEST/dataset1 )],
    'Search for several basic keys across categories'
);

test_metadata_search( { dates => { 8 => { from => '20090101', to => '20091231' } } },
    1, [], 'Search for dates. No matching in interval' );

test_metadata_search(
    { dates => { 8 => { from => '20090101', to => '20100731' } } },
    1,
    [qw( TEST/dataset2 TEST/dataset3 TEST/dataset1 )],
    'Search for dates. Several completely enclosed by interval'
);

test_metadata_search(
    { dates => { 8 => { from => '20100102', to => '20100201' } } },
    1,
    [qw( TEST/dataset3 TEST/dataset1 )],
    'Search for dates. Start date equal to "to date"'
);

test_metadata_search( { dates => { 8 => { from => '20100102', to => '20100131' } } },
    1, [qw( TEST/dataset1 )], 'Search for dates. Start date one less than to "to date"' );

test_metadata_search(
    { dates => { 8 => { from => '20100201', to => '20100202' } } },
    1,
    [qw( TEST/dataset3 TEST/dataset1 )],
    'Search for dates. Start date equal to "from date"'
);

test_metadata_search(
    { dates => { 8 => { from => '20100205', to => '20100801' } } },
    1,
    [qw( TEST/dataset2  TEST/dataset3 TEST/dataset1 )],
    'Search for dates. Partial overlap between search dates and dataset dates'
);

test_metadata_search(
    {
        dates => { 8 => { from => '20100205', to => '20100801', } },
        basickey => [ [1616] ],
    },
    1,
    [qw( TEST/dataset2 )],
    'Search with dates and basic keys.',
);

test_metadata_search( { freetext => ['dummy_ugga_bugga'], }, 1, [], 'Free text search for text that does not exist', );

test_metadata_search(
    { freetext => ['dataset1'], },
    1, [qw( TEST/dataset1 )], 'Free text search for text that match a dataset name',
);

test_metadata_search(
    { freetext => ['Model'], },
    1,
    [qw( TEST/dataset3 TEST/dataset1 )],
    'Free text search that match the full text search vector',
);

test_metadata_search(
    { freetext => ['Model Clouds'], },
    1, [qw( TEST/dataset3 )], 'Free text search with more than one word that match against full text search vector',
);

test_metadata_search(
    {
        basickey => [ [1613] ],
        freetext => ['Model'],
    },
    1,
    [qw( TEST/dataset3 )],
    'Free text search and basickey search',
);

test_metadata_search(
    {
        coords => { srid => 93995, x1 => 455, x2 => 476, y1 => 332, y2 => 347 },
    },
    1,
    [],
    'Map search that does not match any datasets.',
);

test_metadata_search(
    {
        coords => { srid => 93995, x1 => 296, x2 => 313, y1 => 505, y2 => 517 },
    },
    1,
    [ qw( TEST/dataset1 ) ],
    'Map search that matches a single dataset.',
);

test_metadata_search(
    {
        coords => { srid => 93995, x1 => 296, x2 => 313, y1 => 505, y2 => 517 },
    },
    1,
    [ qw( TEST/dataset1 ) ],
    'Map search that matches a single dataset.',
);

test_metadata_search(
    {
        coords => { srid => 93995, x1 => 296, x2 => 363, y1 => 505, y2 => 517 },
    },
    1,
    [ qw( TEST/dataset2 TEST/dataset3 TEST/dataset1 ) ],
    'Map search that matches dataset from disjoint bounding boxes',
);

test_metadata_search(
    {
        coords => { srid => 93995, x1 => 296, x2 => 363, y1 => 505, y2 => 517 },
        basickey => [ [ 1613 ] ],
    },
    1,
    [ qw( TEST/dataset3 ) ],
    'Map search with basic key search',
);

test_metadata_search( { topics => { bk_ids => [ 10222 ] } }, 1, [], 'Search for topic bk_ids without any matches' );

test_metadata_search( { topics => { hk_ids => [ 23211 ] } }, 1, [], 'Search for topic hk_ids without any matches' );

test_metadata_search( { topics => { bk_ids => [ 809, 56 ] } }, 1, [ qw( TEST/dataset2 TEST/dataset1 )], 'Search for topic bk_ids with mathces' );

test_metadata_search( { topics => { hk_ids => [ 62, 711 ] } }, 1, [ qw( TEST/dataset3 TEST/dataset1 ) ], 'Search for topic hk_ids with mathces' );

test_metadata_search( { topics => { bk_ids => [ 809, 56 ], hk_ids => [ 711 ] } }, 1, [qw( TEST/dataset2 TEST/dataset3 TEST/dataset1 )], 'Search for both topic bk_ids and hk_ids' );

test_metadata_search( { topics => { bk_ids => [809, 56], hk_ids => [62, 711] }, freetext => [ 'dataset1' ] }, 1, [qw( TEST/dataset1 )], 'Search for both topic bk_ids and hk_id and freetext' );

sub test_metadata_search {
    my ( $search_criteria, $curr_page, $expected_names, $test_name ) = @_;

    my $dataset_rs    = $metabase->resultset('Dataset');
    my $rows_per_page = 3;
    my $ownertags     = [qw( TEST )];

    my $result = $dataset_rs->metadata_search(
        {
            curr_page       => $curr_page,
            ownertags       => $ownertags,
            rows_per_page   => $rows_per_page,
            search_criteria => $search_criteria
        }
    );

    my @actual_names = ();
    while ( my $row = $result->next() ) {
        push @actual_names, $row->ds_name();
    }

    is_deeply( \@actual_names, $expected_names, "$test_name: Dataset names" );
}