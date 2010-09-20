<?php 

require_once '../funcs/mmUserbase.inc';
require_once '../funcs/mmWebApp.inc';
require_once '../funcs/mmConfig.inc';

/**
 * Class implementing a UI for registering new users.
 */
class UserAdmin extends MMWebApp {
    
    public function init(){
        
        parent::init();
        
        $this->setDefaultAction('display_new_user');
        
        $dispatchRules = array(
            'display_new_user' => 'displayNewUser',
            'register_new_user' => 'registerNewUser',
        );
        $this->addDispatchRules($dispatchRules);
        
    }
    
    /**
     * Display a form for adding a new user to the database.
     * @param $infoMsg
     * @param $errorMsg
     */
    function displayNewUser( $infoMsg = '', $errorMsg = ''){
        
        $name = urldecode( $_REQUEST['name'] );
        $email = urldecode( $_REQUEST['email'] );
        $institutionCode = $_REQUEST['institution_code'];
        $telephoneNumber = $_REQUEST['telephone_number'];
        
           
        $newUserForm = <<<END_FORM
<html>
<head>
<title>User administration</title>
<style>
body {
    font-family: sans-serif;
    font-size: 12px;
}
div#content {
    width: 600px;
    margin-left: auto;
    margin-right: auto;

}
td {
    font-size: 12px;
}

label {
    font-weight: bolder;
}
</style>
</head>
<body>

<div id="content">
<h2>Register new user</h2>

<span style="color: red">$errorMsg</span>
<span>$infoMsg</span>

<form name="new_user" method="POST">
    <input type="hidden" name="action" value="register_new_user" />
    
    <table>
       
        <tr>
            <td><label for="username">Username</label></td>
        </tr>
        <tr>
            <td><input type="text" id="username" name="username" /></td>
            <td>
                If the METAMOD instance is setup to use LDAP authentication, enter the LDAP uid here. If LDAP authentication
                is not used you can choose any username you would like.
            </td>
        </tr>
        
        <tr>
            <td><label for="password">Password</label></td>
        </tr>
        <tr>
            <td><input type="text" id="password" name="password" value="" /></td>
            <td>
                When LDAP authentication is used please fill out this field with the LDAP password. This password will
                be sent to the user in an email, but not stored in the METAMOD database.
            </td>
        </tr>        
        
        <tr>
            <td><label for="name">Name</label></td>
        </tr>
        <tr>
            <td><input type="text" id="name" name="name" value="$name" /></td>
            <td>&nbsp;</td>        
        </tr>
        
        <tr>
            <td><label for="email">Email address</label></td>
        </tr>
        <tr>
            <td><input type="text" id="email" name="email" value="$email" /></td>
            <td>&nbsp;</td>        
        </tr>

        <tr>
            <td><label for="institution_name">Code for institution</label></td>
        </tr>
        <tr>
            <td><input type="text" id="institution_code" name="institution_code" value="$institutionCode" /></td>
            <td>&nbsp;</td>        
        </tr>

        <tr>
            <td><label for="telephone_number">Telephone number</label></td>
        </tr>
        <tr>
            <td><input type="text" id="telephone_number" name="telephone_number" value="$telephoneNumber" /></td>
            <td>&nbsp;</td>
        </tr>  
                
        <tr style="text-align: center">
            <td><button type="submit">Register user</button></td>
        </tr>
    </table>
</form>
</div>
</body>
</html>
END_FORM;

        return $newUserForm;              
        
    }
    
    /**
     * Action for regisering new users.
     */
    public function registerNewUser() {

        $requiredFields = array( 'username', 'password', 'email' );
        foreach ($requiredFields as $field) {
            if( trim( $_REQUEST[ $field ] ) == ''){
                return $this->displayNewUser( '', "You cannot register a user with a blank $field" );
            }
        }        
        
        $userbase = new MM_userbase();
       
        $applicationId = $this->config->getVar( 'APPLICATION_ID' );        
        $loginname = $_REQUEST['username'];
        $password = $_REQUEST['password'];        
        $name = $_REQUEST['name'];
        $email = $_REQUEST['email'];
        $institutionCode = $_REQUEST['institution_code'];
        $telephoneNumber = $_REQUEST['telephone_number'];

        if( $userbase->user_find( $email, $applicationId ) ){
            $this->logger->info( 'User with specfied email already in database' );
            return $this->displayNewUser( '', 'The email address is already used for another user');                      
        }
        
        if( $userbase->user_lfind( $loginname, $applicationId ) ){
            $this->logger->info( 'User with specfied loginname already in database' );
            return $this->displayNewUser( '', 'The loginname is already used for another user');                      
        }        
        
        $success = $userbase->user_create( $email, $applicationId );
        if( !$success ){
            $this->logger->error( 'Failed to create the user in the database: ' . $userbase->get_exception() );
            return $this->displayNewUser( '', 'Failed to create new user');          
        }
        
        $userbase->user_put( 'u_loginname', $loginname );
        $userbase->user_put( 'u_name', $name );
        $userbase->user_put( 'u_telephone', $telephoneNumber );
        $userbase->user_put( 'u_institution', $institutionCode );
        
        # only stored the password if using database authentication
        if( $this->config->getVar( 'AUTH_TYPE' ) == 'DB' ){
            $userbase->user_put( 'u_password', $password );            
        }
        
        $userbase->close();
        
        $success = $this->sendUsernameEmail( $loginname, $password, $name, $email );
        if( !$success ){
            $this->logger->error( 'Failed to send password email to user' );
            return $this->displayNewUser( '', 'Failed to send email to the user. Please do this manually');    
        }
        
        return $this->displayNewUser('New user has been registered', '');
    }
    
    /**
     * Function used for sending an email to the user when it has been registered in the database.
     */
    private function sendUsernameEmail( $username, $password, $name, $email ){
        
        $applicationName = $this->config->getVar('APPLICATION_NAME');

        $emailSubject = "User registeration for $applicationName complete";
        $emailBody = <<<END_MSG
Dear $name

You have been given access to $applicationName.

You can log in with the following details:
Username: $username
Password: $password
END_MSG;

        # the address to send the request to
        $operatorEmail = $this->config->getVar('OPERATOR_EMAIL');
        $emailHeader = "From: $operatorEmail\r\n";
            
        $success = mail( $email, $emailSubject, $emailBody, $emailHeader );    
        
        if( !$success ) {
            $this->logger->error('Failed to send');
            return false;
        }

        return true;
        
        
    }
    
}


$mmConfig->initLogger();
$logger = Logger::getLogger('metamod.common.user_admin');
$userAdmin = new UserAdmin($logger);
echo $userAdmin->run();

?>