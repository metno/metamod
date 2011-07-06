package mmTtime;
require 0.01;
use strict;
$mmTtime::VERSION = 0.02;
use Metamod::Config;

#
#  Method: ttime
#
sub ttime {
   my $config = Metamod::Config->instance();
   my $realtime;
   if (scalar @_ == 0) {
      $realtime = time;
   } else {
      $realtime = $_[0];
   }
   my $scaling = $config->get("TEST_IMPORT_SPEEDUP") || 1;
   if ($scaling <= 1) {
      #printf STDERR "Real time = %s\n", scalar gmtime $realtime;
      return $realtime;
   } else {
      my $basistime = $config->get("TEST_IMPORT_BASETIME") || 0;
      my $maxdiff = 2147483647 - $realtime;
      my $diff = ($realtime - $basistime)*$scaling;
      # basetime > 3 months old will cause integer overflow
      die "TEST_IMPORT_BASETIME is too old!" if $diff > $maxdiff;
      my $faketime = $basistime + $diff;
      #printf STDERR "Speedup time = %s\n", scalar gmtime $faketime;
      return $faketime;
   }
}
1;
