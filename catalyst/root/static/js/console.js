
if (!window.console) console = {};
var log = new Object();
log.debug = console.log   || function(){};
log.warn  = console.warn  || function(){};
log.error = console.error || function(){};
log.info  = console.info  || function(){};
log.fatal = log.error;
