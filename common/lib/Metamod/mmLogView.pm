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
    timefrom=HH:MM        - Select first time value in interval
    timeto=HH:MM          - Select last time value in interval
    level=LEVEL           - Select level (DEBUG, INFO, WARN, ERROR) Default: all
    logger=LOGGER         - Select logger. Default: all
    file=FILENAME         - Select basename of Perl source file. Default: all
    msg=STRING            - Select messages where the 'msg'-string contain the given string
    summarylogger         - Report count of all messages for each logger
    summarydate           - Report count of all messages for each date
    summarylevel          - Report count of all messages for each level
    summaryfile           - Report count of all messages for each Perl source file
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
my $allowedoptions = 'logfile date from to timefrom timeto level logger file msg exclude summarylogger summarylevel summarydate summaryfile summarymsg multiline ';
my $opcount = 0;
my $output = "";
foreach my $arg (@optargs) {
   $arg =~ s/^-*//;
   my @parts = split(/=/,$arg);
   my $optkey = $parts[0];
   my $optval = "";
   if (scalar @parts == 2) {
      $optval = $parts[1];
   }
   if ($optkey eq "exclude") {
      $optval = quotemeta($optval);
      $optval =~ s/SPCXYZ/ /mg;
      $optval =~ s/EQLXYZ/=/mg;
   }
   if ($optkey eq "msg") {
      $optval = quotemeta($optval);
      $optval =~ s/EQLXYZ/=/mg;
   }
   if (exists($options{$optkey}) && index("level logger file",$optkey) >= 0) {
      $options{$optkey} .= " " . $optval;
   } elsif (exists($options{$optkey}) && ($optkey eq "msg" || $optkey eq "exclude")) {
      $options{$optkey} .= "|" . $optval;
   } else {
      $options{$optkey} = $optval;
   }
   my $rex = '\b' . $optkey . '\b';
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
my %summaryfile = ();
my %summarymsg = ();
#
#  Loop through all lines read from a file:
#
# my $date_reg = '(\d\d\d\d-\d\d-\d\d)';
# my $time_reg = '(\d\d:\d\d)\S+';
# my $level_reg = '\[(\S+)\]';
# my $logger_reg = '(\S+)';
# my $file_reg = '\S+/([^ /]+)';
# my $msg_reg = 'msg:\s+(.+)';
# my $total_reg = qr/^$date_reg\s+$time_reg\s+$level_reg\s+$logger_reg\s+$file_reg\s+.*$msg_reg$/;
my $total_reg = '(\d\d\d\d-\d\d-\d\d)\s+(\d\d:\d\d)\S+\s+\[(\S+)\]\s+(\S+)\s+\S+\s+\S+/([^ /]+)\s+.*msg:\s+(.+)$';
while (<LOG>) {
   chomp($_);
   my $line = $_;
#   
#     Check if expression matches RE:
#   
   if ($line =~ m!$total_reg!) {
      my $date = $1; # First matching ()-expression
      my $time = $2;
      my $level = $3;
      my $logger = $4;
      my $file = $5;
      my $msg = $6;
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
      if ($continue && exists($options{"timefrom"}) && $options{"timefrom"} gt $time) {
         $continue = 0;
      }
      if ($continue && exists($options{"timeto"}) && $options{"timeto"} lt $time) {
         $continue = 0;
      }
      if ($continue && exists($options{"level"}) && index($options{"level"},$level) < 0) {
         $continue = 0;
      }
      if ($continue && exists($options{"logger"}) && index($options{"logger"},$logger) < 0) {
         $continue = 0;
      }
      if ($continue && exists($options{"file"}) && index($options{"file"},$file) < 0) {
         $continue = 0;
      }
      if ($continue && exists($options{"msg"}) && $msg !~ $options{"msg"}) {
         $continue = 0;
      }
      if ($continue && exists($options{"exclude"}) && $msg =~ $options{"exclude"}) {
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
      if ($continue && exists($options{"summaryfile"})) {
         if (exists($summaryfile{$file})) {
            $summaryfile{$file}++;
         } else {
            $summaryfile{$file} = 1;
         }
      }
      if ($continue && exists($options{"summarymsg"})) {
         if (exists($summarymsg{$msg})) {
            $summarymsg{$msg}++;
         } else {
            $summarymsg{$msg} = 1;
         }
      }
      if (exists($options{"summarylogger"}) ||
          exists($options{"summarylevel"}) ||
          exists($options{"summarydate"}) ||
          exists($options{"summaryfile"}) ||
          exists($options{"summarymsg"})) {
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
if (exists($options{"summaryfile"})) {
#   
#     Sort hash keys in hash key lexical order:
#   
   my @summaryfile_keys = sort {$a cmp $b} keys(%summaryfile);
   foreach my $file1 (@summaryfile_keys) {
      $output .= sprintf ('%-80s%8d',$file1, $summaryfile{$file1});
      $output .= "\n";
   }
}
if (exists($options{"summarymsg"})) {
#   
#     Sort hash keys in hash key lexical order:
#   
   my @summarymsg_keys = sort {$a cmp $b} keys(%summarymsg);
   foreach my $msg1 (@summarymsg_keys) {
      $output .= sprintf ('%-80s%8d',$msg1, $summarymsg{$msg1});
      $output .= "\n";
   }
}
close (LOG);
return $output;
}
1;
