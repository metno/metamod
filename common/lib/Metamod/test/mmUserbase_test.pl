#!/usr/bin/perl -w
use strict;
use File::Spec;
# small routine to get lib-directories relative to the installed file
use lib ('../../../lib', '../../../lib/Metamod');
use Metamod::Config;
use Metamod::mmUserbase;
my $mm_config  = Metamod::Config->new('../../../master_config.txt');
my $command_file = "../../../htdocs/funcs/test/mmUserbase_commands";
unless (-r $command_file) {die "Can not read from file: $command_file\n";}
open (COMMANDS,$command_file);
undef $/;
my $test_commands = <COMMANDS>;
my @test_commands = split(/\s*\n\s*/,$test_commands);
$/ = "\n"; 
close (COMMANDS);
my $userbase = Metamod::mmUserbase->new();
my $result;
foreach my $cmd (@test_commands) {
   if ($cmd eq "exit") {
      last;
   }
   my $method_call = '$userbase->' . $cmd;
   print $method_call . "\n";
   eval '$result = ' . $method_call . ';';
   if (!$result) {
      if ($userbase->exception_is_error()) {
         print '   ERROR:   ' . $userbase->get_exception() . "\n";
      } else {
         print '   INFO:    ' . $userbase->get_exception() . "\n";
      }
   } else {
      print "   OK   Result: ".$result."\n";
   }
}
