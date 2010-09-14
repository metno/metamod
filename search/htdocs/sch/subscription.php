<?php 

require_once '../funcs/mmConfig.inc';
require_once '../funcs/mmUserbase.inc';
require_once '../funcs/mmAuth.inc';

class SubscriptionPage {
    
    private $config;
    private $logger;
    private $action;
    private $auth;
    private $userbase;
    
    function __construct() {
        
        $this->config = MMConfig::getInstance();
        $this->config->initLogger();
        
        $this->logger = Logger::getLogger('metamod.search.subscription');
        
        $this->userbase = new MM_Userbase();
        
    }
    
    function __destruct() {
        
        if( isset( $this->userbase ) ){
            $success = $this->userbase->close();           
            if( !$success ){
                $this->logger->debug( $this->userbase->get_exception() );
            }
        }
        
    }
    
    public function dispatch() {
        
        # mmAuthenticate will redirect to login page if not logged in.
        $auth = mmAuthenticate();
        $this->auth = $auth;
        
        $action = $_REQUEST['action'];
        if( !$action ){
            $action = 'list_subscriptions';
        }
        
        $html = '';
        if( 'display_email_form' == $action ){
            $html = $this->displayEmailForm();
        } elseif ( 'store_email_subscription' == $action ){
            $html = $this->storeEmailSubscription();
        } elseif ( 'list_subscriptions' == $action ){
            $html = $this->listSubscriptions();
        } elseif( 'display_remove_subscription' == $action ){
            $html = $this->displayRemoveSubscription();
        } elseif( 'remove_subscription' == $action ){
            $html = $this->removeSubscription();
        } elseif( 'logout' == $action ){
            mmLogout();
        } else {
            $html = 'Invalid action';
        }
        
        return $html;
        
    }

    function displayEmailForm( $storeError = '' ) {
    
        $datasetName = $_REQUEST['dataset_name'];
        if( !$datasetName ){
            $errorHtml = $this->_createErrorHTML( 'Cannot create a subscription without a dataset name' );
            return $this->_html_page( 'New email subscription', '', $errorHtml );
        }
        
        $emailAddress = $_REQUEST['email_address'];
        $repeatedEmailAddress = $_REQUEST['repeated_email_address'];
        if( !$emailAddress ){
            
            $emailAddress = $this->getUserEmail();
            $repeatedEmailAddress = $emailAddress;
        }
        
        $form = $this->_email_form( $datasetName, $emailAddress, $repeatedEmailAddress, $storeError );
        return $form;
        
    }

    
    function storeEmailSubscription() {
        
        $emailAddress = $_REQUEST['email_address'];
        $repeatedEmailAddress = $_REQUEST['repeated_email_address'];
        
        if( $emailAddress != $repeatedEmailAddress ){
            return $this->displayEmailForm( 'Email addresses are not identical. Subscription not stored.' );
        }
    
        $applicationId = $this->config->getVar('APPLICATION_ID');
        $loginname = $this->getLoginname();
           
        $success = $this->userbase->user_lfind( $loginname, $applicationId );
        
        if( !$success ){
            $this->logger->error( "Failed to find an already logged in user: " . $this->userbase->get_exception() );
            $errorHtml = $this->_createErrorHTML( 'Cannot find the current user.' );
            return $this->_html_page( 'Store email subscription', '', $errorHtml );
        }
         
        $datasetName = $_REQUEST['dataset_name'];
        $success = $this->userbase->dset_find( $applicationId, $datasetName );
        if( !$success ){
            $this->logger->error( "Failed to find dataset in userbase: " . $this->userbase->get_exception() );
            $errorHtml = $this->_createErrorHTML( 'Cannot find the selected dataset.' );
            return $this->_html_page( 'Store email subscription', '', $errorHtml );        
        }
        
        # cannot determine success by logging at return value since false is both used for empty set and error.
        $this->userbase->infoUDS_set( 'SUBSCRIPTION_XML', 'USER_AND_DATASET' );
        $subscriptionXML = <<<END_XML
<subscription type="email" xmlns="http://www.met.no/schema/metamod/subscription">
<param name="address" value="$emailAddress" />
</subscription>
END_XML;
    
        if( $this->userbase->infoUDS_get() ){
            $success = $this->userbase->infoUDS_put($subscriptionXML);        
        } else {
            $success = $this->userbase->infoUDS_new($subscriptionXML);
        }   
        
        if( !$success ){
            $this->logger->error( "Failed to insert subscription: " . $this->userbase->get_exception() );
            $errorHtml = $this->_createErrorHTML( 'The subscription could not be inserted.' );
            return $this->_html_page( 'Store email subscription', '', $errorHtml );         
        }       
        
        $this->_sendConfirmationEmail( $datasetName, $emailAddress, $userEmail );
        
        return $this->listSubscriptions('New subscription created.' );
    }

    function listSubscriptions($infoMsg = '', $errorMsg = '' ){
             
        $applicationId = $this->config->getVar('APPLICATION_ID');
        $userLogin = $this->getLoginname();
        
        $success = $this->userbase->user_lfind( $userLogin, $applicationId );    
    
        if( !$success ){
            $this->logger->error( "Failed to find an already logged in user: " . $this->userbase->get_exception() );
            $errorHtml = $this->_createErrorHTML( 'Cannot find the current user.' );
            return $this->_html_page( 'My subscriptions', '', $errorHtml );
        }
        
        $num_subscriptions = $this->userbase->infoUDS_set( 'SUBSCRIPTION_XML', 'USER' );
        if( !$num_subscriptions ){     
            return $this->_html_page( 'My subscriptions', 'You have no subscriptions' );
        }
    
        $subscriptionsHTML = '<table width="100%">';
        $subscriptionsHTML .= '<tr><td class="header">Subscription information</td>';
        $subscriptionsHTML .= '<td class="header">&nbsp;</td></tr>';
        do {
            $this->userbase->dset_isync();
            $datasetName = $this->userbase->dset_get('ds_name');
            
            $subscriptionsHTML .= '<tr>';
            $subscriptionsHTML .= "<td><strong>Dataset: $datasetName</strong><br />";
            
            $subscription = new SimpleXMLElement($this->userbase->infoUDS_get());
            foreach( $subscription->param as $param ){
                $subscriptionsHTML .= '<strong>' . $param['name'] . ': </strong>' . $param['value'] . '<br />';
            }        
            
            $deleteURL = "subscription.php?action=display_remove_subscription&dataset_name=$datasetName";
            $subscriptionsHTML .= '</td>';
            $subscriptionsHTML .= '<td><a href="' . $deleteURL . '">Delete</a></td>';        
            $subscriptionsHTML .= '</tr>';        
            
        } while ( $this->userbase->infoUDS_next() );
        $subscriptionsHTML .= '</table>';
    
        $msg = '';
        if( $infoMsg ){
            $msg = $this->_createInfoHTML( $infoMsg ); 
        } elseif( $errorMsg ){
            $msg = $this->_createInfoHTML( $errorMsg );
        }
        
        return $this->_html_page( 'My subscriptions', $subscriptionsHTML, $msg ); 
        
    }
    
    function displayRemoveSubscription() {
        
        $datasetName = $_REQUEST['dataset_name'];

        if(!$datasetName){
            return $this->_html_page('Remove subscription', '', 'No dataset name given. Cannot remove subscription');
        }
        
        $applicationId = $this->config->getVar('APPLICATION_ID');

        $success = $this->userbase->dset_find( $applicationId, $datasetName );
        if( !$success ){
            $this->logger->error( "Failed to find dataset in userbase: " . $this->userbase->get_exception() );
            $errorHtml = $this->_createErrorHTML( 'Cannot find the selected dataset.' );
            return $this->_html_page( 'Remove subscription', '', $errorHtml );        
        }
        
        $deleteForm = <<<END_HTML
<h2>Remove your subscription for dataset '$datasetName'?</h2>
<form name="remove_subscription" method="POST" action="subscription.php">
    <input type="hidden" name="action" value="remove_subscription" />
    <input type="hidden" name="dataset_name" value="$datasetName" />    
    <button type="submit">Remove subscription</button>
</form>
END_HTML;

        return $this->_html_page( 'Remove subscription', $deleteForm );
        
    }
    
    function removeSubscription(){
        
        $datasetName = $_REQUEST['dataset_name'];

        if(!$datasetName){
            return $this->_html_page('Remove subscription', '', 'No dataset name given. Cannot remove subscription');
        }
        
        $applicationId = $this->config->getVar('APPLICATION_ID');
        $userLogin = $this->getLoginname();

        $success = $this->userbase->user_lfind( $userLogin, $applicationId );    
    
        if( !$success ){
            $this->logger->error( "Failed to find an already logged in user: " . $this->userbase->get_exception() );
            $errorHtml = $this->_createErrorHTML( 'Cannot find the current user.' );
            return $this->_html_page( 'Remove subscription', '', $errorHtml );
        }        
        
        $success = $this->userbase->dset_find( $applicationId, $datasetName );
        if( !$success ){
            $this->logger->error( "Failed to find dataset in userbase: " . $this->userbase->get_exception() );
            $errorHtml = $this->_createErrorHTML( 'Cannot find the selected dataset.' );
            return $this->_html_page( 'Remove subscription', '', $errorHtml );        
        }

        $num_info = $this->userbase->infoUDS_set('SUBSCRIPTION_XML', 'USER_AND_DATASET');
        if( $num_info ){
            $success = $this->userbase->infoUDS_delete();
            if( !$success ){
                $this->logger->error( "Failed to delete subscription: " . $this->userbase->get_exception() );
                $errorHtml = $this->_createErrorHTML( 'An error occured when removing the subscription.' );
                return $this->listSubscriptions( '', 'An error occured when removing the subscription.' );                        
            }
            return $this->listSubscriptions( 'Subscription was removed', '' );
        }
        
        return $this->listSubscriptions( 'Subscription was not found. Probably already removed', '' );        
        
    }

    
    function _email_form ( $dataset_name, $email_address, $repeated_email_address, $storeError ){
   
        $email_form = <<<END_FORM
<form name="subscription" method="POST">
<input type="hidden" name="action" value="store_email_subscription" />

<table>

<tr>
<td>Dataset name</td>
<td><input type="text" readonly="readonly" size="35" name="dataset_name" value="$dataset_name" /></td>
</tr>

<tr>
<td>Recipient address</td>
<td><input type="text" size="35" name="email_address" value="$email_address" /></td>
</tr>

<tr>
<td>Recipient address (repeated)</td>
<td><input type="text" size="35" name="repeated_email_address" value="$repeated_email_address" /></td>
</tr>

<tr style="text-align: center">
<td colspan="2"><button type="submit">Register subscription</button></td>
</tr>

</form>
END_FORM;

        if( $storeError ){
            $storeError = $this->_createErrorHTML( $storeError );
        }
        
        return $this->_html_page( 'New email subscription', $email_form, $storeError );
    }

    function _html_page( $title, $content, $message = '' ){
    
        $html_page = <<<END_HTML
<html>
<head>
<title>$title</title>
<style type="text/css">
body {
    font-family: sans-serif;
}

div#page {
    width: 800px;
    margin-left: auto;
    margin-right: auto;
}

div#menu {
    float: left;
    width: 800px;
    border-bottom: 2px solid silver;
}

div.menu_item {
    float: left;
    padding: 0px 15px 5px 15px;
}

div#content {
    float: left;
    width: 800px;
    padding: 25px 10px 0px 10px;
}

div.error {
    border: 1px solid red;
    background-color: #ffadad;
    font-decoration: italic;
    width: 90%;
    margin-left: auto;
    margin-right: auto;
    padding: 5px 10px 5px 10px;
    margin-bottom: 10px;
}

div.info {
    border: 1px solid green;
    background-color: #c4ffbe;
    font-decoration: italic;
    width: 90%;
    margin-left: auto;
    margin-right: auto;
    padding: 5px 10px 5px 10px;
    margin-bottom: 10px;
}

table {
    border-collapse: collapse;    
}

td {
    border: 1px solid silver;
}

td.header {
    border-bottom: 2px solid gray;
    text-align: center;
    font-size: 1.1em;
    font-weight: bolder;
}

</style>
</head>
<body>
<div id="page">

<div id="menu">
<div class="menu_item"><a href="subscription.php?action=display_email_form">New subscription</a></div>
<div class="menu_item"><a href="subscription.php?action=list_subscriptions">My subscriptions</a></div>
<div class="menu_item"><a href="subscription.php?action=logout">Logout</a></div>
</div>

<div id="content">

$message

$content
</div>
</div>
END_HTML;

        return $html_page;
        
    }
    
    function _sendConfirmationEmail( $datasetName, $emailAddress, $userEmail ){
    
        $baseURL = $this->config->getVar('BASE_PART_OF_EXTERNAL_URL');
        $localURL = $this->config->getVar('LOCAL_URL');
    
        $fullURL = $baseURL . $localURL . "/sch/subscription?action=display_remove_subscription&dataset_name=$datasetName";
        
        $emailSubject = 'New METAMOD subscription';
        $emailBody = <<<END_MSG
A new subscription for the dataset '$datasetName' has been created. 
A notification will be sent to '$emailAddress' when new data files are made available.

To remove your subscription go to this address: $fullURL
END_MSG;

        $fromAddress = $this->config->getVar('OPERATOR_EMAIL');
        $emailHeader = "From: $fromAddress\r\n";
    
        $success = mail( $emailAddress, $emailSubject, $emailBody, $emailHeader );    
        
        if( !$success ) {
            $this->logger->error('Failed to send confirmation email');
            return false;
        }
        
        # in case a subscription is set up to a different address than the users address
        # also send notification to the users address.
        if( $emailAddress != $userEmail ){
            mail( $userEmail, $emailSubject, $emailBody, $emailHeader );
        }
        
        return true;
    }

    private function getLoginname() {
        
        return $this->auth->getUsername();       
    
    }
    
    private function getUserEmail() {

        $applicationId = $this->config->getVar('APPLICATION_ID');
        $loginname = $this->getLoginname();
           
        $success = $this->userbase->user_lfind( $loginname, $applicationId );
        
        if( !$success ){
            $this->logger->error( "Failed to find an already logged in user: " . $this->userbase->get_exception() );
            $errorHtml = $this->_createErrorHTML( 'Cannot find the current user.' );
            return $this->_html_page( 'Store email subscription', '', $errorHtml );
        }
        
        return $this->userbase->user_get('u_email');
        
    }
    
    function _createInfoHTML( $msg ){
        
        $msgHTML = <<<END_HTML
<div class="info">
$msg
</div>
END_HTML;
        
        return $msgHTML; 
        
    }

    function _createErrorHTML( $msg ){
        
        $msgHTML = <<<END_HTML
<div class="error">
$msg
</div>
END_HTML;
    
        return $msgHTML; 
        
    }    
    
}





$subscription_page = new SubscriptionPage();
echo $subscription_page->dispatch();








?>