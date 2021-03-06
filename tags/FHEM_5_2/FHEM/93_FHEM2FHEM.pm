##############################################
# $Id$
package main;

use strict;
use warnings;
use Time::HiRes qw(gettimeofday);


sub FHEM2FHEM_Read($);
sub FHEM2FHEM_Ready($);
sub FHEM2FHEM_OpenDev($$);
sub FHEM2FHEM_CloseDev($);
sub FHEM2FHEM_Disconnected($);
sub FHEM2FHEM_Define($$);
sub FHEM2FHEM_Undef($$);

sub
FHEM2FHEM_Initialize($)
{
  my ($hash) = @_;

# Provider
  $hash->{ReadFn}  = "FHEM2FHEM_Read";
  $hash->{WriteFn} = "FHEM2FHEM_Write";
  $hash->{ReadyFn} = "FHEM2FHEM_Ready";
  $hash->{noRawInform} = 1;

# Normal devices
  $hash->{DefFn}   = "FHEM2FHEM_Define";
  $hash->{UndefFn} = "FHEM2FHEM_Undef";
  $hash->{AttrList}= "dummy:1,0 " .
                     "loglevel:0,1,2,3,4,5,6 ";
}

#####################################
sub
FHEM2FHEM_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);

  if(@a != 4 || !($a[3] =~ m/^(LOG|RAW):(.*)$/)) {
    my $msg = "wrong syntax: define <name> FHEM2FHEM host[:port] ".
                        "[LOG:regexp|RAW:device]";
    Log 2, $msg;
    return $msg;
  }

  $hash->{informType} = $1;
  if($1 eq "LOG") {
    $hash->{regexp} = $2;

  } else {
    my $rdev = $2;
    my $iodev = $defs{$rdev};
    return "Undefined local device $rdev" if(!$iodev);
    $hash->{rawDevice} = $rdev;
    $hash->{Clients} = $iodev->{Clients};
    $hash->{Clients} = $modules{$iodev->{TYPE}}{Clients}
        if(!$hash->{Clients});

  }

  my $dev = $a[2];
  if($dev !~ m/^.+:[0-9]+$/) {       # host:port
    $dev = "$dev:7072";
    $hash->{Host} = $dev;
  }
  $hash->{Host} = $dev;


  FHEM2FHEM_CloseDev($hash);    # Modify...
  return FHEM2FHEM_OpenDev($hash, 0);
}

#####################################
sub
FHEM2FHEM_Undef($$)
{
  my ($hash, $arg) = @_;
  FHEM2FHEM_CloseDev($hash); 
  return undef;
}

sub
FHEM2FHEM_Write($$)
{
  my ($hash,$fn,$msg) = @_;
  my $dev = $hash->{Host};

  if(!$hash->{TCPDev2}) {
    my $conn = IO::Socket::INET->new(PeerAddr => $dev);
    return if(!$conn);  # Hopefuly it is reported elsewhere
    $hash->{TCPDev2} = $conn;
  }
  my $rdev = $hash->{rawDevice};
  syswrite($hash->{TCPDev2}, "iowrite $rdev $fn $msg\n");
}

#####################################
# called from the global loop, when the select for hash->{FD} reports data
sub
FHEM2FHEM_Read($)
{
  my ($hash) = @_;

  my $buf = FHEM2FHEM_SimpleRead($hash);
  my $name = $hash->{NAME};

  ###########
  # Lets' try again: Some drivers return len(0) on the first read...
  if(defined($buf) && length($buf) == 0) {
    $buf = FHEM2FHEM_SimpleRead($hash);
  }

  if(!defined($buf) || length($buf) == 0) {
    FHEM2FHEM_Disconnected($hash);
    return "";
  }

  my $data = $hash->{PARTIAL};
  Log 5, "FHEM2FHEM/RAW: $data/$buf";
  $data .= $buf;

  while($data =~ m/\n/) {
    my $rmsg;
    ($rmsg,$data) = split("\n", $data, 2);
    $rmsg =~ s/\r//;
    Log GetLogLevel($name,4), "$name: $rmsg";

    if($hash->{informType} eq "LOG") {
      my ($type, $name, $msg) = split(" ", $rmsg, 3);
      my $re = $hash->{regexp};
      next if($re && !($name =~ m/^$re$/ || "$name:$msg" =~ m/^$re$/));

      if(!$defs{$name}) {
        LoadModule($type);
        $defs{$name}{NAME}  = $name;
        $defs{$name}{TYPE}  = $type;
        $defs{$name}{READINGS}{STATE} = 'fake';
        DoTrigger($name, $msg);
        delete($defs{$name});

      } else {
        DoTrigger($name, $msg);

      }

    } else {    # RAW
      my ($type, $rname, $msg) = split(" ", $rmsg, 3);
      my $rdev = $hash->{rawDevice};
      next if($rname ne $rdev);
      Dispatch($defs{$rdev}, $msg, undef);

    }
  }
  $hash->{PARTIAL} = $data;
}


#####################################
sub
FHEM2FHEM_Ready($)
{
  my ($hash) = @_;

  return FHEM2FHEM_OpenDev($hash, 1);
}

########################
sub
FHEM2FHEM_CloseDev($)
{
  my ($hash) = @_;
  my $name = $hash->{NAME};
  my $dev = $hash->{Host};

  return if(!$dev);
  
  $hash->{TCPDev}->close() if($hash->{TCPDev});
  $hash->{TCPDev2}->close() if($hash->{TCPDev2});
  delete($hash->{TCPDev});
  delete($hash->{TCPDev2});
  delete($selectlist{"$name.$dev"});
  delete($readyfnlist{"$name.$dev"});
  delete($hash->{FD});
}

########################
sub
FHEM2FHEM_OpenDev($$)
{
  my ($hash, $reopen) = @_;
  my $dev = $hash->{Host};
  my $name = $hash->{NAME};

  $hash->{PARTIAL} = "";
  Log 3, "FHEM2FHEM opening $name at $dev"
        if(!$reopen);

  # This part is called every time the timeout (5sec) is expired _OR_
  # somebody is communicating over another TCP connection. As the connect
  # for non-existent devices has a delay of 3 sec, we are sitting all the
  # time in this connect. NEXT_OPEN tries to avoid this problem.
  if($hash->{NEXT_OPEN} && time() < $hash->{NEXT_OPEN}) {
    return;
  }

  my $conn = IO::Socket::INET->new(PeerAddr => $dev);
  if($conn) {
    delete($hash->{NEXT_OPEN})

  } else {
    Log(3, "Can't connect to $dev: $!") if(!$reopen);
    $readyfnlist{"$name.$dev"} = $hash;
    $hash->{STATE} = "disconnected";
    $hash->{NEXT_OPEN} = time()+60;
    return "";
  }

  $hash->{TCPDev} = $conn;
  $hash->{FD} = $conn->fileno();
  delete($readyfnlist{"$name.$dev"});
  $selectlist{"$name.$dev"} = $hash;

  if($reopen) {
    Log 1, "FHEM2FHEM $dev reappeared ($name)";
  } else {
    Log 3, "FHEM2FHEM device opened ($name)";
  }

  $hash->{STATE}= "connected";
  DoTrigger($name, "CONNECTED") if($reopen);
  my $msg = $hash->{informType} eq "LOG" ? "inform on" : "inform raw";
  syswrite($hash->{TCPDev}, $msg . "\n");
  return undef;
}

sub
FHEM2FHEM_Disconnected($)
{
  my $hash = shift;
  my $dev = $hash->{Host};
  my $name = $hash->{NAME};

  return if(!defined($hash->{FD}));                 # Already deleted
  Log 1, "$dev disconnected, waiting to reappear";
  FHEM2FHEM_CloseDev($hash);
  $readyfnlist{"$name.$dev"} = $hash;               # Start polling
  $hash->{STATE} = "disconnected";

  # Without the following sleep the open of the device causes a SIGSEGV,
  # and following opens block infinitely. Only a reboot helps.
  sleep(5);

  DoTrigger($name, "DISCONNECTED");
}

########################
sub
FHEM2FHEM_SimpleRead($)
{
  my ($hash) = @_;
  my $buf;
  if(!defined(sysread($hash->{TCPDev}, $buf, 256))) {
    FHEM2FHEM_Disconnected($hash);
    return undef;
  }
  return $buf;
}

1;
