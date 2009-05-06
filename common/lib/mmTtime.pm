package mmTtime;
require 0.01;
use strict;
$mmTtime::VERSION = 0.02;
use Metamod::Config;

#
#  Method: ttime
#
sub ttime {
   my $config = new Metamod::Config();
   my $realtime;
   if (scalar @_ == 0) {
      $realtime = time;
   } else {
      $realtime = $_[0];
   }
   my $scaling = $config->get("TEST_IMPORT_SPEEDUP") || 1;
   if ($scaling <= 1) {
      return $realtime;
   } else {
      my $basistime = $config->get("TEST_IMPORT_BASETIME") || 0;
      return $basistime + ($realtime - $basistime)*$scaling;
   }
}
1;
