#!/usr/bin/php -q

<?php

#
# Script that is used for testing writing to a log file using log4php. This script is used
# together with test_concurrent_logging.php
#

require_once( '../../common/htdocs/log4php/Logger.php' );

Logger::configure( 'log4php-test-config.ini' );

$process_name = $_SERVER["argv"][1];
$num_iterations = $_SERVER["argv"][2];

$logger = Logger::getLogger("test");

echo "Starting process $process_name\n";
$logger->info( "Staring process $process_name" );

for ($i=1; $i<=$num_iterations; $i++) {

	$logger->info( "Now at interation" . $i . " in process " . $process_name );
    usleep( rand( 0, 10 ) * 100000 );
}

$logger->info( "Ending process $process_name" );
echo "Ending process $process_name\n";

?>