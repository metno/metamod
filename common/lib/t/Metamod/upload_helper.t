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
#use Test::Files;

BEGIN {
    $ENV{METAMOD_MASTER_CONFIG} = "$FindBin::Bin/../master_config.txt";
    $ENV{METAMOD_LOG4PERL_CONFIG} = "$FindBin::Bin/../log4perl_config.ini";
}

use Metamod::Config;
use Metamod::UploadHelper;
use Metamod::Test::Setup;

my $num_tests = 0;

my $webrun_dir = File::Spec->catdir($FindBin::Bin, 'webrun'); # not a good idea - should use regular config - FIXME
my $upload_area = File::Spec->catdir($FindBin::Bin, 'upload'); #
my $ftp_area = $upload_area; # File::Spec->catdir($FindBin::Bin, 'ftp_upload');
my $data_dir = File::Spec->catdir($webrun_dir, 'data' );
my $metadata_dir = File::Spec->catdir($webrun_dir, 'XML', 'EXAMPLE' );
init_dir_structure();

# we use same dir for ftp and upload, letting ftp_events determine which files should be read by ftp_process_hour
$ENV{METAMOD_UPLOAD_FTP_DIRECTORY} = $ftp_area;
$ENV{METAMOD_WEBRUN_DIRECTORY} = $webrun_dir;
$ENV{METAMOD_OPENDAP_BASEDIR} = "$FindBin::Bin/opendap";
$ENV{METAMOD_LOG4PERL_CONFIG} = "$FindBin::Bin/../log4perl_config.ini";

copy_test_files();

my $test_setup = Metamod::Test::Setup->new( master_config_file => "$FindBin::Bin/../master_config.txt");
my $config = $test_setup->mm_config;
$config->initLogger();
$test_setup->populate_userbase("$FindBin::Bin/upload_helper_userbase.sql");

local $Test::DatabaseRow::dbh = $test_setup->userbase()->storage()->dbh();

my $upload_helper = Metamod::UploadHelper->new();

{
    is($config->get('WEBRUN_DIRECTORY'), $webrun_dir, "WEBRUN_DIRECTORY is $webrun_dir");
    is($config->get('UPLOAD_FTP_DIRECTORY'), $ftp_area, "WEBRUN_DIRECTORY is $ftp_area");
    is($config->get('OPENDAP_BASEDIR' ), "$FindBin::Bin/opendap", "OPENDAP_BASEDIR is $FindBin::Bin/opendap");
    is($config->get('LOG4PERL_CONFIG' ), "$FindBin::Bin/../log4perl_config.ini", "LOG4PERL_CONFIG is $FindBin::Bin/../log4perl_config.ini");
    ok( -w $webrun_dir, "webrun directory is writable" );
    ok( -w $upload_area, "upload directory is writable" );
    ok( -w $ftp_area, "FTP directory is writable" );
    ok( -w $data_dir, "data directory is writable" );
    ok( -w $metadata_dir, "metadata directory is writable" );
    BEGIN { $num_tests += 9 };
}

{
    my $testname = 'Single .nc upload';

    is( $upload_helper->process_upload("$upload_area/hirlam12_ml_2008-05-20_00.nc", 'WEB'), '', "$testname: Processing upload");

    file_exists_ok(File::Spec->catfile($data_dir, 'met.no', 'hirlam12', 'hirlam12_ml_2008-05-20_00.nc'), "$testname: File moved to data directory");

    file_size_ok(File::Spec->catfile($data_dir, 'met.no', 'hirlam12', 'hirlam12_ml_2008-05-20_00.nc'), 5252, "$testname: Moved file has identical filesize");

    file_exists_ok(File::Spec->catfile($metadata_dir, 'hirlam12.xml',), "$testname: Level 1 metadata created");

    file_exists_ok(File::Spec->catfile($metadata_dir, 'hirlam12', 'hirlam12_ml_2008-05-20_00.xml'), "$testname: Level 2 metadata created");

    row_ok( sql => q{SELECT * FROM file WHERE u_id = 1 AND f_name = 'hirlam12_ml_2008-05-20_00.nc'},
            tests => [ f_size => 5252, f_errurl => q{} ],
            label => "$testname: File inserted into userbase",
    );

    BEGIN { $num_tests += 6 };
}


{
    my $testname = 'Single .nc.gz upload';

    is( $upload_helper->process_upload("$upload_area/hirlam12_ml_2008-05-16_00.nc.gz", 'WEB'), '', "$testname: Processing upload");

    file_exists_ok(File::Spec->catfile($data_dir, 'met.no', 'hirlam12', 'hirlam12_ml_2008-05-16_00.nc'), "$testname: File moved to data directory");

    file_size_ok(File::Spec->catfile($data_dir, 'met.no', 'hirlam12', 'hirlam12_ml_2008-05-16_00.nc'), 3280, "$testname: Moved file has identical filesize");

    file_exists_ok(File::Spec->catfile($metadata_dir, 'hirlam12', 'hirlam12_ml_2008-05-16_00.xml'), "$testname: Level 2 metadata created");

    row_ok( sql => q{SELECT * FROM file WHERE u_id = 1 AND f_name = 'hirlam12_ml_2008-05-16_00.nc.gz'},
            tests => [ f_size => 1143, f_errurl => q{} ],
            label => "$testname: Uploaded file inserted into userbase",
    );

    BEGIN { $num_tests += 5 };

}

{
    my $testname = '.tar.gz upload';

    is( $upload_helper->process_upload("$upload_area/hirlam12_upload.tar.gz", 'WEB'), '', "$testname: Processing upload");

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

    BEGIN { $num_tests += 8 }
}

{
    my $testname = '.tgz upload';

    is( $upload_helper->process_upload("$upload_area/hirlam12_upload.tgz", 'WEB'), '', "$testname: Processing upload");

    file_exists_ok(File::Spec->catfile($data_dir, 'met.no', 'hirlam12', 'hirlam12_sf_60h_2010-10-28_06.nc'), "$testname: File 1 moved to data directory");

    file_size_ok(File::Spec->catfile($data_dir, 'met.no', 'hirlam12', 'hirlam12_sf_60h_2010-10-28_06.nc'), 5036, "$testname: Moved file has identical filesize");

    file_exists_ok(File::Spec->catfile($metadata_dir, 'hirlam12', 'hirlam12_sf_60h_2010-10-28_06.xml'), "$testname: File 1 level 2 metadata created");

    row_ok( sql => q{SELECT * FROM file WHERE u_id = 1 AND f_name = 'hirlam12_upload.tgz'},
            tests => [ f_size => 1664, f_errurl => q{} ],
            label => "$testname: Uploaded file inserted into userbase",
    );

    BEGIN { $num_tests += 5 }
}

{
    my $testname = '.tar upload';

    is( $upload_helper->process_upload("$upload_area/hirlam12_upload2.tar", 'WEB'), '', "$testname: Processing upload");

    file_exists_ok(File::Spec->catfile($data_dir, 'met.no', 'hirlam12', 'hirlam12_pl_2008-05-29_00.nc'), "$testname: File moved to data directory");

    file_size_ok(File::Spec->catfile($data_dir, 'met.no', 'hirlam12', 'hirlam12_pl_2008-05-29_00.nc'), 4704, "$testname: Moved file has identical filesize");

    file_exists_ok(File::Spec->catfile($metadata_dir, 'hirlam12', 'hirlam12_pl_2008-05-29_00.xml'), "$testname: Level 2 metadata created");

    row_ok( sql => q{SELECT * FROM file WHERE u_id = 1 AND f_name = 'hirlam12_upload2.tar'},
            tests => [ f_size => 10240, f_errurl => q{} ],
            label => "$testname: Uploaded file inserted into userbase",
    );

    BEGIN { $num_tests += 5 }
}

{
    my $testname = '.tar.gz with invalid name for one file.';

    is( $upload_helper->process_upload("$upload_area/hirlam12_invalid_component.tar.gz", 'WEB'), '', "$testname: Processing upload");

    file_not_exists_ok(File::Spec->catfile($data_dir, 'met.no', 'hirlam12', 'hirlam12_pl_2008-07-01_18.nc'), "$testname: File with valid name not processed");

    file_not_exists_ok(File::Spec->catfile($metadata_dir, 'hirlam12', 'hirlam12_pl_2008-07-01_18.xml'), "$testname: No metadata for file with valid name");

    file_not_exists_ok(File::Spec->catfile($data_dir, 'met.no', 'hirlam12', 'wrong_name.nc'), "$testname: File with invalid name ignored");

    file_not_exists_ok(File::Spec->catfile($metadata_dir, 'hirlam12', 'wrong_name.xml'), "$testname: No metadata for file with wrong name");

    row_ok( sql => q{SELECT * FROM file WHERE u_id = 1 AND f_name = 'hirlam12_invalid_component.tar.gz'},
            tests => [ f_size => 0, f_errurl => qr[/example/htdocs/upl/uerr/.*] ],
            label => "$testname: Uploaded file inserted into userbase",
    );

    BEGIN { $num_tests += 6 }
}

{
    my $testname = 'CDL conversion';

    file_exists_ok("$upload_area/hirlam12_valid_cdl.tar.gz", "$testname: hirlam12_valid_cdl.tar.gz exists");
    is( $upload_helper->process_upload("$upload_area/hirlam12_valid_cdl.tar.gz", 'WEB'), '', "$testname: Processing upload");
    #diag("$upload_area/hirlam12_valid_cdl.tar.gz");

    {
        local $TODO = 'works locally, but not under Jenkins';
        file_exists_ok(File::Spec->catfile($data_dir, 'met.no', 'hirlam12', 'hirlam12_valid_cdl.nc'), "$testname: Valid CDL processed");
        #diag(File::Spec->catfile($data_dir, 'met.no', 'hirlam12', 'hirlam12_valid_cdl.nc'));

        file_exists_ok(File::Spec->catfile($metadata_dir, 'hirlam12', 'hirlam12_valid_cdl.xml'), "$testname: Metadata for valid CDL generated");
        #diag(File::Spec->catfile($metadata_dir, 'hirlam12', 'hirlam12_valid_cdl.xml'));

        row_ok( sql => q{SELECT * FROM file WHERE u_id = 1 AND f_name = 'hirlam12_valid_cdl.tar.gz'},
                tests => [ f_size => 4716, f_errurl => qr[/example/htdocs/upl/uerr/.*] ],
                label => "$testname: Valid file upload inserted into userbase",
        );
    }

    file_exists_ok("$upload_area/hirlam12_invalid_cdl.tar.gz", "$testname: hirlam12_invalid_cdl.tar.gz exists");
    is( $upload_helper->process_upload("$upload_area/hirlam12_invalid_cdl.tar.gz", 'WEB'), '', "$testname: Processing upload" );
    #diag("$upload_area/hirlam12_invalid_cdl.tar.gz");

    file_not_exists_ok(File::Spec->catfile($data_dir, 'met.no', 'hirlam12', 'hirlam12_invalid_cdl.nc'), "$testname: Invalid CDL not processed");
    #diag(File::Spec->catfile($data_dir, 'met.no', 'hirlam12', 'hirlam12_invalid_cdl.nc'));

    file_not_exists_ok(File::Spec->catfile($metadata_dir, 'hirlam12', 'hirlam12_invalid_cdl.xml'), "$testname: Metadata for invalid CDL not generated");
    #diag(File::Spec->catfile($metadata_dir, 'hirlam12', 'hirlam12_invalid_cdl.xml'));

    row_ok( sql => q{SELECT * FROM file WHERE u_id = 1 AND f_name = 'hirlam12_invalid_cdl.tar.gz'},
            tests => [ f_size => 0, f_errurl => qr[/example/htdocs/upl/uerr/.*] ],
            label => "$testname: Invalid file upload inserted into userbase",
    );

    BEGIN { $num_tests += 10 }
}

{
    my $testname = 'ftp_monitor --test'; #

    ok( $upload_helper->ftp_process_hour(), "$testname: ftp_process_hour");
    # TODO - more testing on imported files
    
    BEGIN { $num_tests += 1 };

}

BEGIN { plan tests => $num_tests }

END {
    clean_dir_structure();
}

sub copy_test_files { # copy test files to web_upload and ftp_upload

    opendir(my $test_files_dir, "$FindBin::Bin/upload_helper_files") or die $!;
    while( my $file = readdir($test_files_dir) ){
        if( -f "$FindBin::Bin/upload_helper_files/$file" ){ # skip non-files
            copy( "$FindBin::Bin/upload_helper_files/$file", "$upload_area/$file" ) or die $!;
            #copy( "$FindBin::Bin/upload_helper_files/$file", "$ftp_area/$file" ) or die $!;
        }
    }
    copy( "$FindBin::Bin/ftp_events", $webrun_dir ) or die $!;
}

sub init_dir_structure {

    mkpath($upload_area);
    mkpath($ftp_area);
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
    #rmtree($ftp_area);
    rmtree("$FindBin::Bin/webrun");

}
