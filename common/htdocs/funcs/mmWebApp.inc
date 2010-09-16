<?php 

/**
 * A simple web application "framework" inspired by the Perl module CGI::Application.
 * This class however is a lot simpler and does not contain as much functionality.
 * 
 * This class is meant to be sub classed to implemented a new page/application.
 * 
 * The main idea of the class is that it has a run() method that when called will call
 * init(), dispatch() and end() to process one HTTP request.
 * 
 * See the functions for more details. 
 */
class MMWebApp {

    /**
     * The CGI parameter that will contain the name of the action to perform.
     * @var string
     */
    protected $actionParam = 'action';
    
    /**
     * An associative array of dispatch rules. A dispatch rules maps the name
     * of an action to a specific function in the class.
     * @var array
     */
    protected $dispatchRules = array();
    
    /**
     * The name of the default action. This name should correspond to one of
     * actions in the $dispatchRules array.
     * @var string
     */
    protected $defaultAction;     
    
    /**
     * A MMConfig object.
     * @var MMConfig
     */
    protected $config;
    
    /**
     * The logger object. 
     */
    protected $logger;
    
    public function __construct( &$logger ){

        $this->config = MMConfig::getInstance();        
        
        $this->logger = $logger;
        
    }
    
    /**
     * Set the name of the action parameter.
     * @param $paramName The name of the action parameter
     */
    public function setActionParam( $paramName ) {
        $this->actionParam = $paramName;
    }
    
    public function setDefaultAction( $defaultAction ) {
        $this->defaultAction = $defaultAction;
    }
    
    /**
     * Merges the current dispatch rules with the supplied dispatch rules.
     * @param $dispatchRules An associative array of dispatch rules.
     */
    public function addDispatchRules( $dispatchRules ){
        $this->dispatchRules = array_merge( $this->dispatchRules, $dispatchRules );
    }
    
    /**
     * Process one HTTP request and return the response as a string.
     */
    function run () {
        
        $this->init();
        $response = $this->dispatch();
        $response = $this->end( $response );
        return $response;
    }
    
    /**
     * Initialise the application.
     */
    public function init() {
        
        $this->logger->debug('Init start.');
        
        $this->setDefaultAction( 'notFound' );
        
        $dispatchRules = array(
            'notFound' => 'notFound', 
        );
        
        $this->addDispatchRules( $dispatchRules );
        $this->logger->debug('Init end.');
        
    }    
    
    /**
     * Perform the dispatching according to the dispatch table.
     */
    public function dispatch () {
        
        $action = $_REQUEST[ $this->actionParam ];
        if( !$action ){
            $action = $this->defaultAction;
        }
        $this->logger->debug("Dispatch action is '$action'");
        
        if( !isset( $this->dispatchRules[ $action ] ) ){            
            return "'$action' is not a supported action.";
        }
        
        $actionFunc = $this->dispatchRules[ $action ];
        $this->logger->debug("Action function is $actionFunc");
       
        return $this->$actionFunc();
        
    }
    
    public function end ($response) {
        return $response;
    }
    
    public function notFound() {
        return 'The action was not found.';
    }
    
    public function logout () {
        mmLogout();        
    }
    
    
}

?>