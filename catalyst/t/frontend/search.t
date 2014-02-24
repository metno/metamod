use strict;
use warnings;
use Test::More;
#use WWW::Mechanize;
use Test::WWW::Mechanize::Catalyst;

use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../lib";
use lib "$FindBin::Bin/../../../common/lib";

use MetamodWeb::Test::Helper;

my $helper;
my $dataset1id;

BEGIN {

    $ENV{METAMOD_LOG4PERL_CONFIG} = "$FindBin::Bin/../log4perl_config.ini";

    $helper = MetamodWeb::Test::Helper->new( dataset_dir => "$FindBin::Bin/datasets", );
    $helper->setup_environment();

    $helper->run_import_dataset();

    if( !$helper->valid_metabase() ){
        plan skip_all => "Could not connect to the metabase database: " . $helper->errstr();
    }

    if( !$helper->valid_userbase() ){
        plan skip_all => "Could not connect to the userbase database: " . $helper->errstr();
    }

    my $metabase = $helper->metabase();
    my $dataset1 = $metabase->resultset('Dataset')->search({ ds_name => 'TEST/dataset1' } )->first();

    if( !defined $dataset1 ){
        plan skip_all => "Could not find 'TEST/dataset1'. Probably an import failure";
    }

    $dataset1id = $dataset1->ds_id();

    plan tests => 22;

}

BEGIN { use_ok 'MetamodWeb' }
BEGIN { use_ok 'MetamodWeb::Controller::Search' }

my $mech = Test::WWW::Mechanize::Catalyst->new( catalyst_app => 'MetamodWeb' );
$mech->get_ok( '/search', 'Request to front page' );

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

$mech->get_ok( "/search/page/1/expand/$dataset1id?bk_id_2_1619=on" . $basic_search_params , 'Expand children of first hit' );
$mech->text_contains('dataset1_2008-07-30_12', 'Expanded matching level 2 dataset (num 1, page 1)' );
$mech->text_contains('dataset1_2008-09-17_12', 'Expanded matching level 2 dataset (num 2, page 1)' );
$mech->text_contains('dataset1_2010-01-01_12', 'Expanded matching level 2 dataset (num 3, page 1)' );

$mech->get_ok( "/search/page/1/level2page/$dataset1id/2?show_level2_${dataset1id}=1&bk_id_2_1619=on" . $basic_search_params , 'Navigate to second page of children' );
$mech->text_contains('dataset1_2010-02-01_12', 'Expanded matching level 2 dataset (num 1, page 2)' );
$mech->text_contains('dataset1_2010-03-01_12', 'Expanded matching level 2 dataset (num 2, page 2)' );

$mech->get_ok( "/search/page/1/deflate/$dataset1id?bk_id_2_1619=on" . $basic_search_params , 'Do not show children for first dataset' );
$mech->text_unlike(qr/dataset1_2008-09-17_12/, 'First level 2 dataset not shown.' );

$mech->get_ok( '/search/page/1/result?' . $basic_search_params , 'Search with no criteria' );
$mech->text_contains('dataset1', 'Search found matching datasets (num 1, page 1)');
$mech->text_contains('dataset2', 'Search found matching datasets (num 2, page 1)');
$mech->text_contains('dataset3', 'Search found matching datasets (num 3, page 1)');

$mech->get_ok( '/search/page/2/result?' . $basic_search_params , 'Search with no criteria' );
$mech->text_contains('dataset4', 'Search found matching datasets (num 1, page 2)');

$mech->text_unlike( qr/dataset2/, 'Matching dataset only on one page');

##


#
#$mech = WWW::Mechanize->new;
#$mech->get( '/search/page/0/result?' . $basic_search_params );
#not_ok( $mech->success, 'Search with bad page number' );
##is( $mech->base, 'http://petdance.com', 'Proper <BASE HREF>' );
##is( $mech->title, 'Invoice Status', "Make sure we're on the invoice page" );
##ok( index( $mech->content( format => 'text' ), 'Andy Lester' ) >= 0, 'My name somewhere' );
##like( $mech->content, qr/(cpan|perl)\.org/, 'Link to perl.org or CPAN' );
