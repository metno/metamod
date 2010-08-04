<?php
   require_once("../mmConfig.inc");
   require_once("../mmUserbase.inc");
   $mmConfig = MMConfig::getInstance("../../../master_config.txt");
   $command_file = "mmUserbase_commands";
   if (! file_exists($command_file)) {
      echo "$command_file not found\n";
      exit;
   }
#   
#     Read all lines in a file into an array
#   
   $test_commands = file($command_file);
#   
   $userbase = new MM_Userbase();
   reset($test_commands);
   foreach ($test_commands as $cmd) {
      $cmdtrim = trim($cmd);
      if ($cmdtrim == "exit") {
         break;
      }
      $method_call = '$userbase->' . $cmdtrim;
      echo $method_call . "\n";
      eval ('$result = ' . $method_call . ';');
      if ($result === FALSE) {
         if ($userbase->exception_is_error()) {
            echo '   ERROR:   ' . $userbase->get_exception() . "\n";
         } else {
            echo '   INFO:    ' . $userbase->get_exception() . "\n";
         }
      } else {
         echo "   OK\n";
      }
   }
?>
