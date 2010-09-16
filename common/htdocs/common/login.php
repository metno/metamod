<?php 

require_once 'Auth.php';
require_once '../funcs/mmAuth.inc';
require_once '../funcs/mmWebApp.inc';

class LoginPage extends MMWebApp {
    
    public function init() {

        parent::init();
        
        $this->setDefaultAction('login');
        
        $dispatchRules = array(
            'login' => 'login',
            'register' => 'register',
        );
        $this->addDispatchRules($dispatchRules);
    }
    
    function login() {

        $authType = mmGetAuthType();
        $authOptions = mmGetAuthOptions();
        
        $auth = new Auth( $authType, $authOptions, array($this, 'createLoginPage') );
        mmRegisterAuthLogger($auth);
        $auth->start();

        if( $auth->checkAuth() ){    
            if( isset( $_REQUEST['return'] ) ){
                
                $get_string = urldecode( $_REQUEST['params'] );
                
                echo header( "Location: http://" . $_REQUEST['return'] . '?' . $get_string );
            } else {
                //do not have a good place to send the user. Send them to the search page
                echo header( 'Location: ../sch/' );        
            }
            
        }              
    }
    
    function register() {
        
        $requiredFields = array( 'email', 'name', 'institution_name', 'telephone_number' );
        $missingFields = false;
        foreach( $requiredFields as $field ){
            if( !$_REQUEST[$field]){
                $missingFields = true;
            }
        }
        
        if( $missingFields ){
            $this->registrationFailure = 'You must fill out all the fields to request a new user.';
            return $this->createLoginPage();
        }
        
        $success = $this->sendRegistrationEmail();
        
        if( $success ){
            $this->registrationSuccess = 'You registration has been sent.';
            return $this->createLoginPage();            
        } else {
            $this->registrationFailure = 'An error occurred when sending your request. Please try again.';
            return $this->createLoginPage();
        }
        
    }
    
    function sendRegistrationEmail(){

        
        $applicationId = $this->config->getVar('APPLICATION_ID');
        $name = $_REQUEST['name'];
        $email = $_REQUEST['email'];
        $institutionCode =  $_REQUEST['institution_name'];
        $telephoneNumber = $_REQUEST['telephone_number'];

        $baseURL = $this->config->getVar('BASE_PART_OF_EXTERNAL_URL');
        $localURL = $this->config->getVar('LOCAL_URL');    
        $fullURL = $baseURL . $localURL . "/adm/user_admin.php?action=display_new_user";
        $fullURL .= '&name=' . urlencode( $name );
        $fullURL .= '&email=' . urlencode( $email );
        $fullURL .= '&institution_code=' . $institutionCode;
        $fullURL .= '&telephone_number=' . $telephoneNumber;        
        
        $emailSubject = 'New METAMOD user requested';
        $emailBody = <<<END_MSG
Application id: $applicationId
Name: $name
Email address: $email
Institution code: $institutionCode
Telephone number: $telephoneNumber

Administrator click this link for registration (users do not have access to this URL):

$fullURL

END_MSG;

        # the address to send the request to
        $requestAddress = $this->config->getVar('OPERATOR_EMAIL');
        $emailHeader = "From: $email\r\n";
            
        $success = mail( $requestAddress, $emailSubject, $emailBody, $emailHeader );    
        
        if( !$success ) {
            $this->logger->error('Failed to send');
            return false;
        }
        
        return true;
    }    

    function createLoginPage( $username = null, $status = null, &$auth = null ){
    
        $login_page = $_SERVER['SCRIPT_NAME'];
        $return = $_REQUEST['return'];
        $params = $_REQUEST['params'];
        $name = $_REQUEST['name'];
        $email = $_REQUEST['email'];
        $telephoneNumber = $_REQUEST['telephone_number'];
    
        $status_message = '';
        if ($status == AUTH_EXPIRED) {
            $status_message = 'Your session has expired. Please login again.';
        } else if ($status == AUTH_IDLED) {
            $status_message = 'You have been idle for too long. Please login again.';
        } else if ($status == AUTH_WRONG_LOGIN) {
            $status_message = 'Invalid username or password.';
        } else if ($status == AUTH_SECURITY_BREACH) {
            $status_message = 'Security problem detected.';
        }

        $registerMessage = '';
        if( $this->missingFields ){
            $registerMessage = 'You must fill out all the fields to request a new user.';
        }
        
        $institutionOptions = '';
        $institutions = explode("\n",$this->config->getVar('INSTITUTION_LIST'));
        foreach ($institutions as $institution) {
            $matches = array();
            if (preg_match ('/^ *([^ ]+) (.*)$/i',$institution,$mathces)) {
               $institutionOptions .= '<option value="' . $mathces[1] . '">' . $mathces[2] . "</option>\n";
           }
        }
        
        
        $form = <<<END_FORM
<html>
<head>
<title>METAMOD login</title>
<style>
body {
    font-family: sans-serif;
    font-size: 12px;
}

div#loginform, div#registerform {
    float: left;
    width: 400px;
    height: 350px;
    background-color: #D2F2F4;
    border: 1px solid #0E8AEF;
    margin: 5px 5px 5px 5px;
    padding: 5px 5px 5px 5px;    
}

div#info {
    width: 820px;
    border: 1px solid #0E8AEF;
    margin: 5px 5px 5px 5px;
    padding: 5px 5px 5px 5px;    
}

h2 {
    text-align: center;
}

td {
    font-size: 0.8em;
}

td.error {
    color: red;
}


label {
    font-weight: bolder;
}

</style>
</head>
<body>

<div id="info">
    <p class="info">
    Log in to METAMOD to get access to more functions. When logged in you can do the following:
    </p>
    <ul>
    <li>Setup automatic subscriptions to get notified about new data files.</li>
    <li>Upload new datafiles and add meta data</li>
    <li>Administrate your own account.</li>
    </ul>
</div>

<div id="loginform">
    
    <h2>Login</h2>
    <p class="form">
    For already registered users.
    </p>
    <form name="login" method="POST" action="$login_page">
        <input type="hidden" name="return" value="$return" />
        <input type="hidden" name="params" value="$params" />
        <input type="hidden" name="action" value="login" />
        <table>
            <tr>
            <td class="error" colspan="2">$status_message</td>
            </tr>
            
            <tr>
            <td><label for="username">Username<label></td>
            <td><input type="text" name="username" id="username" value="$username" /></td>
            </tr>
            
            <tr>
            <td><label for="password">Password</label></td>
            <td><input type="password" id="password" name="password" /></td>
            </tr>
            
            <tr>
            <td colspan="2"><input type="submit" value="Login" /></td>
            </tr>
        </table>
    </form>
</div>

<div id="registerform">

    <h2>Request new user</h2>
    
    <span style="font-weight: bolder">$this->registrationSuccess</span>
    
    <p class="form">
    If you do not already have a username and password you can send a request for one. Be aware that it can take
    some time to process your request as it has to be manually approved.    
    </p>

    <form name="register" method="POST" action="$login_page">
    <input type="hidden" name="return" value="$return" />
    <input type="hidden" name="params" value="$params" />
    <input type="hidden" name="action" value="register" />    
        <table>
            <tr>
            <td class="error" colspan="2">$this->registrationFailure</td>
            </tr>
            
            
            <tr>
            <td><label for="name">Name</label></td>
            <td><input type="text" id="name" name="name" value="$name" /></td>
            </tr>
            
            <tr>
            <td><label for="email">Email address</label></td>
            <td><input type="text" id="email" name="email" value="$email" /></td>
            </tr>

            <tr>
            <td><label for="institution_name">Name of institution</label></td>
            <td>
                <select id="institution_name" name="institution_name">
                $institutionOptions;
                </select>
            </tr>

            <tr>
            <td><label for="telephone_number">Telephone number</label></td>
            <td><input type="text" id="telephone_number" name="telephone_number" value="$telephoneNumber" /></td>
            </tr>            
            
            <tr>
            <td colspan="2"><input type="submit" value="Request access" /></td>
            </tr>
        </table>
    </form>
</div>
</body>
</html>
END_FORM;
        
        echo $form;
        
    }
  
}

$logger = Logger::getLogger('metamod.base.login');
$loginPage = new LoginPage($logger);
echo $loginPage->run();

?>