
if (!window.console) console = {};
log.log = console.log || function(){};
log.warn = console.warn || function(){};
log.error = console.error || function(){};
log.info = console.info || function(){};
