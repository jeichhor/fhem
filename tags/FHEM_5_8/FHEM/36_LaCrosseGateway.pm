# $Id$

package main;

use strict;
use warnings;
use Time::HiRes qw(gettimeofday);
use Time::Local;

my $clients = ":PCA301:EC3000:LaCrosse:Level:EMT7110:KeyValueProtocol";

my %matchList = (
  "1:PCA301"           => "^\\S+\\s+24",
  "2:EC3000"           => "^\\S+\\s+22",
  "3:LaCrosse"         => "^(\\S+\\s+9 |OK\\sWS\\s)",
  "4:EMT7110"          => "^OK\\sEMT7110\\s",
  "5:Level"            => "^OK\\sLS\\s",
  "6:KeyValueProtocol" => "^OK\\sVALUES\\s",
);

sub LaCrosseGateway_Initialize($) {
  my ($hash) = @_;

  require "$attr{global}{modpath}/FHEM/DevIo.pm";

  $hash->{ReadFn}         = "LaCrosseGateway_Read";
  $hash->{WriteFn}        = "LaCrosseGateway_Write";
  $hash->{ReadyFn}        = "LaCrosseGateway_Ready";
  $hash->{DefFn}          = "LaCrosseGateway_Define";
  $hash->{FingerprintFn}  = "LaCrosseGateway_Fingerprint";
  $hash->{UndefFn}        = "LaCrosseGateway_Undef";
  $hash->{SetFn}          = "LaCrosseGateway_Set";
  $hash->{AttrFn}         = "LaCrosseGateway_Attr";
  $hash->{AttrList}       = " Clients"
                           ." MatchList"
                           ." dummy"
                           ." initCommands"
                           ." timeout"
                           ." watchdog"
                           ." disable:0,1"
                           ." tftFile"
                           ." kvp:dispatch,readings,both"
                           ." ownSensors:dispatch,readings,both"
                           ." mode:USB,WiFi,Cable"
                           ." usbFlashCommand"
                           ." $readingFnAttributes";

}

#=======================================================================================
sub LaCrosseGateway_Fingerprint($$) {
}

#=======================================================================================
sub LaCrosseGateway_Define($$) {
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);

  if(@a != 3) {
    my $msg = "wrong syntax: define <name> LaCrosseGateway {none | devicename[\@baudrate] | devicename\@directio | hostname:port}";
    Log3 undef, 2, $msg;
    return $msg;
  }

  DevIo_CloseDev($hash);

  my $name = $a[0];
  my $dev = $a[2];

  $hash->{Clients} = $clients;
  $hash->{MatchList} = \%matchList;
  $hash->{TIMEOUT} = 0.5;

  if( !defined( $attr{$name}{usbFlashCommand} ) ) {
    $attr{$name}{usbFlashCommand} = "./FHEM/firmware/esptool.py -b 921600 -p [PORT] write_flash -ff 80m -fm dio -fs 4MB-c1 0x00000 [BINFILE] > [LOGFILE]"
  }
  if($dev eq "none") {
    Log3 $name, 1, "$name device is none, commands will be echoed only";
    $attr{$name}{dummy} = 1;
    return undef;
  }
  $dev .= "\@57600" if( $dev !~ m/\@/ && $def !~ m/:/ );
  $hash->{DeviceName} = $dev;

  my $ret = LaCrosseGateway_Connect($hash);
  
  return $ret;
}

#=======================================================================================
sub LaCrosseGateway_Undef($$) {
  my ($hash, $arg) = @_;
  my $name = $hash->{NAME};

  foreach my $d (sort keys %defs) {
    if(defined($defs{$d}) && defined($defs{$d}{IODev}) && $defs{$d}{IODev} == $hash) {
      my $lev = ($reread_active ? 4 : 2);
      Log3 $name, $lev, "deleting port for $d";
      delete $defs{$d}{IODev};
    }
  }

  DevIo_CloseDev($hash);
  
  return undef;
}

#=======================================================================================
sub LaCrosseGateway_RemoveLaCrossePair($) {
  my $hash = shift;
  delete($hash->{LaCrossePair});
}

#=======================================================================================
sub LaCrosseGateway_Set($@) {
  my ($hash, @a) = @_;
  my $name = shift @a;
  my $cmd = shift @a;
  my $arg = join(" ", @a);

  my $list = "raw connect LaCrossePairForSec flash nextionUpload parse reboot";
  return $list if( $cmd eq '?' || $cmd eq '');

  if ($cmd eq "raw") {
    Log3 $name, 4, "set $name $cmd $arg";
    LaCrosseGateway_SimpleWrite($hash, $arg);
  } 
  elsif ($cmd eq "flash") {
    my @args = split(' ', $arg);
    my $log = "";
    my @deviceName = split('@', $hash->{DeviceName});
    my $port = $deviceName[0];
    my $logFile = AttrVal("global", "logdir", "./log") . "/LaCrosseGatewayFlash.log";
    my $hexFile = "./FHEM/firmware/JeeLink_LaCrosseGateway.bin";
    
    return "The file '$hexFile' does not exist" if(!-e $hexFile);

    $log .= "flashing LaCrosseGateway $name\n";
    $log .= "hex file: $hexFile\n";

    if(AttrVal($name, "mode", "WiFi") eq "WiFi") {
      eval "use LWP::UserAgent";
      return "\nERROR: Please install LWP::UserAgent" if($@);

      eval "use HTTP::Request::Common";
      return "\nERROR: Please install HTTP::Request::Common" if($@);

      $log .= "Mode is LaCrosseGateway OTA-update\n";
      DevIo_CloseDev($hash);
      readingsSingleUpdate($hash, "state", "disconnected", 1);
      $log .= "$name closed\n";

      my @spl = split(':', $hash->{DeviceName});
      my $targetIP = $spl[0];
      my $targetURL = "http://" . $targetIP . "/ota/firmware.bin";
      $log .= "target: $targetURL\n";

      my $request = POST($targetURL, Content_Type => 'multipart/form-data', Content => [ file => [$hexFile, "firmware.bin"] ]);
      my $userAgent = LWP::UserAgent->new;
      $userAgent->timeout(60);
      my $response = $userAgent->request($request);
      if ($response->is_success) {
        $log .= "\n\nSketch reports:\n";
        $log .= $response->decoded_content;
      }
      else {
        $log .= "\nERROR: " . $response->code . " " . $response->decoded_content;
      }
    }
    else {
      $log .= "Mode is LaCrosseGateway USB-update\n";
      my $usbFlashCommand = AttrVal($name, "usbFlashCommand", "");

      if ($usbFlashCommand ne "") {
        if (-e $logFile) {
          unlink $logFile;
        }

        my $command = $usbFlashCommand;
        $command =~ s/\Q[PORT]\E/$port/g;
        $command =~ s/\Q[BINFILE]\E/$hexFile/g;
        $command =~ s/\Q[LOGFILE]\E/$logFile/g;

        $log .= "command: $command\n\n";
        `$command`;

        local $/ = undef;
        if (-e $logFile) {
          open FILE, $logFile;
          my $logText = <FILE>;
          close FILE;
          $log .= "--- esptool ---------------------------------------------------------------------------------\n";
          $log .= $logText;
          $log .= "--- esptool ---------------------------------------------------------------------------------\n\n";
        }
        else {
          $log .= "WARNING: esptool created no log file\n\n";
        }
      }
      else {
        $log .= "\n\nNo usbFlashCommand found. Please define this attribute.\n\n";
      }
    }

    LaCrosseGateway_Connect($hash);
    $log .= "$name opened\n";
    
    return $log;
  }
   elsif ($cmd eq "nextionUpload") {
    my $log = "";
    my @deviceName = split('@', $hash->{DeviceName});
    my $port = $deviceName[0];
    my $logFile = AttrVal("global", "logdir", "./log") . "/NextionUpload.log";
    my $tftFile = AttrVal($name, "tftFile", "./FHEM/firmware/nextion.tft");
    
    return "The file '$tftFile' does not exist" if(!-e $tftFile);

    $log .= "upload Nextion firmware to $name\n";
    $log .= "tft file: $tftFile\n";

    eval "use LWP::UserAgent";
    return "\nERROR: Please install LWP::UserAgent" if($@);

    eval "use HTTP::Request::Common";
    return "\nERROR: Please install HTTP::Request::Common" if($@);

    my @spl = split(':', $hash->{DeviceName});
    my $targetIP = $spl[0];
    my $targetURL = "http://" . $targetIP . "/ota/nextion";
    $log .= "target: $targetURL\n";

    my $request = POST($targetURL, Content_Type => 'multipart/form-data', Content => [ file => [$tftFile, "nextion.tft"] ]);
    my $userAgent = LWP::UserAgent->new;
    $userAgent->timeout(300);
    my $response = $userAgent->request($request);
    if ($response->is_success) {
      $log .= "\n\nLGW reports:\n";
      $log .= $response->decoded_content;
    }
    else {
      $log .= "\nERROR: " . $response->code . " " . $response->decoded_content;
    }
    
    return $log;
  }
  elsif ($cmd eq "LaCrossePairForSec") {
    my @args = split(' ', $arg);

    return "Usage: set $name LaCrossePairForSec <seconds_active> [ignore_battery]" if(!$arg || $args[0] !~ m/^\d+$/ || ($args[1] && $args[1] ne "ignore_battery") );
    $hash->{LaCrossePair} = $args[1]?2:1;
    InternalTimer(gettimeofday()+$args[0], "LaCrosseGateway_RemoveLaCrossePair", $hash, 0);
  } 
  elsif ($cmd eq "connect") {
    DevIo_CloseDev($hash);
    return LaCrosseGateway_Connect($hash);
  }
  elsif ($cmd eq "reboot") {
    if(AttrVal($name, "mode", "WiFi") eq "WiFi") {
      LaCrosseGateway_SimpleWrite($hash, "8377e\n");
    }
    else {
      my $po = $hash->{USBDev};
      $po->rts_active(0);
      $po->dtr_active(0);
      select undef, undef, undef, 0.01;
      $po->rts_active(1);
      $po->dtr_active(1);
    }


  }
  elsif ($cmd eq "parse") {
    LaCrosseGateway_Parse($hash, $hash, $name, $arg);
  } 
  else {
    return "Unknown argument $cmd, choose one of ".$list;
  }

  return undef;
}

#=======================================================================================
sub LaCrosseGateway_OnInitTimer($) {
  my ($hash) = @_;
  my $name = $hash->{NAME};

  LaCrosseGateway_SimpleWrite($hash, "v\n");
}

#=======================================================================================
sub LaCrosseGateway_DoInit($) {
  my $hash = shift;
  my $name = $hash->{NAME};
  
  my $enabled = AttrVal($name, "disable", "0") != "1";
  if($enabled) {
    readingsSingleUpdate($hash, "state", "opened", 1);
    if(AttrVal($name, "mode", "") ne "USB") {
      InternalTimer(gettimeofday() +3, "LaCrosseGateway_OnInitTimer", $hash, 1);
    }
  }
  else {
    readingsSingleUpdate($hash, "state", "disabled", 1);
  }
  
  return undef;
}

#=======================================================================================
sub LaCrosseGateway_Ready($) {
  my ($hash) = @_;
  my $name = $hash->{NAME};

  LaCrosseGateway_Connect($hash, 1);

  # This is relevant for windows/USB only
  my $po = $hash->{USBDev};
  my ($BlockingFlags, $InBytes, $OutBytes, $ErrorFlags);
  if($po) {
    ($BlockingFlags, $InBytes, $OutBytes, $ErrorFlags) = $po->status;
  }
  return ($InBytes && $InBytes>0);
}

#=======================================================================================
sub LaCrosseGateway_Write($$)  {
  my ($hash, $cmd, $msg) = @_;
  my $name = $hash->{NAME};
  my $arg = $cmd;
  $arg .= " " . $msg if(defined($msg));

  LaCrosseGateway_SimpleWrite($hash, $arg);
}

#=======================================================================================
sub LaCrosseGateway_Read($) {
  my ($hash) = @_;
  my $name = $hash->{NAME};

  my $buf = DevIo_SimpleRead($hash);
  return "" if(!defined($buf));

  my $data = $hash->{PARTIAL};
  $data .= $buf;

  while($data =~ m/\n/) {
    my $rmsg;
    ($rmsg,$data) = split("\n", $data, 2);
    $rmsg =~ s/\r//;
    LaCrosseGateway_Parse($hash, $hash, $name, $rmsg) if($rmsg);
  }
  $hash->{PARTIAL} = $data;
}

#=======================================================================================
sub LaCrosseGateway_DeleteKVPReadings($) {
  my ($hash) = @_;
  delete $hash->{READINGS}{"FramesPerMinute"};
  delete $hash->{READINGS}{"RSSI"};
  delete $hash->{READINGS}{"UpTime"};
}


#=======================================================================================
sub LaCrosseGateway_HandleKVP($$) {
  my ($hash, $kvp) = @_;
  
  readingsBeginUpdate($hash);
  
  if($kvp =~ m/UpTimeText=(.*?)(\,|\ ,)/) {
    readingsBulkUpdate($hash, "UpTime", $1);
  }
  if($kvp =~ m/RSSI=(.*?)(\,|\ ,)/) {
    readingsBulkUpdate($hash, "RSSI", $1);
  }
  if($kvp =~ m/FramesPerMinute=(.*?)(\,|\ ,)/) {
    readingsBulkUpdate($hash, "FramesPerMinute", $1);
  }
  
  readingsEndUpdate($hash, 1);
}

#=======================================================================================
sub LaCrosseGateway_DeleteOwnSensorsReadings($) {
  my ($hash) = @_;
  delete $hash->{READINGS}{"temperature"};
  delete $hash->{READINGS}{"humidity"};
  delete $hash->{READINGS}{"pressure"};
}

#=======================================================================================
sub LaCrosseGateway_HandleOwnSensors($$) {
  my ($hash, $data) = @_;

  readingsBeginUpdate($hash);

  my @bytes = split( ' ', substr($data, 5) );
  return "" if(@bytes < 14);

  my $temperature = undef;
  my $humidity = undef;
  my $pressure = undef;

  if($bytes[2] != 0xFF) {
    $temperature = ($bytes[2]*256 + $bytes[3] - 1000)/10;
    readingsBulkUpdate($hash, "temperature", $temperature);
  }

  if($bytes[4] != 0xFF) {
    $humidity = $bytes[4];
    readingsBulkUpdate($hash, "humidity", $humidity);
  }

  if(@bytes > 15 && $bytes[14] != 0xFF) {
    $pressure = $bytes[14] * 256 + $bytes[15];
    readingsBulkUpdate($hash, "pressure", $pressure);
  }

  readingsEndUpdate($hash, 1);

  delete $hash->{READINGS}{"temperature"} if !$temperature;
  delete $hash->{READINGS}{"humidity"} if !$humidity;
  delete $hash->{READINGS}{"pressure"} if !$pressure;

}

#=======================================================================================
sub LaCrosseGateway_HandleAnalogData($$) {
  my ($hash, $data) = @_;

  if ($data =~ m/^LGW ANALOG /) {
    readingsBeginUpdate($hash);

    my @bytes = split( ' ', substr($data, 10) );
    return "" if(@bytes < 2);

    my $value = $bytes[0]*256 + $bytes[1];
    readingsBulkUpdate($hash, "analog", $value);

    readingsEndUpdate($hash, 1);

}}

#=======================================================================================
sub LaCrosseGateway_Parse($$$$) {
  my ($hash, $iohash, $name, $msg) = @_;

  next if (!$msg || length($msg) < 1);
  return if ($msg =~ m/^\*\*\*CLEARLOG/);

  return if ($msg =~ m/[^\x20-\x7E]/);



  if ($msg =~ m/^LGW/) {
    if ($msg =~ /ALIVE/) {
      $hash->{Alive} = TimeNow();
    }

    LaCrosseGateway_HandleAnalogData($hash, $msg);

    return;
  }

  if($msg =~ m/^\[LaCrosseITPlusReader.Gateway/ ) {
    $hash->{model} = $msg;

    my $attrVal = AttrVal($name, "timeout", undef);
    if(defined($attrVal)) {
      my ($timeout, $interval) = split(',', $attrVal);
      if (!$interval) {
        $hash->{Alive} = TimeNow();
      }
    }

    if (ReadingsVal($name, "state", "") eq "opened") {
      if (my $initCommandsString = AttrVal($name, "initCommands", undef)) {
        my @initCommands = split(' ', $initCommandsString);
        foreach my $command (@initCommands) {
          LaCrosseGateway_SimpleWrite($hash, $command);
        }
      }

      readingsSingleUpdate($hash, "state", "initialized", 1);
    }

    return;
  }

  $hash->{"${name}_MSGCNT"}++;
  $hash->{"${name}_TIME"} = TimeNow();
  readingsSingleUpdate($hash, "state", $hash->{READINGS}{state}{VAL}, 0);
  $hash->{RAWMSG} = $msg;

  if($msg =~ m/^OK WS \d{1,3} 4 /) {
    my $osa = AttrVal($name, "ownSensors", "dispatch");
    if($osa eq "readings") {
      LaCrosseGateway_HandleOwnSensors($hash, $msg);
      return;
    }
    elsif ($osa eq "both") {
      LaCrosseGateway_HandleOwnSensors($hash, $msg);
    }
    else {
      LaCrosseGateway_DeleteOwnSensorsReadings($hash);
    }
  }

  if($msg =~ m/^OK VALUES LGW/) {
    my $osa = AttrVal($name, "kvp", "dispatch");
    if($osa eq "readings") {
      LaCrosseGateway_HandleKVP($hash, $msg);
      return;
    }
    elsif ($osa eq "both") {
      LaCrosseGateway_HandleKVP($hash, $msg);
    }
    else {
      LaCrosseGateway_DeleteKVPReadings($hash);
    }

    return if AttrVal($name, "dispatchKVP", "1") ne "1";
  }

  Dispatch($hash, $msg, "");
}

#=======================================================================================
sub LaCrosseGateway_SimpleWrite(@) {
  my ($hash, $msg, $nocr) = @_;
  return if(!$hash);

  my $name = $hash->{NAME};
  Log3 $name, 5, "SW: $msg";

  $msg .= "\n" unless($nocr);

  $hash->{USBDev}->write($msg)    if($hash->{USBDev});
  syswrite($hash->{TCPDev}, $msg) if($hash->{TCPDev});
  syswrite($hash->{DIODev}, $msg) if($hash->{DIODev});

  # Some linux installations are broken with 0.001, T01 returns no answer
  select(undef, undef, undef, 0.01);
}

#=======================================================================================
sub LaCrosseGateway_Connect($;$) {
  my ($hash, $mode) = @_;
  my $name = $hash->{NAME};
  
  $mode = 0 if!($mode);
  my $enabled = AttrVal($name, "disable", "0") != "1";
  if($enabled) {
    my $ret = DevIo_OpenDev($hash, $mode, "LaCrosseGateway_DoInit");
    return $ret;
  }
  
  return undef;
}

#=======================================================================================
sub LaCrosseGateway_TriggerWatchdog($) {
  my ($hash) = @_;
  my $name = $hash->{NAME};
  my $watchDog = "";

  my $watchDogAttribute = AttrVal($name, "watchdog", undef);
  if($watchDogAttribute) {
    $watchDog = "=$watchDogAttribute"
  }

  my $command = "\"WATCHDOG Ping$watchDog\"";

  LaCrosseGateway_SimpleWrite($hash, $command);
}

#=======================================================================================
sub LaCrosseGateway_OnConnectTimer($) {
  my ($hash) = @_;
  my $name = $hash->{NAME};

  RemoveInternalTimer($hash, "LaCrosseGateway_OnConnectTimer");

  my $attrVal = AttrVal($name, "timeout", undef);
  if(defined($attrVal)) {
    my ($timeout, $interval) = split(',', $attrVal);
    my $useOldMethod = $interval;
    $interval = $timeout if !$interval;

    InternalTimer(gettimeofday() + $interval, "LaCrosseGateway_OnConnectTimer", $hash, 0);

    if(AttrVal($name, "disable", "0") != "1") {
      my ($date, $time, $year, $month, $day, $hour, $min, $sec, $timestamp, $alive);
      if($useOldMethod) {
        $alive = InternalVal($name, "${name}_TIME", "2000-01-01 00:00:00");
      }
      else {
        LaCrosseGateway_TriggerWatchdog($hash);
        $timeout += 5;
        $alive = $hash->{Alive};
        $alive = "2000-01-01 00:00:00" if !$alive;
      }

      ($date, $time) = split( ' ', $alive);
      ($year, $month, $day) = split( '-', $date);
      ($hour, $min, $sec) = split( ':', $time);
      $month -= 01;
      $timestamp = timelocal($sec, $min, $hour, $day, $month, $year);

      if (gettimeofday() - $timestamp > $timeout) {
        return LaCrosseGateway_Connect($hash, 1);
      }

    }

  }
}

#=======================================================================================
sub LaCrosseGateway_Attr(@) {
  my ($cmd,$name,$aName,$aVal) = @_;
  my $hash = $defs{$name};

  if( $aName eq "Clients" ) {
    $hash->{Clients} = $aVal;
    $hash->{Clients} = $clients if( !$hash->{Clients});
  }
  elsif ($aName eq "timeout") {
    return "Usage: attr $name $aName <checkInterval>" if($aVal && $aVal !~ m/^[0-9]{1,6}(,[0-9]{1,6})*/);
  
    RemoveInternalTimer($hash, "LaCrosseGateway_OnConnectTimer");
    if($aVal) {
      LaCrosseGateway_TriggerWatchdog($hash);

      my ($timeout, $interval) = split(',', $aVal);
      $interval = $timeout if !$interval;
      InternalTimer(gettimeofday()+$interval, "LaCrosseGateway_OnConnectTimer", $hash, 0);
    }

  }
  elsif ($aName eq "disable") {
    if($aVal eq "1") {
      DevIo_CloseDev($hash);
      readingsSingleUpdate($hash, "state", "disabled", 1);
      $hash->{"RAWMSG"} = "";
      $hash->{"model"} = "";
    }
    else {
      if($hash->{READINGS}{state}{VAL} eq "disabled") {
        readingsSingleUpdate($hash, "state", "disconnected", 1);
        InternalTimer(gettimeofday()+1, "LaCrosseGateway_Connect", $hash, 0);
      }
    }
  
  }
  elsif ($aName eq "MatchList") {
    my $match_list;
    if( $cmd eq "set" ) {
      $match_list = eval $aVal;
      if( $@ ) {
        Log3 $name, 2, $name .": $aVal: ". $@;
      }
    }

    if (ref($match_list) eq 'HASH') {
      $hash->{MatchList} = $match_list;
    }
    else {
      $hash->{MatchList} = \%matchList;
      Log3 $name, 2, $name .": $aVal: not a HASH" if( $aVal );
    }
  }
  elsif ($aName eq "ownSensors" && $aVal eq "dispatch") {
    LaCrosseGateway_DeleteOwnSensorsReadings($hash);
  }
  elsif ($aName eq "kvp" && $aVal eq "dispatch") {
    LaCrosseGateway_DeleteKVPReadings($hash);
  }

  return undef;
}


#=======================================================================================
1;

=pod
=item summary    The IODevice for the LaCrosseGateway
=item summary_DE Das IODevice für das LaCrosseGateway
=begin html

<a name="LaCrosseGateway"></a>
<h3>LaCrosseGateway</h3>
<ul>
  For more information about the LaCrosseGateway see here: <a href="http://www.fhemwiki.de/wiki/LaCrosseGateway">FHEM wiki</a>
  <br><br>

  <a name="LaCrosseGateway_Define"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; LaCrosseGateway &lt;device&gt;</code> <br>
    <br>
    USB-connected devices:<br><ul>
      &lt;device&gt; specifies the serial port to communicate with the LaCrosseGateway.
      The name of the serial-device depends on your distribution, under
      linux it is something like /dev/ttyACM0 or /dev/ttyUSB0.<br><br>
    </ul>
    Network-connected devices:<br><ul>
      &lt;device&gt; specifies the network device<br>
      Normally this is the IP-address and the port in the form ip:port<br>
      Example: 192.168.1.100:81<br>
      You must define the port number on the setup page of the LaCrosseGateway and use the same number here.<br>
      The default is 81
      <br><br>
    </ul>
    <br>
  </ul>

  <a name="LaCrosseGateway_Set"></a>
  <b>Set</b>
  <ul>
    <li>raw &lt;data&gt;<br>
        send &lt;data&gt; to the LaCrosseGateway. The possible command can be found in the wiki.
    </li><br>

    <li>connect<br>
        tries to (re-)connect to the LaCrosseGateway. It does not reset the LaCrosseGateway but only try to get a connection to it.
    </li><br>

    <li>reboot<br>
    Reboots the ESP8266. Works only if we are connected (state is opened or initialized)
    </li><br>

    <li>LaCrossePairForSec &lt;sec&gt; [ignore_battery]<br>
       enable autocreate of new LaCrosse sensors for &lt;sec&gt; seconds. If ignore_battery is not given only sensors
       sending the 'new battery' flag will be created.
    </li><br>

    <li>flash<br>
      The LaCrosseGateway needs the right firmware to be able to receive and deliver the sensor data to fhem.<br>
      This provides a way to flash it directly from FHEM.
    </li><br>
    
    <li>nextionUpload<br>
      Requires LaCrosseGateway V1.24 or newer.<br>
      Sends a Nextion firmware file (.tft) to the LaCrosseGateway. The LaCrosseGateway then distributes it to a connected Nextion display.<br>
      You can define the .tft file that shall be uploaded in the tftFile attribute. If this attribute does not exists, it will try to use FHEM/firmware/nextion.tft
    </li><br>
    
  </ul>

  <a name="LaCrosseGateway_Get"></a>
  <b>Get</b>
  <ul>
  ---
  </ul>
  <br>

  <a name="LaCrosseGateway_Attr"></a>
  <b>Attributes</b>
  <ul>
    <li>Clients<br>
      The received data gets distributed to a client (e.g. LaCrosse, EMT7110, ...) that handles the data.
      This attribute tells, which are the clients, that handle the data. If you add a new module to FHEM, that shall handle
      data distributed by the LaCrosseGateway module, you must add it to the Clients attribute.
    </li><br>

    <li>MatchList<br>
      Can be set to a perl expression that returns a hash that is used as the MatchList
    </li><br>

    <li>initCommands<br>
      Space separated list of commands to send for device initialization.
    </li><br>

    <li>timeout<br>
      format: &lt;timeout&gt<br>
      Asks the LaCrosseGateway every timeout seconds if it is still alive. If there is no response it reconnects to the LaCrosseGateway.<br>
      Can be combined with the watchdog attribute. If the watchdog attribute is set, the LaCrosseGateway also will check if it gets
      a request within watchdog seconds and if not, it will reboot.
      watchdog must be longer than timeout and does only work in combination with timeout.<br>
      Both should not be too short because the LaCrosseGateway needs enough time to boot before the next check.<br>
      Good values are: timeout 60 and watchdog 300<br>
      This mode needs LaCrosseGateway V1.24 or newer.
      <br><br><u>Old version (still working):</u><br>
      format: &lt;timeout, checkInterval&gt;<br>
      Checks every 'checkInterval' seconds if the last data reception is longer than 'timeout' seconds ago.<br>
      If this is the case, a new connect will be tried.
    </li><br>

    <li>watchdog<br>
      see timeout attribute.
    </li><br>

    <li>disable<br>
      if disabled, it does not try to connect and does not dispatch data
    </li><br>

    <li>kvp<br>
      defines how the incoming KVP-data of the LaCrosseGateway is handled<br>
      dispatch: (default) dispatch it to a KVP device<br>
      readings: create readings (e.g. RSSI, ...) in this device<br>
      both: dispatch and create readings
    </li><br>

    <li>ownSensors<br>
      defines how the incoming data of the internal LaCrosseGateway sensors is handled<br>
      dispatch: (default) dispatch it to a LaCrosse device<br>
      readings: create readings (e.g. temperature, humidity, ...) in this device<br>
      both: dispatch and create readings
    </li><br>

    <li>mode<br>
      USB, WiFi or Cable<br>
      Depending on how the LaCrosseGateway is connected, it must be handled differently (init, ...)
    </li><br>
    
    <li>tftFile<br>
      defines the .tft file that shall be used by the Nextion firmware upload (set nextionUpload)
    </li><br>

  </ul>
  <br>
</ul>

=end html
=cut
