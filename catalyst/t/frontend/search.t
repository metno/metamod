use strict;
use warnings;
use Test::More tests => 22;
use Test::WWW::Mechanize::Catalyst;

use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../lib";
use lib "$FindBin::Bin/../../../common/lib";

use MetamodWeb::Test::Init;

my $init;

BEGIN {
    $init = MetamodWeb::Test::Init->new(
        catalyst_root       => "$FindBin::Bin/../../",
        import_dataset_path => "$FindBin::Bin/../../../base/scripts/import_dataset.pl",
        dataset_dir         => "$FindBin::Bin/datasets"
    );
    $init->setup_environment();
}

BEGIN { use_ok 'MetamodWeb' }
BEGIN { use_ok 'MetamodWeb::Controller::Search' }

my $mech = Test::WWW::Mechanize::Catalyst->new( catalyst_app => 'MetamodWeb' );
$mech->get_ok( '/search', 'Request should succeed' );

# These are basic parameters that are needed for all the search requests
my $basic_search_params = '';
$basic_search_params .= '&shown_mt_name_1=dataref';
$basic_search_params .= '&shown_mt_name_2=institution';
$basic_search_params .= '&shown_mt_name_3=area';
$basic_search_params .= '&shown_mt_name_4=activity_type';
$basic_search_params .= '&shown_mt_name_5=abstract';
$basic_search_params .= '&vertical_mt_name=area';
$basic_search_params .= '&horisontal_mt_name=activity_type';
$basic_search_params .= '&datasets_per_page=3';
$basic_search_params .= '&files_per_page=3';


$mech->get_ok( '/search/page/1/result?bk_id_2_1619=on' . $basic_search_params , 'Search with one criteria' );
$mech->text_contains('dataset1', 'Search found matching datasets');
$mech->text_unlike( qr/dataset2/, 'Search did not return non-matching dataset');

$mech->get_ok( '/search/page/1/expand/4?bk_id_2_1619=on' . $basic_search_params , 'Expand children of first hit' );
$mech->text_contains('dataset1_2008-09-17_12', 'Expanded matching level 2 dataset (num 1, page 1)' );
$mech->text_contains('dataset1_2010-02-01_12', 'Expanded matching level 2 dataset (num 2, page 1)' );
$mech->text_contains('dataset1_2008-07-30_12', 'Expanded matching level 2 dataset (num 3, page 1)' );

$mech->get_ok( '/search/page/1/level2page/4/2?show_level2_4=1&bk_id_2_1619=on' . $basic_search_params , 'Navigate to second page of children' );
$mech->text_contains('dataset1_2010-01-01_12', 'Expanded matching level 2 dataset (num 1, page 2)' );
$mech->text_contains('dataset1_2010-03-01_12', 'Expanded matching level 2 dataset (num 2, page 2)' );

$mech->get_ok( '/search/page/1/deflate/4?bk_id_2_1619=on' . $basic_search_params , 'Do not show children for first dataset' );
$mech->text_unlike(qr/dataset1_2008-09-17_12/, 'First level 2 dataset not shown.' );

$mech->get_ok( '/search/page/1/result?' . $basic_search_params , 'Search with no criteria' );
$mech->text_contains('dataset4', 'Search found matching datasets (num 1, page 1)');
$mech->text_contains('dataset3', 'Search found matching datasets (num 2, page 1)');
$mech->text_contains('dataset2', 'Search found matching datasets (num 3, page 1)');

$mech->get_ok( '/search/page/2/result?' . $basic_search_params , 'Search with no criteria' );
$mech->text_contains('dataset1', 'Search found matching datasets (num 1, page 2)');
$mech->text_unlike( qr/dataset2/, 'Matching dataset only on one page');
