#!/usr/bin/perl -w

use strict;

use FindBin;

use lib "$FindBin::Bin/../..";

use File::Copy;
use File::Path;
use File::Spec;

use Test::DatabaseRow;
use Test::More;
use Test::File;
use Test::Files;

BEGIN {
    $ENV{METAMOD_MASTER_CONFIG} = "$FindBin::Bin/../master_config.txt";
    $ENV{METAMOD_LOG4PERL_CONFIG} = "$FindBin::Bin/../log4perl_config.ini";
}

use Metamod::Config;
use Metamod::UploadHelper;
use Metamod::Test::Setup;

my $num_tests = 0;

my $webrun_dir = File::Spec->catdir($FindBin::Bin, 'webrun');
my $upload_area = File::Spec->catdir($FindBin::Bin, 'upload');
my $data_dir = File::Spec->catdir($webrun_dir, 'data' );
my $metadata_dir = File::Spec->catdir($webrun_dir, 'XML', 'EXAMPLE' );
init_dir_structure();


$ENV{METAMOD_WEBRUN_DIRECTORY} = $webrun_dir;
$ENV{METAMOD_OPENDAP_BASEDIR} = "$FindBin::Bin/opendap";
$ENV{METAMOD_LOG4PERL_CONFIG} = "$FindBin::Bin/../log4perl_config.ini";

copy_test_files();

my $test_setup = Metamod::Test::Setup->new( master_config_file => "$FindBin::Bin/../master_config.txt");
$test_setup->mm_config->initLogger();
$test_setup->populate_userbase("$FindBin::Bin/upload_helper_userbase.sql");

local $Test::DatabaseRow::dbh = $test_setup->userbase()->storage()->dbh();

my $upload_helper = Metamod::UploadHelper->new();

{
    my $testname = 'Single .nc upload';

    $upload_helper->process_upload("$upload_area/hirlam12_ml_2008-05-20_00.nc", 'WEB');

    file_exists_ok(File::Spec->catfile($data_dir, 'met.no', 'hirlam12', 'hirlam12_ml_2008-05-20_00.nc'), "$testname: File moved to data directory");

    file_size_ok(File::Spec->catfile($data_dir, 'met.no', 'hirlam12', 'hirlam12_ml_2008-05-20_00.nc'), 5252, "$testname: Moved file has identical filesize");

    file_exists_ok(File::Spec->catfile($metadata_dir, 'hirlam12.xml',), "$testname: Level 1 metadata created");

    file_exists_ok(File::Spec->catfile($metadata_dir, 'hirlam12', 'hirlam12_ml_2008-05-20_00.xml'), "$testname: Level 2 metadata created");

    row_ok( sql => q{SELECT * FROM file WHERE u_id = 1 AND f_name = 'hirlam12_ml_2008-05-20_00.nc'},
            tests => [ f_size => 5252, f_errurl => q{} ],
            label => "$testname: File inserted into userbase",
    );

    BEGIN { $num_tests += 5 };
}


{
    my $testname = 'Single .nc.gz upload';

    $upload_helper->process_upload("$upload_area/hirlam12_ml_2008-05-16_00.nc.gz", 'WEB');

    file_exists_ok(File::Spec->catfile($data_dir, 'met.no', 'hirlam12', 'hirlam12_ml_2008-05-16_00.nc'), "$testname: File moved to data directory");

    file_size_ok(File::Spec->catfile($data_dir, 'met.no', 'hirlam12', 'hirlam12_ml_2008-05-16_00.nc'), 3280, "$testname: Moved file has identical filesize");

    file_exists_ok(File::Spec->catfile($metadata_dir, 'hirlam12', 'hirlam12_ml_2008-05-16_00.xml'), "$testname: Level 2 metadata created");

    row_ok( sql => q{SELECT * FROM file WHERE u_id = 1 AND f_name = 'hirlam12_ml_2008-05-16_00.nc.gz'},
            tests => [ f_size => 1143, f_errurl => q{} ],
            label => "$testname: Uploaded file inserted into userbase",
    );

    BEGIN { $num_tests += 4 };

}

{
    my $testname = '.tar.gz upload';

    $upload_helper->process_upload("$upload_area/hirlam12_upload.tar.gz", 'WEB');

    file_exists_ok(File::Spec->catfile($data_dir, 'met.no', 'hirlam12', 'hirlam12_ml_2008-05-21_00.nc'), "$testname: File 1 moved to data directory");
    file_exists_ok(File::Spec->catfile($data_dir, 'met.no', 'hirlam12', 'hirlam12_ml_2008-05-22_00.nc'), "$testname: File 2 moved to data directory");

    file_size_ok(File::Spec->catfile($data_dir, 'met.no', 'hirlam12', 'hirlam12_ml_2008-05-21_00.nc'), 5252, "$testname: Moved file has identical filesize");
    file_size_ok(File::Spec->catfile($data_dir, 'met.no', 'hirlam12', 'hirlam12_ml_2008-05-22_00.nc'), 5252, "$testname: Moved file has identical filesize");

    file_exists_ok(File::Spec->catfile($metadata_dir, 'hirlam12', 'hirlam12_ml_2008-05-21_00.xml'), "$testname: File 1 level 2 metadata created");
    file_exists_ok(File::Spec->catfile($metadata_dir, 'hirlam12', 'hirlam12_ml_2008-05-22_00.xml'), "$testname: File 2 level 2 metadata created");

    row_ok( sql => q{SELECT * FROM file WHERE u_id = 1 AND f_name = 'hirlam12_upload.tar.gz'},
            tests => [ f_size => 1616, f_errurl => q{} ],
            label => "$testname: Uploaded file inserted into userbase",
    );

    BEGIN { $num_tests += 7 }
}

{
    my $testname = '.tar upload';

    $upload_helper->process_upload("$upload_area/hirlam12_upload2.tar", 'WEB');

    file_exists_ok(File::Spec->catfile($data_dir, 'met.no', 'hirlam12', 'hirlam12_pl_2008-05-29_00.nc'), "$testname: File moved to data directory");

    file_size_ok(File::Spec->catfile($data_dir, 'met.no', 'hirlam12', 'hirlam12_pl_2008-05-29_00.nc'), 4704, "$testname: Moved file has identical filesize");

    file_exists_ok(File::Spec->catfile($metadata_dir, 'hirlam12', 'hirlam12_pl_2008-05-29_00.xml'), "$testname: Level 2 metadata created");

    row_ok( sql => q{SELECT * FROM file WHERE u_id = 1 AND f_name = 'hirlam12_upload2.tar'},
            tests => [ f_size => 10240, f_errurl => q{} ],
            label => "$testname: Uploaded file inserted into userbase",
    );

    BEGIN { $num_tests += 4 }
}

{
    my $testname = '.tar.gz with invalid name for one file.';

    $upload_helper->process_upload("$upload_area/hirlam12_invalid_component.tar.gz", 'WEB');

    file_not_exists_ok(File::Spec->catfile($data_dir, 'met.no', 'hirlam12', 'hirlam12_pl_2008-07-01_18.nc'), "$testname: File with valid name not processed");

    file_not_exists_ok(File::Spec->catfile($metadata_dir, 'hirlam12', 'hirlam12_pl_2008-07-01_18.xml'), "$testname: No metadata for file with valid name");

    file_not_exists_ok(File::Spec->catfile($data_dir, 'met.no', 'hirlam12', 'wrong_name.nc'), "$testname: File with invalid name ignored");

    file_not_exists_ok(File::Spec->catfile($metadata_dir, 'hirlam12', 'wrong_name.xml'), "$testname: No metadata for file with wrong name");

    row_ok( sql => q{SELECT * FROM file WHERE u_id = 1 AND f_name = 'hirlam12_invalid_component.tar.gz'},
            tests => [ f_size => 0, f_errurl => qr[/example/htdocs/upl/uerr/.*] ],
            label => "$testname: Uploaded file inserted into userbase",
    );

    BEGIN { $num_tests += 5 }
}

{
    my $testname = 'CDL conversion';

    $upload_helper->process_upload("$upload_area/hirlam12_valid_cdl.tar.gz", 'WEB');

    file_exists_ok(File::Spec->catfile($data_dir, 'met.no', 'hirlam12', 'hirlam12_valid_cdl.nc'), "$testname: Valid CDL processed");

    file_exists_ok(File::Spec->catfile($metadata_dir, 'hirlam12', 'hirlam12_valid_cdl.xml'), "$testname: Metadata for valid CDL generated");

    row_ok( sql => q{SELECT * FROM file WHERE u_id = 1 AND f_name = 'hirlam12_valid_cdl.tar.gz'},
            tests => [ f_size => 4716, f_errurl => qr[/example/htdocs/upl/uerr/.*] ],
            label => "$testname: Valid file upload inserted into userbase",
    );

    $upload_helper->process_upload("$upload_area/hirlam12_invalid_cdl.tar.gz", 'WEB');

    file_not_exists_ok(File::Spec->catfile($data_dir, 'met.no', 'hirlam12', 'hirlam12_invalid_cdl.nc'), "$testname: Invalid CDL not processed");

    file_not_exists_ok(File::Spec->catfile($metadata_dir, 'hirlam12', 'hirlam12_invalid_cdl.xml'), "$testname: Metadata for invalid CDL not generated");

    row_ok( sql => q{SELECT * FROM file WHERE u_id = 1 AND f_name = 'hirlam12_invalid_cdl.tar.gz'},
            tests => [ f_size => 0, f_errurl => qr[/example/htdocs/upl/uerr/.*] ],
            label => "$testname: Invalid file upload inserted into userbase",
    );


    BEGIN { $num_tests += 6 }
}


BEGIN { plan tests => $num_tests }

END {
    clean_dir_structure();
}

sub copy_test_files {

    opendir(my $test_files_dir, "$FindBin::Bin/upload_helper_files") or die $!;
    while( my $file = readdir($test_files_dir) ){

        if( -f "$FindBin::Bin/upload_helper_files/$file" ){
            copy( "$FindBin::Bin/upload_helper_files/$file", "$upload_area/$file" ) or die $!;
        }
    }
}

sub init_dir_structure {

    mkpath($upload_area);
    mkpath("$FindBin::Bin/webrun");
    mkpath("$FindBin::Bin/webrun/data");
    mkpath("$FindBin::Bin/webrun/upl/problemfiles");
    mkpath("$FindBin::Bin/webrun/upl/uerr");
    mkpath("$FindBin::Bin/webrun/XML/EXAMPLE");
    mkpath("$FindBin::Bin/webrun/XML/history");

}

sub clean_dir_structure {

    # need to reset current dir because the modules that is tested might not do it.
    chdir $FindBin::Bin;
    rmtree($upload_area);
    rmtree("$FindBin::Bin/webrun");

}