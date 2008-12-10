package mmTtime;
require 0.01;
use strict;
$mmTtime::VERSION = 0.01;
#
#  Method: time
#
sub ttime {
   my $realtime;
   if (scalar @_ == 0) {
      $realtime = time;
   } else {
      $realtime = $_[0];
   }
   my $scaling = "[==TEST_IMPORT_SPEEDUP==]";
   if ($scaling eq "" or substr($scaling,0,2) eq "[=") {
       $scaling = 1;
   }
   if ($scaling <= 1) {
      return $realtime;
   } else {
      my $basistime = "[==TEST_IMPORT_BASETIME==]";
      return $basistime + ($realtime - $basistime)*$scaling;
   }
}
1;
