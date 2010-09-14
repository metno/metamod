<?php 

require_once 'Auth.php';
require_once 'Log.php';
require_once 'Log/observer.php';
require_once 'mmConfig.inc';
require_once("../log4php/Logger.php");

/**
 * Get the options array used by the Auth object for verifying the login.
 * 
 * This function will read the master_config.txt file to determine 
 * the correct connection paramters. Both LDAP and DB options are supported.
 */
function mmGetAuthOptions(){
    
    $config = MMConfig::getInstance();
    $logger = Logger::getLogger('metamod.base.auth');
    $authType = mmGetAuthType();

    $options;
    if( 'LDAP' == $authType ){
        
        $ldapUrl = $config->getVar('AUTH_LDAP_URL');
        $basedn = $config->getVar('AUTH_LDAP_BASE_DN');
    
        $options = array(
            'url' => $ldapUrl, 
            'basedn' => $basedn,
            'version' => 3, 
        );
        
    } elseif ( 'DB' == $authType ){
        
        $databaseName = $config->getVar('USERBASE_NAME');
        $dbUser = $config->getVar('PG_WEB_USER');
        $applicationId = $config->getVar('APPLICATION_ID');        
        $connectionParams = mmParsePgString( $config->getVar('PG_CONNECTSTRING_PHP') );
        
        $dns = "pgsql://$dbUser";
        if( isset($connectionParams['password']) ){
            $dns .= ':' . $connectionParams['password'];
        }
        if( isset($connectionParams['host']) ){
            $dns .= '@' . $connectionParams['host'];
        } else {
            $dns .= '@localhost';
        }

        if( isset( $connectionParams['port']) ){
            $dns .= ':' . $connectionParams['port'];
        }            
        
        
        $dns .= '/' . $databaseName;
        
        $logger->debug("Auth dns: $dns");
        
        $options = array(
            'dsn' => $dns,
            'table' => 'usertable',
            'usernamecol' => 'u_loginname',
            'passwordcol' => 'u_password',
            'cryptType' => 'none', 
            'db_where' => "a_id ='$applicationId'",
        );
        
    }

    $options['enableLogging'] = true;
    return $options;
        
}

/**
 * Get the type of authentication that is performed. Either LDAP or DB
 * @throws Exception Throws an exception if it sees an unknown auth type. 
 */
function mmGetAuthType() {
    
    $config = MMConfig::getInstance();
    $authType = $config->getVar('AUTH_TYPE');
 
    if( $authType != 'LDAP' && $authType != 'DB' ) {
        $logger = Logger::getLogger('metamod.base.auth');
        $logger->error("Invalid AUTH_TYPE '$authType'");
        throw new Exception( "Invalid AUTH_TYPE '$authType'");
    }
    
    return $authType;
}

/**
 * Perform the actual authentication. It is this function that should be used in 
 * file requiring authentication.
 */
function mmAuthenticate() {

    $type = mmGetAuthType();    
    $options = mmGetAuthOptions();
    $auth = new Auth( $type, $options, 'mmRedirectToLogin' );
    mmRegisterAuthLogger($auth);
    $auth->start();   
    
}

/**
 * A callback function used if the authentication failes. It will redirect to 
 * the login page.
 */
function mmRedirectToLogin(){
    
    $orig_uri = $_SERVER['SERVER_NAME'] . $_SERVER['SCRIPT_NAME'];
    echo header("Location: ../adm/login.php?return=$orig_uri");
}

/**
 * This function deletes the current session and then sends the user to the
 * login page.
 */
function mmLogout(){
    $type = mmGetAuthType();
    $options = mmGetAuthOptions();
    
    $auth = new Auth( $type, $options, 'mmRedirectToLogin' );
    $auth->start();
    
    if( $auth->checkAuth() ){
        $auth->logout();
        $auth->start();
    }      
}

/**
 * Parses a PG_CONNECTSTRING_PHP into an array/hash of different connection 
 * variables.
 * @param string $pgString The string to parse
 * @throws Exception Throws and exception if it sees a format it does not recognise.
 */
function mmParsePgString( $pgString ){

    $connectParams = array();
    if( $pgString == '' ){
        return $connectParams;
    }
    
    $params = preg_split( '/\s+/', $pgString );
    
    foreach ($params as $param) {
        $matches = array();
        if( preg_match( '/^(\w+)=\s*(\w+)$/', $param, $matches ) ){
            $connectParams[ $matches[1] ] = $matches[2];
        } else {
            throw new Exception( "Failed to parse connect string. Connect string: '$pgString', part: '$param'");
        }
    }
            
    return $connectParams;
        
}

/**
 * Register a logger for internal events in Auth. Very useful for debugging login.
 * @param $auth The Auth object
 */
function mmRegisterAuthLogger($auth){
    
    $infoObserver = new AuthLogObserver(PEAR_LOG_INFO);
    $auth->attachLogObserver($infoObserver);

    $debugObserver = new AuthLogObserver(PEAR_LOG_DEBUG);
    $auth->attachLogObserver($debugObserver);    
    
}

/**
 * A log observer needed to log events from the Auth object. This one just
 * sends all log message to the log4php logger.
 */
class AuthLogObserver extends Log_observer {

    function notify($event) {

        $logger = Logger::getLogger('metamod.base.auth');
        if( $event['priority'] == PEAR_LOG_INFO ){
            $logger->info( $event['message'] );
        } elseif( $event['priority'] == PEAR_LOG_DEBUG ){
            $logger->debug( $event['message'] );
        }
    }

}


?>