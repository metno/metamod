<?php 

require_once 'Auth.php';
require_once '../funcs/mmAuth.inc';

$mmConfig->initLogger();

$auth_type = mmGetAuthType();
$auth_options = mmGetAuthOptions();

$auth = new Auth( $auth_type, $auth_options, 'createLoginPage' );
mmRegisterAuthLogger($auth);
$auth->start();


if( $auth->checkAuth() ){    
    if( isset( $_REQUEST['return'] ) ){
        echo header( "Location: http://" . $_REQUEST['return'] );
    } else {
        //do not have a good place to send the user. Send them to the search page
        echo header( 'Location: ../sch/' );        
    }
    
}

function createLoginPage( $username = null, $status = null, &$auth = null ){

    $login_page = $_SERVER['SCRIPT_NAME'];
    $return = $_REQUEST['return'];

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
       
    
    $form = <<<END_FORM
<form name="login" method="POST" action="$login_page">
<input type="hidden" name="return" value="$return" />

<table>

<tr>
<td colspan="2">$status_message</td>
</tr>

<tr>
<td>Username</td>
<td><input type="text" name="username" value="$username" /></td>
</tr>

<tr>
<td>Password</td>
<td><input type="password" name="password" /></td>
</tr>

<tr>
<td colspan="2"><input type="submit" value="Login" /></td>
</tr>

</table>
</form>
END_FORM;
    
    echo $form;
    
}

?>