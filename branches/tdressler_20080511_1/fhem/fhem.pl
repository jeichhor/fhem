#!/usr/bin/perl

################################################################
#
#  Copyright notice
#
#  (c) 2005 Copyright: Rudolf Koenig (r dot koenig at koeniglich dot de)
#  All rights reserved
#
#  This script free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  The GNU General Public License can be found at
#  http://www.gnu.org/copyleft/gpl.html.
#  A copy is found in the textfile GPL.txt and important notices to the license
#  from the author is found in LICENSE.txt distributed with these scripts.
#
#  This script is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  This copyright notice MUST APPEAR in all copies of the script!
#  Thanks for Tosti's site (<http://www.tosti.com/FHZ1000PC.html>)
#  for inspiration.
#
#  Homepage:  http://www.koeniglich.de/fhem/fhem.html


use strict;
use warnings;
use IO::Socket;
use Time::HiRes qw(gettimeofday);


##################################################
# Forward declarations
#
sub AnalyzeCommand($$);
sub AnalyzeCommandChain($$);
sub AnalyzeInput($);
sub AssignIoPort($);
sub CallFn(@);
sub CommandChain($$);
sub DoClose($);
sub FmtDateTime($);
sub FmtTime($);
sub GetLogLevel(@);
sub GlobalAttr($$);
sub HandleArchiving($);
sub HandleTimeout();
sub IOWrite($@);
sub InternalTimer($$$$);
sub Log($$);
sub OpenLogfile($);
sub PrintHash($$);
sub ResolveDateWildcards($@);
sub SemicolonEscape($);
sub SignalHandling();
sub TimeNow();
sub WriteStatefile();
sub XmlEscape($);
sub devspec2array($);
sub doGlobalDef($);
sub fhem($);
sub fhz($);

sub CommandAttr($$);
sub CommandDefaultAttr($$);
sub CommandDefine($$);
sub CommandDeleteAttr($$);
sub CommandDelete($$);
sub CommandGet($$);
sub CommandHelp($$);
sub CommandInclude($$);
sub CommandInform($$);
sub CommandList($$);
sub CommandModify($$);
sub CommandRereadCfg($$);
sub CommandRename($$);
sub CommandQuit($$);
sub CommandSave($$);
sub CommandSet($$);
sub CommandSetstate($$);
sub CommandSleep($$);
sub CommandShutdown($$);
sub CommandXmlList($$);
sub CommandTrigger($$);

##################################################
# Variables:
# global, to be able to access them from modules

#Special values in %modules (used if set):
# DefFn    - define a "device" of this type
# UndefFn  - clean up at delete
# ParseFn  - Interpret a raw message
# ListFn   - details for this "device"
# SetFn    - set/activate this device
# GetFn    - get some data from this device
# StateFn  - set local info for this device, do not activate anything
# TimeFn   - if the TRIGGERTIME of a device is reached, call this function
# NotifyFn - call this if some device changed its properties
# ReadFn - Reading from a filedescriptor (see FHZ/WS300)

#Special values in %defs:
# TYPE    - The name of the module it belongs to
# STATE   - Oneliner describing its state
# NR      - its "serial" number
# DEF     - its definition
# READINGS- The readings. Each value has a "VAL" and a "TIME" component.
# FD      - FileDescriptor. If set, it will be integrated into the global select
# IODev   - attached to io device
# CHANGED - Currently changed attributes of this device. Used by NotifyFn
# VOLATILE- Set if the definition should be saved to the "statefile"

use vars qw(%modules);		# List of loaded modules (device/log/etc)
use vars qw(%defs);		# FHEM device/button definitions
use vars qw(%attr);		# Attributes

use vars qw(%value);		# Current values, see commandref.html
use vars qw(%oldvalue);		# Old values, see commandref.html
use vars qw($nextat);           # used by the at module
use vars qw($init_done);        #

my $server;			# Server socket
my $currlogfile;		# logfile, without wildcards
my $logopened = 0;              # logfile opened or using stdout
my %client;			# Client array
my $rcvdquit;			# Used for quit handling in init files
my $sig_term = 0;		# if set to 1, terminate (saving the state)
my $modpath_set;                # Check if modpath was used, and report if not.
my $global_cl;			# To use from perl snippets
my $devcount = 0;		# To sort the devices
my %defaultattr;    		# Default attributes
my %intAt;			# Internal at timer hash.
my $intAtCnt=0;
my $reread_active = 0;
my $AttrList = "room comment";
my $cvsid = '$Id: fhem.pl,v 1.42 2008-05-09 13:58:10 rudolfkoenig Exp $';

$init_done = 0;

$modules{_internal_}{ORDER} = -1;
$modules{_internal_}{AttrList} =
        "archivecmd allowfrom archivedir configfile lastinclude logfile " .
        "modpath nrarchive pidfilename port statefile title userattr " .
        "verbose:1,2,3,4,5 version";


my %cmds = (
  "?"       => { Fn=>"CommandHelp",
	    Hlp=>",get this help" },
  "attr" => { Fn=>"CommandAttr", 
            Hlp=>"<devspec> <attrname> [<attrval>],set attribute for <devspec>" },
  "define"  => { Fn=>"CommandDefine",
	    Hlp=>"<name> <type> <options>,define a device/at/notify entity" },
  "deleteattr" => { Fn=>"CommandDeleteAttr", 
	    Hlp=>"<devspec> [<attrname>],delete attribute for <devspec>" },
  "delete"  => { Fn=>"CommandDelete",
	    Hlp=>"<devspec>,delete the corresponding definition(s)"},
  "get"     => { Fn=>"CommandGet", 
	    Hlp=>"<devspec> <type dependent>,request data from <devspec>" },
  "help"    => { Fn=>"CommandHelp",
	    Hlp=>",get this help" },
  "include" => { Fn=>"CommandInclude",
	    Hlp=>"<filename>,read the commands from <filenname>" },
  "inform" => { Fn=>"CommandInform",
	    Hlp=>"{on|off},echo all commands and events to this client" },
  "list"    => { Fn=>"CommandList",
	    Hlp=>"[devspec],list definitions and status info" },
  "modify"  => { Fn=>"CommandModify",
	    Hlp=>"device <options>,modify the definition (e.g. at, notify)" },
  "quit"    => { Fn=>"CommandQuit",
	    Hlp=>",end the client session" },
  "reload"  => { Fn=>"CommandReload",
	    Hlp=>"<module-name>,reload the given module (e.g. 99_PRIV)" },
  "rename"  => { Fn=>"CommandRename",
	    Hlp=>"<old> <new>,rename a definition" },
  "rereadcfg"  => { Fn=>"CommandRereadCfg",
	    Hlp=>",reread the config file" },
  "save"    => { Fn=>"CommandSave", 
	    Hlp=>"[configfile],write the configfile and the statefile" },
  "set"     => { Fn=>"CommandSet", 
	    Hlp=>"<devspec> <type dependent>,transmit code for <devspec>" },
  "setstate"=> { Fn=>"CommandSetstate", 
	    Hlp=>"<devspec> <state>,set the state shown in the command list" },
  "setdefaultattr" => { Fn=>"CommandDefaultAttr", 
	    Hlp=>"<attrname> <attrvalue>,set attr for following definitions" },
  "shutdown"=> { Fn=>"CommandShutdown",
	    Hlp=>",terminate the server" },
  "sleep"  => { Fn=>"CommandSleep",
            Hlp=>"<sec>,sleep for sec, 3 decimal places" },
  "trigger" => { Fn=>"CommandTrigger",
            Hlp=>"<devspec> <state>,trigger notify command" },
  "xmllist" => { Fn=>"CommandXmlList",
            Hlp=>",list definitions and status info as xml" },
);



###################################################
# Start the program
if(int(@ARGV) != 1 && int(@ARGV) != 2) {
  print "Usage:\n";
  print "as server: fhem configfile\n";
  print "as client: fhem [host:]port cmd\n";
  CommandHelp(undef, undef);
  exit(1);
}

doGlobalDef($ARGV[0]);

###################################################
# Client code
if(int(@ARGV) == 2) {
  my $buf;
  my $addr = $ARGV[0];
  $addr = "localhost:$addr" if($ARGV[0] !~ m/:/);
  $server = IO::Socket::INET->new(PeerAddr => $addr);
  die "Can't connect to $addr\n" if(!$server);
  syswrite($server, "$ARGV[1] ; quit\n");
  while(sysread($server, $buf, 256) > 0) {
    print($buf);
  }
  exit(0);
}
# End of client code
###################################################


###################################################
# Server initialization
my $ret = CommandInclude(undef, $attr{global}{configfile});
die($ret) if($ret);

# Go to background if the logfile is a real file (not stdout)
if($attr{global}{logfile} ne "-") {
  defined(my $pid = fork) || die "Can't fork: $!";
  exit(0) if $pid;
}

die("No modpath specified in the configfile.\n") if(!$modpath_set);
die("No port specified in the configfile.\n") if(!$server);

if($attr{global}{statefile} && -r $attr{global}{statefile}) {
  $ret = CommandInclude(undef, $attr{global}{statefile});
  die($ret) if($ret);
}
SignalHandling();

my $pfn = $attr{global}{pidfilename};
if($pfn) {
  die "$pfn: $!\n" if(!open(PID, ">$pfn"));
  print PID $$ . "\n";
  close(PID);
}
$init_done = 1;

Log 0, "Server started (version $attr{global}{version}, pid $$)";

################################################
# Main Loop
while (1) {
  my ($rout, $rin) = ('', '');

  vec($rin, $server->fileno(), 1) = 1;
  foreach my $p (keys %defs) {
    vec($rin, $defs{$p}{FD}, 1) = 1 if($defs{$p}{FD});
  }
  foreach my $c (keys %client) {
    vec($rin, fileno($client{$c}{fd}), 1) = 1;
  }

  my $nfound = select($rout=$rin, undef, undef, HandleTimeout());

  CommandShutdown(undef, undef) if($sig_term);

  if($nfound < 0) {
    next if ($! == 0);
    die("Select error $nfound / $!\n");
  }

  ###############################
  # Message from the hardware (FHZ1000/WS3000/etc)
  foreach my $p (keys %defs) {
    next if(!$defs{$p}{FD} || !vec($rout, $defs{$p}{FD}, 1));
    CallFn($p, "ReadFn", $defs{$p});
  }
  
  if(vec($rout, $server->fileno(), 1)) {
    my @clientinfo = $server->accept();
    if(!@clientinfo) {
      Log 1, "Accept failed: $!";
      next;
    }
    my ($port, $iaddr) = sockaddr_in($clientinfo[1]);
    my $caddr = inet_ntoa($iaddr);
    my $af = $attr{global}{allowfrom};
    if($af) {
      if(",$af," !~ m/,$caddr,/) {
        my $hostname = gethostbyaddr($iaddr, AF_INET);
        if(!$hostname || ",$af," !~ m/,$hostname,/) {
          Log 1, "Connection refused from $caddr:$port";
          close($clientinfo[0]);
          next;
        }
      }
    }

    my $fd = $clientinfo[0];
    $client{$fd}{fd}   = $fd;
    $client{$fd}{addr} = "$caddr:$port";
    $client{$fd}{buffer} = "";
    Log 4, "Connection accepted from $client{$fd}{addr}";
  }

  foreach my $c (keys %client) {

    next unless (vec($rout, fileno($client{$c}{fd}), 1));

    my $buf;
    my $ret = sysread($client{$c}{fd}, $buf, 256);
    if(!defined($ret) || $ret <= 0) {
      DoClose($c);
      next;
    }
    if(ord($buf) == 4) {	# EOT / ^D
      CommandQuit($c, "");
      next;
    }
    $buf =~ s/\r//g;
    $client{$c}{buffer} .= $buf;
    AnalyzeInput($c);
  }
}

################################################
#Functions ahead, no more "plain" code

################################################
sub
IsDummy($)
{
  my $devname = shift;

  return 1 if(defined($attr{$devname}) && defined($attr{$devname}{dummy}));
  return 0;
}

################################################
sub
IsIoDummy($)
{
  my $name = shift;

  return IsDummy($defs{$name}{IODev}{NAME})
                if($defs{$name} && $defs{$name}{IODev});
  return 1;
}


################################################
sub
GetLogLevel(@)
{
  my ($dev,$deflev) = @_;

  return $attr{$dev}{loglevel}
  	if(defined($attr{$dev}) && defined($attr{$dev}{loglevel}));
  return defined($deflev) ? $deflev : 2;
}


################################################
sub
Log($$)
{
  my ($loglevel, $text) = @_;

  return if($loglevel > $attr{global}{verbose});

  my @t = localtime;
  my $nfile = ResolveDateWildcards($attr{global}{logfile}, @t);
  OpenLogfile($nfile) if($currlogfile && $currlogfile ne $nfile);

  my $tim = sprintf("%04d.%02d.%02d %02d:%02d:%02d",
        $t[5]+1900,$t[4]+1,$t[3], $t[2],$t[1],$t[0]);

#  my ($seconds, $microseconds) = gettimeofday();
#  my $tim = sprintf("%04d.%02d.%02d %02d:%02d:%02d.%03d",
#        $t[5]+1900,$t[4]+1,$t[3], $t[2],$t[1],$t[0], $microseconds/1000);

  if($logopened) {
    print LOG "$tim $loglevel: $text\n";
  } else {
    print "$tim $loglevel: $text\n";
  }
  return undef;
}


#####################################
sub
DoClose($)
{
  my $c = shift;

  Log 4, "Connection closed for $client{$c}{addr}";
  close($client{$c}{fd});
  delete($client{$c});
  return undef;
}

#####################################
sub
IOWrite($@)
{
  my ($hash, @a) = @_;

  my $iohash = $hash->{IODev};
  if(!$iohash) {
    Log 5, "No IO device found for $hash->{NAME}";
    return;
  }

  no strict "refs";
  my $ret = &{$modules{$iohash->{TYPE}}{WriteFn}}($iohash, @a);
  use strict "refs";
  return $ret;
}

#####################################
sub
AnalyzeInput($)
{
  my $c = shift;

  while($client{$c}{buffer} =~ m/\n/) {
    my ($cmd, $rest) = split("\n", $client{$c}{buffer}, 2);
    $client{$c}{buffer} = $rest;
    if($cmd) {
      if($cmd =~ m/\\$/) {                     # Multi-line
        $client{$c}{prevlines} .= $cmd . "\n";
      } else {
        if($client{$c}{prevlines}) {
          $cmd = $client{$c}{prevlines} . $cmd;
          undef($client{$c}{prevlines});
        }
        AnalyzeCommandChain($c, $cmd);
        return if(!defined($client{$c}));         # quit
      }
    } else {
      $client{$c}{prompt} = 1;                  # Empty return
    }

    syswrite($client{$c}{fd}, $client{$c}{prevlines} ? "> " : "FHZ> ")
                if($client{$c}{prompt} && !$rest);
  }
}

#####################################
# i.e. split a line by ; (escape ;;), and execute each
sub
AnalyzeCommandChain($$)
{
  my ($c, $cmd) = @_;
  $cmd =~ s/#.*$//s;
  $cmd =~ s/;;/____/g;
  foreach my $subcmd (split(";", $cmd)) {
    $subcmd =~ s/____/;/g;
    AnalyzeCommand($c, $subcmd);
    last if($c && !defined($client{$c}));	 # quit
  }
}

#####################################
sub
AnalyzeCommand($$)
{
  my ($cl, $cmd) = @_;

  $cmd =~ s/^[ \t]*//;			# Strip space
  $cmd =~ s/[ \t]*$//;

  Log 5, "Cmd: >$cmd<";
  return if(!$cmd);

  if($cmd =~ m/^{.*}$/s) {		# Perl code

    $cmd =~ s/\\\n/ /g;                 # Multi-line
    # Make life easier for oneliners: 
    %value = ();
    foreach my $d (keys %defs) { $value{$d} = $defs{$d}{STATE } }
    my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime;
    my $we = (($wday==0 || $wday==6) ? 1 : 0);
    $month++;
    $year+=1900;

    $global_cl = $cl;
    my $ret = eval $cmd;
    $ret = $@ if($@);
    if($ret) {
      if($cl) {
	syswrite($client{$cl}{fd}, "$ret\n")
      } else {
	Log 3, $ret;
      }
    }
    return $ret;

  }

  if($cmd =~ m/^"(.*)"$/s) {		 # Shell code, always in bg
    system("$1 &"); 
    return;
  }

  $cmd =~ s/^[ \t]*//;
  my ($fn, $param) = split("[ \t][ \t]*", $cmd, 2);
  return if(!$fn);

  $fn = "setdefaultattr" if($fn eq "defattr"); # Compatibility mode

  #############
  # Search for abbreviation
  if(!defined($cmds{$fn})) {
    foreach my $f (sort keys %cmds) {
      if(length($f) > length($fn) && substr($f, 0, length($fn)) eq $fn) {
	Log 5, "$fn => $f";
        $fn = $f;
        last;
      }
    }
  }

  if(!defined($cmds{$fn})) {
    my $msg =  "Unknown command $fn, try help";
    if($cl) {
      syswrite($client{$cl}{fd}, "$msg\n");
    } else {
      Log 3, "$msg";
    }
    return $msg;
  }

  $param = "" if(!defined($param));
  no strict "refs";
  my $ret = &{$cmds{$fn}{Fn} }($cl, $param);
  use strict "refs";

  if($ret) {
    if($cl) {
      syswrite($client{$cl}{fd}, $ret . "\n");
    } else {
      Log 3, $ret;
    }
  }
  return $ret;
}

#####################################
my $namedef =
  "where <name> is either:\n" .
  "- a single device name\n" .
  "- a list seperated by komma (,)\n" .
  "- a regexp, if contains one of the following characters: *[]^\$\n" .
  "- a range seperated by dash (-)\n";

sub
devspec2array($)
{
  my ($name) = @_;
  return $name if(defined($defs{$name}));
  my @ret;

  foreach my $l (split(",", $name)) {   # List
    if($l =~ m/[*\[\]^\$]/) {           # Regexp
      push @ret, grep($_ =~ m/$l/, sort keys %defs);
      next;
    }
    if($l =~ m/-/) {                    # Range
      my ($lower, $upper) = split("-", $l, 2);
      push @ret, grep($_ ge $lower && $_ le $upper, sort keys %defs);
      next;
    }
    push @ret, $l;
  }

  return $name if(!@ret);               # No match, return the input
  return @ret;
}

#####################################
sub
CommandHelp($$)
{
  my ($cl, $param) = @_;

  my $str = "\n" .
            "Possible commands:\n\n" . 
            "Command   Parameter                 Description\n" .
	    "-----------------------------------------------\n";

  for my $cmd (sort keys %cmds) {
    my @a = split(",", $cmds{$cmd}{Hlp}, 2);

    $str .= sprintf("%-9s %-25s %s\n", $cmd, $a[0], $a[1]);
  }
  return $str;
}

#####################################
sub
CommandInclude($$)
{
  my ($cl, $arg) = @_;
  my $fh;
  if(!open($fh, $arg)) {
    return "Can't open $arg: $!";
  }

  my $bigcmd = "";
  $rcvdquit = 0;
  while(my $l = <$fh>) {
    chomp($l);
    if($l =~ m/^(.*)\\$/) {		# Multiline commands
      $bigcmd .= "$1\\\n";
    } else {
      AnalyzeCommandChain($cl, $bigcmd . $l);
      $bigcmd = "";
    }
    last if($rcvdquit);
  }
  close($fh);
  return undef;
}


#####################################
sub
OpenLogfile($)
{
  my $param = shift;

  close(LOG);
  $logopened=0;
  $currlogfile = $param;
  if($currlogfile eq "-") {

    open LOG, '>&STDOUT'    or die "Can't dup stdout: $!";

  } else {
    
    $defs{global}{currentlogfile} = $param;
    $defs{global}{logfile} = $attr{global}{logfile};
    HandleArchiving($defs{global});

    open(LOG, ">>$currlogfile") || return("Can't open $currlogfile: $!");
    # Redirect stdin/stderr

    open STDIN,  '</dev/null'  or return "Can't read /dev/null: $!";

    close(STDERR);
    open(STDERR, ">>$currlogfile") or return "Can't append STDERR to log: $!";
    STDERR->autoflush(1);

    close(STDOUT);
    open STDOUT, '>&STDERR'    or return "Can't dup stdout: $!";
    STDOUT->autoflush(1);
  }
  LOG->autoflush(1);
  $logopened = 1;
  return undef;
}


#####################################
sub
CommandRereadCfg($$)
{
  my ($cl, $param) = @_;

  WriteStatefile();

  foreach my $d (keys %defs) {
    my $ret = CallFn($d, "UndefFn", $defs{$d}, $d);
    return $ret if($ret);
  }

  my $cfgfile = $attr{global}{configfile};
  %defs = ();
  %attr = ();
  doGlobalDef($cfgfile);


  $reread_active=1;

  my $ret = CommandInclude($cl, $cfgfile);
  if(!$ret && $attr{global}{statefile} && -r $attr{global}{statefile}) {
    $ret = CommandInclude($cl, $attr{global}{statefile});
  }

  $reread_active=0;
  return $ret;
}

#####################################
sub
CommandQuit($$)
{
  my ($cl, $param) = @_;

  if(!$cl) {
    $rcvdquit = 1;
    return;
  }

  syswrite($client{$cl}{fd}, "Bye...\n") if($client{$cl}{prompt});
  DoClose($cl);
  return undef;
}

#####################################
sub
WriteStatefile()
{
  return if(!$attr{global}{statefile});
  if(!open(SFH, ">$attr{global}{statefile}")) {
    my $msg = "Cannot open $attr{global}{statefile}: $!";
    Log 1, $msg;
    return $msg;
  }

  my $t = localtime;
  print SFH "#$t\n";

  foreach my $d (sort keys %defs) {
    next if($defs{$d}{TEMPORARY});
    print SFH "define $d $defs{$d}{TYPE} $defs{$d}{DEF}\n"
        if($defs{$d}{VOLATILE});
    print SFH "setstate $d $defs{$d}{STATE}\n"
        if($defs{$d}{STATE} && $defs{$d}{STATE} ne "unknown");

    #############
    # Now the detailed list
    my $r = $defs{$d}{READINGS};
    if($r) {
      foreach my $c (sort keys %{$r}) {
        print SFH "setstate $d $r->{$c}{TIME} $c $r->{$c}{VAL}\n";
      }
    }
  }

  close(SFH);
}

#####################################
sub
CommandSave($$)
{
  my ($cl, $param) = @_;
  my $ret = WriteStatefile();

  $param = $attr{global}{configfile} if(!$param);
  return "No configfile attribute set and no argument specified" if(!$param);
  if(!open(SFH, ">$param")) {
    return "Cannot open $param: $!";
  }

  # Sort the devices by room
  my (%rooms, %savefirst);
  foreach my $d (sort keys %defs) {
    next if($d eq "global");
    my $r = ($attr{$d} && $attr{$d}{room}) ? $attr{$d}{room} : "~";
    $rooms{$r}{$d} = 1;
    $savefirst{$d} = $r if($attr{$d} && $attr{$d}{savefirst});
  }

  # First the global definitions
  my $t = localtime;
  print SFH "#$t\n\n";
  print SFH "attr global userattr $attr{global}{userattr}\n"
                                if($attr{global}{userattr});
  foreach my $a (sort keys %{$attr{global}}) {
    next if($a eq "configfile" || $a eq "version" || $a eq "userattr");
    print SFH "attr global $a $attr{global}{$a}\n";
  }
  print SFH "\n";

  # then the "important" ones (FHZ, WS300Device)
  foreach my $d (sort keys %savefirst) {
    my $r = $savefirst{$d};
    delete $rooms{$r}{$d};
    delete $rooms{$r} if(! %{$rooms{$r}});
    my $def = $defs{$d}{DEF};
    $def =~ s/;/;;/g;
    print SFH "define $d $defs{$d}{TYPE} $def\n";
    foreach my $a (sort keys %{$attr{$d}}) {
      next if($a eq "savefirst");
      print SFH "attr $d $a $attr{$d}{$a}\n";
    }
  }

  foreach my $r (sort keys %rooms) {
    print SFH "\nsetdefaultattr" . ($r ne "~" ? " room $r" : "") . "\n";
    foreach my $d (sort keys %{$rooms{$r}} ) {
      next if($defs{$d}{TEMPORARY});
      next if($defs{$d}{VOLATILE});
      if($defs{$d}{DEF}) {
        my $def = $defs{$d}{DEF};
        $def =~ s/;/;;/g;
        print SFH "define $d $defs{$d}{TYPE} $def\n";
      } else {
        print SFH "define $d $defs{$d}{TYPE}\n";
      }
      foreach my $a (sort keys %{$attr{$d}}) {
        next if($a eq "room");
        print SFH "attr $d $a $attr{$d}{$a}\n";
      }
    }
  }
  
  print SFH "setdefaultattr\n";        # Delete the last default attribute.

  print SFH "include $attr{global}{lastinclude}\n"
        if($attr{global}{lastinclude});


  close(SFH);
  return undef;
}

#####################################
sub
CommandShutdown($$)
{
  my ($cl, $param) = @_;
  Log 0, "Server shutdown";
  WriteStatefile();
  unlink($attr{global}{pidfilename}) if($attr{global}{pidfilename});
  exit(0);
}

#####################################
sub
DoSet(@)
{
  my @a = @_;

  my $dev = $a[0];
  return "No set implemented for $dev" if(!$modules{$defs{$dev}{TYPE}}{SetFn});
  my $ret = CallFn($dev, "SetFn", $defs{$dev}, @a);
  return $ret if($ret);

  shift @a;
  return DoTrigger($dev, join(" ", @a));
}


#####################################
sub
CommandSet($$)
{
  my ($cl, $param) = @_;
  my @a = split("[ \t][ \t]*", $param);
  return "Usage: set <name> <type-dependent-options>\n" .
         "$namedef" if(int(@a)<1);

  my @rets;
  foreach my $sdev (devspec2array($a[0])) {

    if(!defined($defs{$sdev})) {
      push @rets, "Please define $sdev first";
      next;
    }

    $a[0] = $sdev;
    my $ret = DoSet(@a);
    push @rets, $ret if($ret);

  }
  return join("\n", @rets);
}


#####################################
sub
CommandGet($$)
{
  my ($cl, $param) = @_;

  my @a = split("[ \t][ \t]*", $param);
  return "Usage: get <name> <type-dependent-options>\n" .
         "$namedef" if(int(@a) < 1);


  my @rets;
  foreach my $sdev (devspec2array($a[0])) {
    if(!defined($defs{$sdev})) {
      push @rets, "Please define $sdev first";
      next;
    }
    if(!$modules{$defs{$sdev}{TYPE}}{GetFn}) {
      push @rets, "No get implemented for $sdev";
      next;
    }

    $a[0] = $sdev;
    my $ret = CallFn($sdev, "GetFn", $defs{$sdev}, @a);
    push @rets, $ret if($ret);
  }
  return join("\n", @rets);
}

#####################################
# Parse a timespec: Either HH:MM:SS or HH:MM or { perfunc() }
sub
GetTimeSpec($)
{
  my ($tspec) = @_;
  my ($hr, $min, $sec, $fn);

  if($tspec =~ m/^([0-9]+):([0-5][0-9]):([0-5][0-9])$/) {
    ($hr, $min, $sec) = ($1, $2, $3);
  } elsif($tspec =~ m/^([0-9]+):([0-5][0-9])$/) {
    ($hr, $min, $sec) = ($1, $2, 0);
  } elsif($tspec =~ m/^{(.*)}$/) {
    $fn = $1;
    $tspec = eval $fn;
    if(!$@ && $tspec =~ m/^([0-9]+):([0-5][0-9]):([0-5][0-9])$/) {
      ($hr, $min, $sec) = ($1, $2, $3);
    } elsif(!$@ && $tspec =~ m/^([0-9]+):([0-5][0-9])$/) {
      ($hr, $min, $sec) = ($1, $2, 0);
    } else {
      $tspec = "<empty string>" if(!$tspec);
      return ("the at function \"$fn\" must return a timespec and not $tspec.",
      		undef, undef, undef, undef);
    }
  } else {
    return ("Wrong timespec $tspec: either HH:MM:SS or {perlcode}",
    		undef, undef, undef, undef);
  }
  return (undef, $hr, $min, $sec, $fn);
}


#####################################
sub
CommandDefine($$)
{
  my ($cl, $def) = @_;
  my @a = split("[ \t][ \t]*", $def, 3);

  return "Usage: define <name> <type> <type dependent arguments>"
  					if(int(@a) < 2);

  # Return a list of modules
  if(!$modules{$a[1]} || !$modules{$a[1]}{DefFn}) {
    my @m;
    foreach my $i (sort keys %modules) {
      push @m, $i if($modules{$i}{DefFn})
    }
    return "Unknown argument $a[1], choose one of " . join(" ",@m);
  }

  return "$a[0] already defined, delete it first" if(defined($defs{$a[0]}));
  return "Invalid characters in name (not A-Za-z0-9.:_): $a[0]"
                        if($a[0] !~ m/^[a-z0-9.:_]*$/i);

  my %hash;

  $hash{NAME}  = $a[0];
  $hash{TYPE}  = $a[1];
  $hash{STATE} = "???";
  $hash{DEF}   = $a[2] if(int(@a) > 2);
  $hash{NR}    = $devcount++;

  # If the device wants to issue initialization gets/sets, then it needs to be 
  # in the global hash.
  $defs{$a[0]} = \%hash;

  my $ret = CallFn($a[0], "DefFn", \%hash, $def);
  if($ret) {
    delete $defs{$a[0]}
  } else {
    foreach my $da (sort keys (%defaultattr)) {     # Default attributes
      CommandAttr($cl, "$a[0] $da $defaultattr{$da}");
    }
  }
  return $ret;
}

#####################################
sub
CommandModify($$)
{
  my ($cl, $def) = @_;
  my @a = split("[ \t]+", $def, 2);

  return "Usage: modify <name> <type dependent arguments>"
  					if(int(@a) < 2);

  # Return a list of modules
  return "Define $a[0] first" if(!defined($defs{$a[0]}));
  my $hash = $defs{$a[0]};

  $hash->{OLDDEF} = $hash->{DEF};
  $hash->{DEF} = $a[1];
  my $ret = CallFn($a[0], "DefFn", $hash, "$a[0] $hash->{TYPE} $a[1]");
  $hash->{DEF} = $hash->{OLDDEF} if($ret);
  delete($hash->{OLDDEF});
  return $ret;
}

#############
# internal
sub
AssignIoPort($)
{
  my ($hash) = @_;

  # Set the I/O device
  for my $p (sort { $defs{$b}{NR} cmp $defs{$a}{NR} } keys %defs) {
    my $cl = $modules{$defs{$p}{TYPE}}{Clients};
    if(defined($cl) && $cl =~ m/:$hash->{TYPE}:/) {
      $hash->{IODev} = $defs{$p};
      last;
    }
  }
  Log 3, "No I/O device found for $hash->{NAME}" if(!$hash->{IODev});
}


#############
sub
CommandDelete($$)
{
  my ($cl, $def) = @_;

  return "Usage: delete <name>\n" .
         "$namedef" if(!$def);

  my @rets;
  foreach my $sdev (devspec2array($def)) {
    if(!defined($defs{$sdev})) {
      push @rets, "Please define $sdev first";
      next;
    }

    my $ret = CallFn($sdev, "UndefFn", $defs{$sdev}, $sdev);
    if($ret) {
      push @rets, $ret;
      next;
    }
    delete($attr{$sdev});
    delete($defs{$sdev});
  }
  return join("\n", @rets);
}

#############
sub
CommandDeleteAttr($$)
{
  my ($cl, $def) = @_;

  my @a = split(" ", $def, 2);
  return "Usage: deleteattr <name> [<attrname>]\n" .
         "$namedef" if(@a < 1);

  my @rets;
  foreach my $sdev (devspec2array($a[0])) {

    if($sdev eq "global") {
      push @rets, "Cannot delete global parameters";
      next;
    }
    if(!defined($defs{$sdev})) {
      push @rets, "Please define $sdev first";
      next;
    }

    $a[0] = $sdev;
    $ret = CallFn($sdev, "AttrFn", "del", @a);
    if($ret) {
      push @rets, $ret;
      next;
    }

    if(@a == 1) {
      delete($attr{$sdev});
    } else {
      delete($attr{$sdev}{$a[1]}) if(defined($attr{$sdev}));
    }

  }

  return join("\n", @rets);
}

sub
PrintHash($$)
{
  my ($h, $lev) = @_;

  my ($str,$sstr) = ("","");
  foreach my $c (sort keys %{$h}) {

    if(ref($h->{$c})) {
      if(ref($h->{$c}) eq "HASH") {
        if(defined($h->{$c}{TIME}) && defined($h->{$c}{VAL})) {
          $str .= sprintf("%*s %-19s   %-15s %s\n",
                          $lev," ", $h->{$c}{TIME},$c,$h->{$c}{VAL});
        } elsif($c eq "IODev" || $c eq "HASH") {
          $str .= sprintf("%*s %-10s %s\n", $lev," ",$c, $h->{$c}{NAME});
        } else {
          $sstr .= sprintf("%*s %s:\n",
                          $lev, " ", uc(substr($c,0,1)).lc(substr($c,1)));
          $sstr .= PrintHash($h->{$c}, $lev+2);
        }
      }
    } else {
      $str .= sprintf("%*s %-10s %s\n", $lev," ",$c, $h->{$c});
    }
  }
  return $str . $sstr;
}

#####################################
sub
CommandList($$)
{
  my ($cl, $param) = @_;
  my $str = "";

  if(!$param) {

    $str = "\nType list <name> for detailed info.\n";
    my $lt = "";

    # Sort first by type then by name
    for my $d (sort { my $x = $modules{$defs{$a}{TYPE}}{ORDER} cmp
		  	      $modules{$defs{$b}{TYPE}}{ORDER};
		         $x = ($a cmp $b) if($x == 0); $x; } keys %defs) {
      my $t = $defs{$d}{TYPE};
      $str .= "\n$t:\n" if($t ne $lt);
      $str .= sprintf("  %-20s (%s)\n", $d, $defs{$d}{STATE});
      $lt = $t;
    }

  } else {

    foreach my $sdev (devspec2array($param)) {
      if(!defined($defs{$sdev})) {
        $str .= "No device named $param found";
        next;
      }
      $str .= "Internals:\n";
      $str .= PrintHash($defs{$sdev}, 2);
    }

  }

  return $str;
}


#####################################
sub
XmlEscape($)
{
  my $a = shift;
  return "" if(!$a);
  $a =~ s/\\\n/<br>/g;  # Multi-line
  $a =~ s/&/&amp;/g;
  $a =~ s/"/&quot;/g;
  $a =~ s/</&lt;/g;
  $a =~ s/>/&gt;/g;
  $a =~ s/([^ -~])/sprintf("#%02x;", ord($1))/ge;
  return $a;
}

#####################################
sub
CommandXmlList($$)
{
  my ($cl, $param) = @_;
  my $str = "<FHZINFO>\n";
  my $lt = "";

  delete($modules{""}) if(defined($modules{""}));
  for my $d (sort { my $x = $modules{$defs{$a}{TYPE}}{ORDER} cmp
    		            $modules{$defs{$b}{TYPE}}{ORDER};
    		    $x = ($a cmp $b) if($x == 0); $x; } keys %defs) {

      my $p = $defs{$d};
      my $t = $p->{TYPE};

      if($t ne $lt) {
        $str .= "\t</${lt}_LIST>\n" if($lt);
        $str .= "\t<${t}_LIST>\n";
      }
      $lt = $t;

      my $a1 = XmlEscape($p->{STATE});
      my $a2 = CommandSet(undef, "$d ?");
      $a2 =~ s/.*choose one of //;
      $a2 = "" if($a2 =~ /^No set implemented for/);
      $a2 = XmlEscape($a2);
      my $a3 = XmlEscape(getAllAttr($d));

      $str .= "\t\t<$t name=\"$d\" state=\"$a1\" sets=\"$a2\" attrs=\"$a3\">\n";

      foreach my $c (sort keys %{$p}) {
        next if(ref($p->{$c}));
        $str .= sprintf("\t\t\t<INT key=\"%s\" value=\"%s\"/>\n",
                        XmlEscape($c), XmlEscape($p->{$c}));
      }
      $str .= sprintf("\t\t\t<INT key=\"IODev\" value=\"%s\"/>\n",
                                        $p->{IODev}{NAME}) if($p->{IODev});

      foreach my $c (sort keys %{$attr{$d}}) {
        $str .= sprintf("\t\t\t<ATTR key=\"%s\" value=\"%s\"/>\n",
                        XmlEscape($c), XmlEscape($attr{$d}{$c}));
      }

      my $r = $p->{READINGS};
      if($r) {
        foreach my $c (sort keys %{$r}) {
	  $str .=
            sprintf("\t\t\t<STATE key=\"%s\" value=\"%s\" measured=\"%s\"/>\n",
                XmlEscape($c), XmlEscape($r->{$c}{VAL}), $r->{$c}{TIME});
        }
      }
      $str .= "\t\t</$t>\n";
  }
  $str .= "\t</${lt}_LIST>\n" if($lt);
  $str .= "</FHZINFO>\n";
  return $str;
}

#####################################
sub
CommandReload($$)
{
  my ($cl, $param) = @_;
  my %hash;

  $param =~ s,[\./],,g;
  $param =~ s,\.pm$,,g;
  my $file = "$modpath_set/$param.pm";
  return "Can't read $file: $!" if(! -r "$file");

  my $m = $param;
  $m =~ s,^([0-9][0-9])_,,;
  my $order = $1;
  Log 5, "Loading $file";

  my $ret;

  no strict "refs";
  # Get the correct module case from the initialize function name. We need
  # this as sometimes we live on a FAT fs with wrong case
  eval { 
    do "$file";
    foreach my $i (keys %main::) {
      if($i =~ m/^(${m})_initialize$/i) {
        $m = $1;
        last;
      }
    }
    $ret = &{ "${m}_Initialize" }(\%hash);
  };

  if($@) {
    return "$@";
  }
  use strict "refs";

  $modules{$m} = \%hash;
  $modules{$m}{ORDER} = $order;

  return undef;
}

#####################################
sub
CommandRename($$)
{
  my ($cl, $param) = @_;
  my ($old, $new) = split(" ", $param);

  return "Please define $old first" if(!defined($defs{$old}));
  return "Invalid characters in name (not A-Za-z0-9.:-): $new"
                        if($new !~ m/^[a-z0-9.:_-]*$/i);
  return "Cannot rename global" if($old eq "global");

  $defs{$new} = $defs{$old};
  delete($defs{$old});

  $attr{$new} = $attr{$old} if(defined($attr{$old}));
  delete($attr{$old});

  $oldvalue{$new} = $oldvalue{$old} if(defined($oldvalue{$old}));
  delete($oldvalue{$old});

  return undef;
}

#####################################
sub
getAllAttr($)
{
  my $d = shift;
  my $list = $AttrList;
  $list .= " " . $modules{$defs{$d}{TYPE}}{AttrList}
        if($modules{$defs{$d}{TYPE}}{AttrList});
  $list .= " " . $attr{global}{userattr}
        if($attr{global}{userattr});
  return $list;
}

sub
GlobalAttr($$)
{
  my ($name, $val) = @_;

  ################
  if($name eq "logfile") {
    my @t = localtime;
    my $ret = OpenLogfile(ResolveDateWildcards($val, @t));
    if($ret) {
      return $ret if($init_done);
      die($ret);
    }
  }

  ################
  elsif($name eq "port") {

    return undef if($reread_active);
    my ($port, $global) = split(" ", $val);
    if($global && $global ne "global") {
      return "Bad syntax, usage: attr global port <portnumber> [global]";
    }

    my $server2 = IO::Socket::INET->new(
          Proto        => 'tcp',
          LocalHost    => ($global ? undef : "localhost"),
          LocalPort    => $port,
          Listen       => 10,
          ReuseAddr    => 1);
    if(!$server2) {
      Log 1, "Can't open server port at $port: $!\n";
      return "$!" if($init_done);
      die "Can't open server port at $port: $!\n";
    }
    close($server) if($server);
    $server = $server2;
  }

  ################
  elsif($name eq "verbose") {
    if($val =~ m/^[0-5]$/) {
      return undef;
    } else {
      $attr{global}{verbose} = 3;
      return "Valid value for verbose are 0,1,2,3,4,5";
    }
  }

  elsif($name eq "modpath") {
    return "modpath must point to a directory where the FHEM subdir is"
        if(! -d "$val/FHEM");
    my $modpath = "$val/FHEM";

    opendir(DH, $modpath) || return "Can't read $modpath: $!";
    my $counter = 0;

    $modpath_set = $modpath;
    foreach my $m (sort grep(/^[0-9][0-9].*\.pm$/,readdir(DH))) {

      $m =~ s/\.pm$//;
      my $err = CommandReload(undef, $m);
      if($err) {
        Log 1, $err;
        exit(1);
      }
      $counter++;
    }
    closedir(DH);

    if(!$counter) {
      return "No modules found, set modpath to a directory in which a " .
             "subdirectory called \"FHEM\" exists wich in turn contains " .
             "the fhem module files <*>.pm";
    }

  }

  return undef;
}

#####################################
sub
CommandAttr($$)
{
  my ($cl, $param) = @_;
  my $ret = undef;
  my @a;
  @a = split(" ", $param, 3) if($param);
  
  return "Usage: attr <name> <attrname> [<attrvalue>]\n" .
        "$namedef" if(@a && @a < 2);

  my @rets;
  foreach my $sdev (devspec2array($a[0])) {

    if(!defined($defs{$sdev})) {
      push @rets, "Please define $sdev first";
      next;
    }

    my $list = getAllAttr($sdev);
    if($a[1] eq "?") {
      push @rets, "Unknown argument $a[1], choose one of $list";
      next;
    }
    if(" $list " !~ m/ ${a[1]}[ :;]/) {
      push @rets, "Unknown attribute $a[1], use attr global userattr $a[1]";
      next;
    }

    $a[0] = $sdev;
    $ret = CallFn($sdev, "AttrFn", "set", @a);
    if($ret) {
      push @rets, $ret;
      next;
    }

    if(defined($a[2])) {
      $attr{$sdev}{$a[1]} = $a[2];
    } else {
      $attr{$sdev}{$a[1]} = "1";
    }

    if($sdev eq "global") {
      $ret = GlobalAttr($a[1], $a[2]);
      if($ret) {
        push @rets, $ret;
        next;
      }
    }

  }
  return join("\n", @rets);
}


#####################################
# Default Attr
sub
CommandDefaultAttr($$)
{
  my ($cl, $param) = @_;

  my @a = split(" ", $param, 2);
  if(int(@a) == 0) {
    %defaultattr = ();
  } elsif(int(@a) == 1) {
    $defaultattr{$a[0]} = 1;
  } else {
    $defaultattr{$a[0]} = $a[1];
  } 
  return undef;
}

#####################################
sub
CommandSetstate($$)
{
  my ($cl, $param) = @_;
  
  my @a = split(" ", $param, 2);
  return "Usage: setstate <name> <state>\n" .
         "$namedef" if(@a != 2);


  my @rets;
  foreach my $sdev (devspec2array($a[0])) {
    if(!defined($defs{$sdev})) {
      push @rets, "Please define $sdev first";
      next;
    }

    my $d = $defs{$sdev};

    # Detailed state with timestamp
    if($a[1] =~ m/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} /) {
      my @b = split(" ", $a[1], 4);

      if($defs{$sdev}{TYPE} eq "FS20" && $b[2] ne "state") { # Compatibility
        $b[3] = $b[2] . ($b[3] ? " $b[3]" : "");
        $b[2] = "state";
      }

      my $tim = "$b[0] $b[1]";
      my $ret = CallFn($sdev, "StateFn", $d, $tim, $b[2], $b[3]);
      if($ret) {
        push @rets, $ret;
        next;
      }

      if(!$d->{READINGS}{$b[2]} || $d->{READINGS}{$b[2]}{TIME} lt $tim) {
        $d->{READINGS}{$b[2]}{VAL} = $b[3];
        $d->{READINGS}{$b[2]}{TIME} = $tim;
      }

    } else {
      $d->{STATE} = $a[1];

      $oldvalue{$sdev}{VAL} = $a[1];
      # This time is not the correct one, but we do not store a timestamp for
      # this reading.
      $oldvalue{$sdev}{TIME} = TimeNow();
    }
  }
  return join("\n", @rets);
}

#####################################
sub
CommandTrigger($$)
{
  my ($cl, $param) = @_;

  my ($dev, $state) = split(" ", $param, 2);
  return "Usage: trigger <name> <state>\n" .
         "$namedef" if(!$state);

  my @rets;
  foreach my $sdev (devspec2array($dev)) {
    if(!defined($defs{$sdev})) {
      push @rets, "Please define $sdev first";
      next;
    }
    my $ret = DoTrigger($sdev, $state);
    if($ret) {
      push @rets, $ret;
      next;
    }
  }
  return join("\n", @rets);
}

#####################################
sub
CommandInform($$)
{
  my ($cl, $param) = @_;

  if(!$cl) {
    return;
  }

  return "Usage: inform {on|off}" if($param !~ m/^(on|off)$/i);
  $client{$cl}{inform} = ($param =~ m/on/i);
  Log 4, "Setting inform to " . ($client{$cl}{inform} ? "on" : "off");

  return undef;
}

#####################################
sub
CommandSleep($$)
{
  my ($cl, $param) = @_;

  return "Cannot interpret $param as seconds" if($param !~ m/^[0-9\.]+$/);
  Log 4, "sleeping for $param";
  select(undef, undef, undef, $param);
  return undef;
}


#####################################
# Return the time to the next event (or undef if there is none)
# and call each function which was scheduled for this time
sub
HandleTimeout()
{
  return undef if(!$nextat);

  my $now = gettimeofday();
  return ($nextat-$now) if($now < $nextat);

  $nextat = 0;
  foreach my $i (keys %defs) {
    next if(!$defs{$i}{TRIGGERTIME});

    if($now >= $defs{$i}{TRIGGERTIME}) {
      CallFn($i, "TimeFn", $i);
    } else {
      $nextat = $defs{$i}{TRIGGERTIME}
        if(!$nextat || $nextat > $defs{$i}{TRIGGERTIME});
    }
  }

  #############
  # Check the internal list.
  foreach my $i (keys %intAt) {
    my $tim = $intAt{$i}{TRIGGERTIME};
    if($tim <= $now) {
      no strict "refs";
      &{$intAt{$i}{FN}}($intAt{$i}{ARG});
      use strict "refs";
      delete($intAt{$i});
    }
    $nextat = $tim if(!$nextat || $nextat > $tim);
  }

  return undef if(!$nextat);
  $now = gettimeofday();
  return ($now < $nextat) ? ($nextat-$now) : 0;
}


#####################################
sub
InternalTimer($$$$)
{
  my ($tim, $fn, $arg, $waitIfInitNotDone) = @_;

  if(!$init_done && $waitIfInitNotDone) {
    select(undef, undef, undef, $tim-gettimeofday());
    no strict "refs";
    &{$fn}($arg);
    use strict "refs";
    return;
  }

  $intAt{$intAtCnt}{TRIGGERTIME} = $tim;
  $intAt{$intAtCnt}{FN} = $fn;
  $intAt{$intAtCnt}{ARG} = $arg;
  $intAtCnt++;
  $nextat = $tim if(!$nextat || $nextat > $tim);
}


#####################################
sub
SignalHandling()
{
  if ($^O ne "MSWin32") {

    $SIG{'INT'}  = sub { $sig_term = 1; };
    $SIG{'QUIT'} = sub { $sig_term = 1; };
    $SIG{'TERM'} = sub { $sig_term = 1; };
    $SIG{'PIPE'} = 'IGNORE';
    $SIG{'CHLD'} = 'IGNORE';
    $SIG{'HUP'}  = sub { CommandRereadCfg(undef, "") };
  }
}

#####################################
sub
TimeNow()
{
  my @t = localtime;
  return sprintf("%04d-%02d-%02d %02d:%02d:%02d",
      $t[5]+1900, $t[4]+1, $t[3], $t[2], $t[1], $t[0]);
}

#####################################
sub
FmtDateTime($)
{
  my @t = localtime(shift);
  return sprintf("%04d-%02d-%02d %02d:%02d:%02d",
      $t[5]+1900, $t[4]+1, $t[3], $t[2], $t[1], $t[0]);
}

sub
FmtTime($)
{
  my @t = localtime(shift);
  return sprintf("%02d:%02d:%02d", $t[2], $t[1], $t[0]);
}

#####################################
sub
CommandChain($$)
{
  my ($retry, $list) = @_;
  my $ov = $attr{global}{verbose};
  my $oid = $init_done;

  $init_done = 0;
  $attr{global}{verbose} = 1;
  foreach my $cmd (@{$list}) {
    for(my $n = 0; $n < $retry; $n++) {
      Log 1, sprintf("Trying again $cmd (%d out of %d)", $n+1,$retry) if($n>0);
      my $ret = AnalyzeCommand(undef, $cmd);
      last if(!$ret || $ret !~ m/Timeout/);
    }
  }
  $attr{global}{verbose} = $ov;
  $init_done = $oid;
}

#####################################
sub
ResolveDateWildcards($@)
{
  my ($f, @t) = @_;
  return $f if(!$f);
  return $f if($f !~ m/%/);	# Be fast if there is no wildcard

  my $S = sprintf("%02d", $t[0]);      $f =~ s/%S/$S/g;
  my $M = sprintf("%02d", $t[1]);      $f =~ s/%M/$M/g;
  my $H = sprintf("%02d", $t[2]);      $f =~ s/%H/$H/g;
  my $d = sprintf("%02d", $t[3]);      $f =~ s/%d/$d/g;
  my $m = sprintf("%02d", $t[4]+1);    $f =~ s/%m/$m/g;
  my $Y = sprintf("%04d", $t[5]+1900); $f =~ s/%Y/$Y/g;
  my $w = sprintf("%d",   $t[6]);      $f =~ s/%w/$w/g;
  my $j = sprintf("%03d", $t[7]+1);    $f =~ s/%j/$j/g;
  my $U = sprintf("%02d", int(($t[7]-$t[6]+6)/7));   $f =~ s/%U/$U/g;
  my $V = sprintf("%02d", int(($t[7]-$t[6]+7)/7)+1); $f =~ s/%V/$V/g;
  
  return $f;
}

sub
SemicolonEscape($)
{
  my $cmd = shift;
  $cmd =~ s/^[ \t]*//;
  $cmd =~ s/[ \t]*$//;
  if($cmd =~ m/^{.*}$/s || $cmd =~ m/^".*"$/s) {
    $cmd =~ s/;/;;/g
  }
  return $cmd;
}

sub
DoTrigger($$)
{
  my ($dev, $ns) = @_;

  return "" if(!defined($defs{$dev}));

  if(defined($ns)) {
    $defs{$dev}{CHANGED}[0] = $ns;
  } elsif(!defined($defs{$dev}{CHANGED})) {
    return "";
  }
  $defs{$dev}{STATE} = $defs{$dev}{CHANGED}[0];

  # STATE && {READINGS}{state} should be the same
  my $r = $defs{$dev}{READINGS};
  $r->{state}{VAL} = $defs{$dev}{STATE} if($r && $r->{state});

  my $max = int(@{$defs{$dev}{CHANGED}});
  Log 5, "Triggering $dev ($max changes)";
  return "" if(defined($attr{$dev}) && defined($attr{$dev}{do_not_notify}));

  ################
  # Inform
  for(my $i = 0; $i < $max; $i++) {
    my $state = $defs{$dev}{CHANGED}[$i];
    my $fe = "$dev:$state";
    foreach my $c (keys %client) {
      next if(!$client{$c}{inform});
      syswrite($client{$c}{fd}, "$defs{$dev}{TYPE} $dev $state\n");
    }
  }


  ################
  # Log/notify modules
  # If modifying a device in its own trigger, do not call the triggers from
  # the inner loop.
  if(!defined($defs{$dev}{INTRIGGER})) {
    $defs{$dev}{INTRIGGER}=1;
    my $ret = "";
    foreach my $n (sort keys %defs) {
      if($modules{$defs{$n}{TYPE}}{NotifyFn}) {
        Log 5, "$dev trigger: Checking $n for notify";
        $ret .= CallFn($n, "NotifyFn", $defs{$n}, $defs{$dev});
      }
    }
    delete($defs{$dev}{INTRIGGER});
  }

  ####################
  # Used by triggered perl programs to check the old value
  # Not suited for multi-valued devices (KS300, etc)
  $oldvalue{$dev}{TIME} = TimeNow();
  $oldvalue{$dev}{VAL} = $defs{$dev}{CHANGED}[0];

  delete($defs{$dev}{CHANGED}) if(!defined($defs{$dev}{INTRIGGER}));

  Log 3, "NTFY return: $ret" if($ret);
  return $ret;
}

sub
CallFn(@)
{
  my $d = shift;
  my $n = shift;
  my $fn = $modules{$defs{$d}{TYPE}}{$n};
  return "" if(!$fn);
  no strict "refs";
  my $ret = &{$fn}(@_);
  use strict "refs";
  return $ret;
}

#####################################
# Used from perl oneliners inside of scripts
sub
fhem($)
{
  my $param = shift;
  return AnalyzeCommandChain($global_cl, $param);
}

# the "old" name, kept to make upgrade process easier
sub
fhz($)
{
  my $param = shift;
  return AnalyzeCommandChain($global_cl, $param);
}

sub
doGlobalDef($)
{
  my ($arg) = @_;

  $devcount = 0;
  $defs{global}{NR}    = $devcount++;
  $defs{global}{TYPE}  = "_internal_";
  $defs{global}{STATE} = "<no definition>";
  $defs{global}{DEF}   = "<no definition>";
  $defs{global}{NAME}  = "global";

  CommandAttr(undef, "global verbose 3");
  CommandAttr(undef, "global configfile $arg");
  CommandAttr(undef, "global logfile -");
  CommandAttr(undef, "global version =VERS= from =DATE= ($cvsid)");
}

# Make a directory and its parent directories if needed.
sub
HandleArchiving($)
{
  my ($log) = @_;
  my $ln = $log->{NAME};
  return if(!$attr{$ln});

  # If there is a command, call that
  my $cmd = $attr{$ln}{archivecmd};
  if($cmd) {
    $cmd =~ s/%/$log->{currentlogfile}/g;
    Log 2, "Archive: calling $cmd"; 
    system($cmd);
    return;
  }

  my $nra = $attr{$ln}{nrarchive};
  my $ard = $attr{$ln}{archivedir};
  return if(!defined($nra));

  # If nrarchive is set, then check the last files:
  # Get a list of files:

  my ($dir, $file);
  if($log->{logfile} =~ m,^(.+)/([^/]+)$,) {
    ($dir, $file) = ($1, $2);
  } else {
    ($dir, $file) = (".", $log->{logfile});
  }

  $file =~ s/%./.+/g;
  return if(!opendir(DH, $dir));
  my @files = sort grep {/^$file$/} readdir(DH);
  closedir(DH);

  my $max = int(@files)-$nra;
  for(my $i = 0; $i < $max; $i++) {
    if($ard) {
      Log 2, "Moving $files[$i] to $ard";
      rename("$dir/$files[$i]", "$ard/$files[$i]");
    } else {
      Log 2, "Deleting $files[$i]";
      unlink("$dir/$files[$i]");
    }
  }
}

