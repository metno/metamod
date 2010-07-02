<?php

require_once("../log4php/Logger.php");
require_once("../funcs/mmConfig.inc");

# we manipulate the environment so that LoggerConfiguratorIni will use the log file
# specified in the master_config.txt
putenv( "METAMOD_SYSTEM_LOG=" . $mmConfig->getVar('LOG4ALL_SYSTEM_LOG') );

$config_file = $mmConfig->getVar('LOG4PHP_CONFIG');
Logger::configure( $config_file );

