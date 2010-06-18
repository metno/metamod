<?php

require_once("../log4php/Logger.php");
require_once("../funcs/mmConfig.inc");

# we manipulate the environment so that LoggerConfiguratorIni will use the log file
# specified in the master_config.txt
putenv( "METAMOD_LOG_FILE=" . $mmConfig->getVar('LOG4P_FILE') );

$config_file = $mmConfig->getVar('LOG4P_CONFIG');
Logger::configure( $config_file );

