<?php
/*
 * Created on May 7, 2009
 *
 *---------------------------------------------------------------------------- 
 * METAMOD - Web portal for metadata search and upload 
 *
 * Copyright (C) 2009 met.no 
 *
 * Contact information: 
 * Norwegian Meteorological Institute 
 * Box 43 Blindern 
 * 0313 OSLO 
 * NORWAY 
 * email: heiko.klein@met.no 
 *  
 * This file is part of METAMOD 
 *
 * METAMOD is free software; you can redistribute it and/or modify 
 * it under the terms of the GNU General Public License as published by 
 * the Free Software Foundation; either version 2 of the License, or 
 * (at your option) any later version. 
 *
 * METAMOD is distributed in the hope that it will be useful, 
 * but WITHOUT ANY WARRANTY; without even the implied warranty of 
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the 
 * GNU General Public License for more details. 
 *  
 * You should have received a copy of the GNU General Public License 
 * along with METAMOD; if not, write to the Free Software 
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA 
 *--------------------------------------------------------------------------- 
 */

/**
 * @brief Runtime Config-file access
 * 
 * The mmConfig class enables to read the configuration file in runtime and
 * to access the variables in a php-way. 
 * 
 * Including this file will also initialize the $mmConfig variable.
 * 
 */
class MMConfig {
	static private $_configs = array(); # storage of filename => MMConfig
	private $filename;
	private $vars = array();

	# flag to ensure that the logger is only initialised once
	private static $loggerInitialised = false;

	/**
	 * Retrieve an MMConfig object for the filename.
	 * 
	 * @param file The filename of the config-file, if not given, the default config-file.
	 *             The default config file only works if you are in the htdocs directory, not in subdirectories.
	 */
	static function getInstance($file = "") {
		if ($file == "") {
			$file = self::getDefaultConfigFile();
		}
		if (!array_key_exists($file, self::$_configs)) {
			self::$_configs[$file] = new MMConfig($file);
		}
		return self::$_configs[$file]; 
	}
	
	/**
	 * Get the filename of the default config file.
	 */
	static function getDefaultConfigFile() {
		return '../../master_config.txt';
	}
	
	/**
	 * Construct a new MMConfig
	 * 
	 * @param file The filename of the config-file.
	 */
	private function __construct($file) {
		$this->filename = realpath($file);
		$this->vars  = $this->_readConfig();
	}
	
	private function _readConfig() {
		// parse the file
		$conf = array();
		# get the filesystem prefix to installed base
		$prefix = __FILE__;
		$prefix = preg_replace("/htdocs\/funcs\/mmConfig.inc$/", "", $prefix);
		
		$fh = fopen($this->filename,'r');
		if (!$fh) trigger_error("cannot open config-file at: ".$this->filename, E_USER_ERROR);
		$origname = "";
		$newname = "";
		$value = "";
		$varname = "";
		while (!feof($fh)) {
			$line = fgets($fh);
			$line = rtrim($line);
			if (preg_match('/^[A-Z0-9_#!]/', $line) && $varname != "") {
				if (strlen($origname) > 0) {
					$conf[$varname.':'.$origname.':'.$prefix.$newname] = $value;
				} else {
					$conf[$varname] = $value;
				}
				$varname = "";
			}
			if (preg_match('/^([A-Z0-9_]+)\s*=(.*)$/', $line, $matches)) {
				$varname = $matches[1];
				$value = $matches[2];
				$value = trim($value);
			} elseif (preg_match('/^!substitute_to_file_with_new_name\s+(\S+)\s+=>\s+(\S+)\s*$/', $line, $matches)) {
				$origname = $matches[1];
				$newname = $matches[2];
			} elseif (preg_match('/^!end_substitute_to_file_with_new_name\s*$/', $line)) {
				$origname = "";
				$newname = "";
			} elseif (!preg_match('/^#/', $line) && !preg_match('/^\s*$/', $line)) {
				$value .= "\n$line";
			}
		}
		fclose($fh);
		if ($varname != "") {
			$conf[$varname] = $value;
		}
		return $conf;	
	}
	
	/**
	 * Read a variable from the configuration
	 * 
	 * @param var the variable-key
	 * @param origName This can optionally be used for substitutions. (!substitute_to_file in master_config)
	 *        The scripts original filename, i.e. htdocs/qst/quest.php, usually, this should be left empty
	 * @param myFile This can optionally be used for substitutions. It should then contain __FILE__ of the installed
	 *        script. Usually, this should be left empty.
	 */
	function getVar($var, $origName="", $myFile="") {
		$val = $this->substituteVariable($var, $origName, $myFile);
		return $val;
	}
	
	private function substituteVariable($var, $origName, $myFile) {
		if (strlen($myFile)) {
			$val = $this->vars["$var:$origName:$myFile"];
		} else {
			$val = $this->vars[$var];
		}
		$maxSubst = 40;
		$substNo = 0;
		$count = 1;
		while ($count > 0 && ($substNo < $maxSubst)) {
			$val = preg_replace('/\[==([A-Z0-9_]+)==\]/e', '$this->vars[\'$1\']', $val, -1, $count);
			$substNo += $count;
		}
		if ($substNo >= $maxSubst) {
			trigger_error("Circular substitution in ".$this->filename." for $var", E_USER_ERROR);		
		}
		return $val;
	}

	/**
	 * Initialise the logger defined in the configuration file.
	 */
	public function initLogger(){

        require_once("../log4php/Logger.php");

		if( MMConfig::$loggerInitialised ){
			return;
		}
		# we manipulate the environment so that LoggerConfiguratorIni will use the log file
		# specified in the master_config.txt
		putenv( "METAMOD_SYSTEM_LOG=" . $this->getVar('LOG4ALL_SYSTEM_LOG') );

		$config_file = $this->getVar('LOG4PHP_CONFIG');
		Logger::configure( $config_file );

		MMConfig::$loggerInitialised = true;

	}

	/**
	 * Initialise a logger without having a MMConfig object first.
	 *
	 * Will automatically create a MMConfig object for you which is returned.
	 *
	 * @param string $file Optional parameter containing the name of the master config file.
	 */
	public static function getInstanceWithLogger($file = ''){
		$config = MMConfig::getInstance($file);
		$config->initLogger();

		return $config;
	}
}

$mmConfig = "";
if (file_exists(realpath(MMConfig::getDefaultConfigFile()))) {
	$mmConfig = MMConfig::getInstance();
}
?>
