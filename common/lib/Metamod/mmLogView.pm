package mmLogView;
require 0.01;
use strict;
$mmLogView::VERSION = 0.01;
use File::Basename;

=pod

=head1 mmlog

Display various parts of the METAMOD log.

=head2 Usage: my $output = mmLogView::run("optionstring");

Optionstring is any combination of the following:

    logfile=LOGFILE       - Read LOGFILE. Default: metamod.log
    date=YYYY-MM-DD       - Select date
    from=YYYY-MM-DD       - Select first date in interval
    to=YYYY-MM-DD         - Select last date in interval
    level=LEVEL           - Select level (DEBUG, INFO, WARN, ERROR) Default: all
    logger=LOGGER         - Select logger. Default: all
    summarylogger         - Report count of all messages for each logger
    summarydate           - Report count of all messages for each date
    summarylevel          - Report count of all messages for each level
    multiline             - Show each log message on several lines.

=head2 Examples:

   my $output = mmLogView::run("date=2010-10-23 summarylogger");
   my $output = mmLogView::run("from=2010-10-23 to=2010-10-27 logger=Catalyst multiline");

=cut

sub run {
#
my $optionstring = shift;
my @optargs = split(/\s+/,$optionstring);
my %options = ();
my $logfile = "metamod.log";
my $allowedoptions = 'logfile date from to level logger summarylogger summarylevel summarydate multiline ';
my $opcount = 0;
my $output = "";
foreach my $arg (@optargs) {
   $arg =~ s/^-*//;
   my @parts = split(/=/,$arg);
   if (scalar @parts == 1) {
      $options{$parts[0]} = "";
   } elsif (scalar @parts == 2) {
      $options{$parts[0]} = $parts[1];
   }
   my $rex = '\b' . $parts[0] . '\b';
   if ($allowedoptions =~ /$rex/) {
      $opcount++;
   }
}
if (exists($options{"logfile"})) {
   $logfile = $options{"logfile"};
}
#
#  Open file for reading
#
unless (-r $logfile) {return "Can not read from file: $logfile\n";}
open (LOG,$logfile);
my %summarylogger = ();
my %summarylevel = ();
my %summarydate = ();
#
#  Loop through all lines read from a file:
#
while (<LOG>) {
   chomp($_);
   my $line = $_;
#   
#     Check if expression matches RE:
#   
   if ($line =~ /^(\d\d\d\d-\d\d-\d\d)\s+\S+\s+\[(\S+)\]\s+(\S+)\s/) {
      my $date = $1; # First matching ()-expression
      my $level = $2;
      my $logger = $3;
      my $continue = 1;
      if (exists($options{"date"}) && $options{"date"} ne $date) {
         $continue = 0;
      }
      if ($continue && exists($options{"from"}) && $options{"from"} gt $date) {
         $continue = 0;
      }
      if ($continue && exists($options{"to"}) && $options{"to"} lt $date) {
         $continue = 0;
      }
      if ($continue && exists($options{"level"}) && $options{"level"} ne $level) {
         $continue = 0;
      }
      if ($continue && exists($options{"logger"}) && $options{"logger"} ne $logger) {
         $continue = 0;
      }
      if ($continue && exists($options{"summarylogger"})) {
         if (exists($summarylogger{$logger})) {
            $summarylogger{$logger}++;
         } else {
            $summarylogger{$logger} = 1;
         }
      }
      if ($continue && exists($options{"summarylevel"})) {
         if (exists($summarylevel{$level})) {
            $summarylevel{$level}++;
         } else {
            $summarylevel{$level} = 1;
         }
      }
      if ($continue && exists($options{"summarydate"})) {
         if (exists($summarydate{$date})) {
            $summarydate{$date}++;
         } else {
            $summarydate{$date} = 1;
         }
      }
      if (exists($options{"summarylogger"}) || exists($options{"summarylevel"}) || exists($options{"summarydate"})) {
         $continue = 0;
      }
      if ($continue) {
         if (exists($options{"multiline"})) {
            if ($line =~ /^(.* in )(.* msg: )(.*)$/) {
               my $line1 = $1; # First matching ()-expression
               my $line2 = $2;
               my $line3 = $3;
               $output .= $line1 . "\n    " . $line2 . "\n    " . $line3 . "\n\n";
            }
         } else {
            $output .= $line . "\n";
         }
      }
   }
}
if (exists($options{"summarylogger"})) {
#   
#     Sort hash keys in hash value lexical order:
#   
   my @summarylogger_keys = sort {$summarylogger{$a} cmp $summarylogger{$b}} keys(%summarylogger);
   foreach my $log1 (@summarylogger_keys) {
      $output .= sprintf ('%-80s%8d',$log1, $summarylogger{$log1});
      $output .= "\n";
   }
}
if (exists($options{"summarylevel"})) {
#   
#     Sort hash keys in hash value lexical order:
#   
   my @summarylevel_keys = sort {$summarylevel{$a} cmp $summarylevel{$b}} keys(%summarylevel);
   foreach my $lev1 (@summarylevel_keys) {
      $output .= sprintf ('%-80s%8d',$lev1, $summarylevel{$lev1});
      $output .= "\n";
   }
}
if (exists($options{"summarydate"})) {
#   
#     Sort hash keys in hash key lexical order:
#   
   my @summarydate_keys = sort {$a cmp $b} keys(%summarydate);
   foreach my $date1 (@summarydate_keys) {
      $output .= sprintf ('%-80s%8d',$date1, $summarydate{$date1});
      $output .= "\n";
   }
}
close (LOG);
return $output;
}
1;
