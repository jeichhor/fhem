##############################################
# CUL HomeMatic handler
package main;

use strict;
use warnings;

sub CUL_HM_Define($$);
sub CUL_HM_Id($);
sub CUL_HM_Initialize($);
sub CUL_HM_Pair(@);
sub CUL_HM_Parse($$);
sub CUL_HM_PushCmdStack($$);
sub CUL_HM_SendCmd($$$$);
sub CUL_HM_Set($@);
sub CUL_HM_DumpProtocol($$@);

my %culHmDevProps=(
  "10" => { st => "switch",          cl => "receiver" }, # Parse,Set
  "20" => { st => "dimmer",          cl => "receiver" }, # Parse,Set
  "30" => { st => "blindActuator",   cl => "receiver" }, # Parse,Set
  "40" => { st => "remote",          cl => "sender" },   # Parse
  "41" => { st => "sensor",          cl => "sender" },
  "42" => { st => "swi",             cl => "sender" },
  "43" => { st => "pushButton",      cl => "sender" },
  "60" => { st => "KFM100",          cl => "sender" },   # Parse,unfinished
  "70" => { st => "THSensor",        cl => "sender" },   # Parse,unfinished
  "80" => { st => "threeStateSensor",cl => "sender" },
  "81" => { st => "motionDetector",  cl => "sender" },
  "C0" => { st => "keyMatic",        cl => "sender" },
  "C1" => { st => "winMatic",        cl => "receiver" },
  "CD" => { st => "smokeDetector",   cl => "sender" },   # Parse
);

my %culHmModel=(
  "0001" => "HM-LC-SW1-PL-OM54",
  "0002" => "HM-LC-SW1-SM",
  "0003" => "HM-LC-SW4-SM",
  "0004" => "HM-LC-SW1-FM",
  "0005" => "HM-LC-BL1-FM",
  "0006" => "HM-LC-BL1-SM",
  "0007" => "KS550",
  "0008" => "HM-RC-4",
  "0009" => "HM-LC-SW2-FM",
  "000A" => "HM-LC-SW2-SM",
  "000B" => "HM-WDC7000",
  "000D" => "ASH550",
  "000E" => "ASH550I",
  "000F" => "S550IA",
  "0011" => "HM-LC-SW1-PL",
  "0012" => "HM-LC-DIM1L-CV",
  "0013" => "HM-LC-DIM1L-PL",
  "0014" => "HM-LC-SW1-SM-ATMEGA168",
  "0015" => "HM-LC-SW4-SM-ATMEGA168",
  "0016" => "HM-LC-DIM2L-CV",
  "0018" => "CMM",
  "0019" => "HM-SEC-KEY",
  "001A" => "HM-RC-P1",
  "001B" => "HM-RC-SEC3",
  "001C" => "HM-RC-SEC3-B",
  "001D" => "HM-RC-KEY3",
  "001E" => "HM-RC-KEY3-B",
  "0022" => "WS888",
  "0026" => "HM-SEC-KEY-S",
  "0027" => "HM-SEC-KEY-O",
  "0028" => "HM-SEC-WIN",
  "0029" => "HM-RC-12",
  "002A" => "HM-RC-12-B",
  "002D" => "HM-LC-SW4-PCB",
  "002E" => "HM-LC-DIM2L-SM",
  "002F" => "HM-SEC-SC",
  "0030" => "HM-SEC-RHS",
  "0034" => "HM-PBI-4-FM",
  "0035" => "HM-PB-4-WM",
  "0036" => "HM-PB-2-WM",
  "0037" => "HM-RC-19",
  "0038" => "HM-RC-19-B",
  "0039" => "HM-CC-TC",
  "003A" => "HM-CC-VD",
  "003B" => "HM-RC-4-B",
  "003C" => "HM-WDS20-TH-O",
  "003D" => "HM-WDS10-TH-O",
  "003E" => "HM-WDS30-T-O",
  "003F" => "HM-WDS40-TH-I",
  "0040" => "HM-WDS100-C6-O",
  "0041" => "HM-WDC7000",
  "0042" => "HM-SEC-SD",
  "0043" => "HM-SEC-TIS",
  "0044" => "HM-SEN-EP",
  "0045" => "HM-SEC-WDS",
  "0046" => "HM-SWI-3-FM",
  "0047" => "KFM-Display",
  "0048" => "IS-WDS-TH-OD-S-R3",
  "0049" => "KFM-Sensor",
  "004A" => "HM-SEC-MDIR",
  "004C" => "HM-RC-12-SW",
  "004D" => "HM-RC-19-SW",
  "004E" => "HM-LC-DDC1-PCB",
  "004F" => "HM-SEN-MDIR-SM",
  "0050" => "HM-SEC-SFA-SM",
  "0051" => "HM-LC-SW1-PB-FM",
  "0052" => "HM-LC-SW2-PB-FM",
  "0053" => "HM-LC-BL1-PB-FM",
  "0056" => "HM-CC-SCD",
  "0057" => "HM-LC-DIM1T-PL",
  "0058" => "HM-LC-DIM1T-CV",
  "0059" => "HM-LC-DIM1T-FM",
  "005A" => "HM-LC-DIM2T-SM",
  "005C" => "HM-OU-CF-PL",
  "005F" => "HM-SCI-3-FM",
  "0060" => "HM-PB-4DIS-WM",
  "0061" => "HM-LC-SW4-DR",
  "0062" => "HM-LC-SW2-DR",
);


sub
CUL_HM_Initialize($)
{
  my ($hash) = @_;

  $hash->{Match}     = "^A......................";
  $hash->{DefFn}     = "CUL_HM_Define";
  $hash->{ParseFn}   = "CUL_HM_Parse";
  $hash->{SetFn}     = "CUL_HM_Set";
  $hash->{AttrList}  = "IODev do_not_notify:1,0 ignore:0,1 " .
                       "showtime:1,0 loglevel:0,1,2,3,4,5,6 model " .
                       "subType:switch,dimmer,blindActuator,remote,sensor,".
                         "swi,pushButton,threeStateSensor,motionDetector,".
                         "keyMatic,winMatic,smokeDetector " .
                       "hmClass:receiver,sender serialNr firmware";
}


#############################
sub
CUL_HM_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);

  return "wrong syntax: define <name> CUL_HM 6-digit-hex-code [Raw-Message]"
        if(!(int(@a)==3 || int(@a)==4) || $a[2] !~ m/^[A-F0-9]{6}$/i);

  $modules{CUL_HM}{defptr}{uc($a[2])} = $hash;
  $hash->{STATE} = "???";
  AssignIoPort($hash);
  if(int(@a) == 4) {
    $hash->{DEF} = $a[2];
    CUL_HM_Parse($hash, $a[3]);
  }
  return undef;
}



#############################
sub
CUL_HM_Parse($$)
{
  my ($iohash, $msg) = @_;
  my $id = CUL_HM_Id($iohash);

  # Msg format: Allnnccttssssssddddddpp...
  $msg =~ m/A(..)(..)(....)(......)(......)(.*)/;
  my @msgarr = ($1,$2,$3,$4,$5,$6,$7);
  my ($len,$msgcnt,$cmd,$src,$dst,$p) = @msgarr;
  CUL_HM_DumpProtocol("CUL_HM RCV", $iohash, @msgarr);

  my $shash = $modules{CUL_HM}{defptr}{$src};
  my $lcm = "$len$cmd";

  my $dhash = $modules{CUL_HM}{defptr}{$dst};
  my $dname = $dhash ? $dhash->{NAME} : "unknown";
  $dname = "broadcast" if($dst eq "000000");
  $dname = $iohash->{NAME} if($dst eq $id);

  if(!$shash) {
    my $sname = "CUL_HM_$src";
    if($lcm eq "1A8400") {
      my $model = substr($p, 2, 4);
      if($culHmModel{$model}) {
        $sname = $culHmModel{$model} . "_" . $src;
        $sname =~ s/-/_/g;
      }
    }
    Log 3, "CUL_HM Unknown device $sname, please define it";
    return "UNDEFINED $sname CUL_HM $src $msg";
  }

  my $name = $shash->{NAME};
  my @event;
  my $isack;
  if($shash->{ackWaiting}) {
    delete($shash->{ackWaiting});
    delete($shash->{ackCmdSent});
    RemoveInternalTimer($shash);
    $isack = 1;
  }

  my $st = AttrVal($name, "subType", "");
  my $model = AttrVal($name, "model", "");

  if($lcm eq "1A8400" || $lcm eq "1A8000") {     #### Pairing-Request
    push @event, CUL_HM_Pair($name, $shash, @msgarr);
    
  } elsif($cmd =~ m/^A0[01]{2}$/ && $dst eq $id) {#### Pairing-Request-Convers.
    CUL_HM_SendCmd($shash, $msgcnt."8002".$id.$src."00", 1, 0);  # Ack
    push @event, "";

  } elsif($cmd eq "8002") {                       # Ack

    if($shash->{cmdStack}) {                     # Send next msg from the stack
      CUL_HM_SendCmd($shash, shift @{$shash->{cmdStack}}, 1, 1);
      delete($shash->{cmdStack}) if(!@{$shash->{cmdStack}});
      $shash->{lastStackAck} = 1;

    } elsif($shash->{lastStackAck}) {            # Ack of our last stack msg
      delete($shash->{lastStackAck});

    }
    push @event, "";

  } elsif($st eq "switch" || ############################################
          $st eq "dimmer" ||
          $st eq "blindActuator") {

    if($p =~ m/^(0.0.)(..).0/) {
      my $lt = $1;
      my $val = hex($2)/2;
      $val = ($val == 100 ? "on" : ($val == 0 ? "off" : "$val %"));
      my $msg = "unknown";
      $msg = "deviceMsg" if($lt =~ m/0.01/);
      push @event, "$msg:$val";
      push @event, "state:$val" if(!$isack);
    }

  } elsif($st eq "remote") { ############################################

    if($cmd =~ m/^..4./ && $p =~ m/^(..)(..)$/) {
      my ($button, $bno) = (hex($1), hex($2));

      my $btn = int((($button&0x3f)+1)/2);
      my $state = ($button&1 ? "off" : "on") . ($button & 0x40 ? "Long" : "");
      my $add = ($dst eq $id) ? "" : " (to $dname)";

      push @event, "state:Btn$btn $state$add";
      if($id eq $dst) {
        CUL_HM_SendCmd($shash, "++8002".$id.$src."0101".    # Send Ack.
                ($state =~ m/on/?"C8":"00")."0028", 1, 0);
      }

    }

  } elsif($st eq "smokeDetector") { #####################################

    if($p eq "0106C8") {
      push @event, "state:on";
      push @event, "smoke_detect:on";

    } elsif($p =~ m/^06010000$/) {
      push @event, "state:alive";

    } elsif($p =~ m/^00(..)$/) {
      push @event, "test:$1";

    }

  } elsif($st eq "threeStateSensor") { #####################################

    push @event, "cover:closed" if($p =~ m/^0601..00$/);
    push @event, "cover:open"   if($p =~ m/^0601..0E$/);
    push @event, "state:alive"  if($p =~ m/^0601000E$/);

    if($p =~ m/^....C8/) {
      push @event, "contact:open";
      if($id eq $dst) {
        CUL_HM_SendCmd($shash, "++8002".$id.$src."0101".    # Send Ack.
                "C8"."0028", 1, 0);
      }

    } elsif($p =~ m/^....00/) {
      push @event, "contact:closed";
      if($id eq $dst) {
        CUL_HM_SendCmd($shash, "++8002".$id.$src."0101".    # Send Ack.
                "00"."0028", 1, 0);
      }

    }
    push @event, "unknownMsg:$p" if(!@event);

  } elsif($st eq "THSensor") { ##########################################

    if($p =~ m/^(....)(..)$/) {
      my ($t, $h) = ($1, $2);
      $t = hex($t)/10;
      $t -= 3276.8 if($t > 1638.4);
      $h = hex($h);
      push @event, "state:T:$t H:$h";
      push @event, "temperature:$t";
      push @event, "humidity:$h";

    } elsif($p =~ m/^(....)$/) {
      my $t = $1;
      $t = hex($t)/10;
      $t -= 3276.8 if($t > 1638.4);
      push @event, "temperature:$t";

    }


  } elsif($st eq "KFM" && $model eq "KFM-Sensor") {

    if($p =~ m/814(.)0200(..)(..)(..)/) {
      my ($k_cnt, $k_v1, $k_v2, $k_v3) = ($1,$2,$3,$4);
      my $v = 128-hex($k_v2);                  # FIXME: calibrate
      $v = 256+$v if($v < 0);

      push @event, "rawValue:$v";

    }

  }

  #push @event, "unknownMsg:$p" if(!@event);

  my $tn = TimeNow();
  for(my $i = 0; $i < int(@event); $i++) {
    next if($event[$i] eq "");

    if($shash->{lastMsg} && $shash->{lastMsg} eq $msg) {
      Log GetLogLevel($name,4), "CUL_HM $name dup mesg";
      next;
    }

    my ($vn, $vv) = split(":", $event[$i], 2);
    Log GetLogLevel($name,2), "CUL_HM $name $vn:$vv" if($vn eq "unknown");

    if($vn eq "state") {
      $shash->{STATE} = $vv;
      $shash->{CHANGED}[$i] = $vv;

    } else {
      $shash->{CHANGED}[$i] = "$vn: $vv";

    }

    $shash->{READINGS}{$vn}{TIME} = $tn;
    $shash->{READINGS}{$vn}{VAL} = $vv;
  }

  
  $shash->{lastMsg} = $msg;
  return $name;
}

my %culHmGlobalSets = (
  raw   => "data",
  reset => 0,
  pair  => 0,
  statusRequest  => 0,
);
my %culHmSubTypeSets = (
  switch        => { on => 0, off => 0, toggle => 0 },
  dimmer        => { on => 0, off => 0, toggle => 0, pct=>0 },
  blindActuator => { on => 0, off => 0, toggle => 0, pct=>0 },
  remote        => { text => "<btn> [on|off] <txt1> <txt2>" },
);

###################################
sub
CUL_HM_Set($@)
{
  my ($hash, @a) = @_;
  my $ret = "";
  my $tval;

  return "no set value specified" if(@a < 2);

  my $name = $hash->{NAME};
  my $st = AttrVal($name, "subType", "");
  my $cmd = $a[1];

  my $h = $culHmGlobalSets{$cmd};
  $h = $culHmSubTypeSets{$st}{$cmd} if(!defined($h) && $culHmSubTypeSets{$st});

  if(!defined($h) && $culHmSubTypeSets{$st}{pct} && $cmd =~ m/^\d+/) {
    $cmd = "pct";

  } elsif(!defined($h)) {
    my $usg = "Unknown argument $cmd, choose one of " .
                 join(" ",sort keys %culHmGlobalSets);
    $usg .= " ". join(" ",sort keys %{$culHmSubTypeSets{$st}})
                  if($culHmSubTypeSets{$st});
    my $pct = join(" ", (0..100));
    $usg =~ s/ pct/ $pct/;
    return $usg;

  }

#  if($h) {
#    my @l = split(" ", $h);
#    my $narg = int(@l);
#    return "Usage: set $name $cmd $h" if(@a < $narg+2);
#
#  } else {
#    return "Usage: set $name $cmd (no argument required)" if(@a > 2);
#
#  }


  my $id = CUL_HM_Id($hash->{IODev});
  my $sndcmd;

  if($cmd eq "raw") {  ##################################################
    return "Usage: set $a[0] $cmd data [data ...]" if(@a < 3);
    $sndcmd = $a[2];
    for (my $i = 3; $i < @a; $i++) {
      CUL_HM_PushCmdStack($hash, $a[$i]);
    }

  } elsif($cmd eq "reset") { ############################################
    $sndcmd = sprintf("++A011%s%s0400", $id,$hash->{DEF});

  } elsif($cmd eq "pair") { #############################################
    my $serialNr = AttrVal($name, "serialNr", undef);
    return "serialNr is not set" if(!$serialNr);
    $sndcmd = sprintf("++8401%s000000010A%s", $id, unpack("H*",$serialNr));
    $hash->{hmPairSerial} = $serialNr;

  } elsif($cmd eq "statusRequest") { ####################################
    $sndcmd = sprintf("++A001%s%s010E", $id,$hash->{DEF});

  } elsif($cmd eq "on") { ###############################################
    $sndcmd = sprintf("++A011%s%s0201C80000", $id,$hash->{DEF});
    if(@a > 2) {
      ($tval,$ret) = CUL_HM_encodeTime16($a[2]);
      $sndcmd .= $tval;
    }


  } elsif($cmd eq "off") { ##############################################
    $sndcmd = sprintf("++A011%s%s0201000000", $id,$hash->{DEF});
    # timer not supported :/

  } elsif($cmd eq "toggle") { ###########################################
    $hash->{toggleIndex} = 1 if(!$hash->{toggleIndex});
    $hash->{toggleIndex} = (($hash->{toggleIndex}+1) % 128);
    $sndcmd = sprintf("++A03E%s%s%s4001%02x", $id, $hash->{DEF},
                                      $hash->{DEF}, $hash->{toggleIndex});

  } elsif($st eq "pct") { ##############################################
    $a[1] = 100 if ($a[1] > 100);
    $sndcmd = sprintf("++A011%s%s0201%02X0000", $id, $hash->{DEF}, $a[1]*2);
    if(@a > 2) {
      ($tval,$ret) = CUL_HM_encodeTime16($a[2]);
      $sndcmd .= $tval;
    }


  } elsif($st eq "text") { #############################################
    return "$a[2] is not a button number" if($a[2] !~ m/^\d$/);
    return "$a[3] is not on or off" if($a[3] !~ m/^(on|off)$/);
    my $bn = $a[2]*2-($a[3] eq "on" ? 0 : 1);

    CUL_HM_PushCmdStack($hash,
      sprintf("++A001%s%s%02d050000000001", $id, $hash->{DEF}, $bn));

    my ($l1, $l2, $s, $tl);     # Create CONFIG_WRITE_INDEX string
    $l1 = $a[4] . "\x00";
    $l1 = substr($l1, 0, 13);
    $s = 54;
    $l1 =~ s/(.)/sprintf("%02X%02X",$s++,ord($1))/ge;

    $l2 = $a[5] . "\x00";
    $l2 = substr($l2, 0, 13);
    $s = 70;
    $l2 =~ s/(.)/sprintf("%02X%02X",$s++,ord($1))/ge;
    $l1 .= $l2;

    $tl = length($l1);
    for(my $l = 0; $l < $tl; $l+=28) {
      my $ml = $tl-$l < 28 ? $tl-$l : 28;
      CUL_HM_PushCmdStack($hash, sprintf("++A001%s%s%02d08%s",
              $id, $hash->{DEF}, $bn, substr($l1,$l,$ml)));
    }

    CUL_HM_PushCmdStack($hash,
      sprintf("++A001%s%s%02d06", $id, $hash->{DEF}, $bn));
    return "Set your remote in learning mode to transmit the data";

  }

  CUL_HM_SendCmd($hash, $sndcmd, 0, 1);
  return $ret;
}


###################################
# A pairing between rrrrrr (remote) and ssssss (switch) looks like the
# following (nn and ff is the index of the on and off button):
# 1A CF 84 00 rrrrrr 000000 10 0060 serialnumberxxxxxxxx 40 04 nnff
# 1A 66 A0 00 ssssss rrrrrr 19 0011 serialnumberxxxxxxxx 10 01 0100
# 0A D0 80 02 rrrrrr ssssss 00
# 10 D0 A0 01 ssssss rrrrrr nn05 ssssss 0104
# 0A D0 80 02 rrrrrr ssssss 00
# 0E D0 A0 01 ssssss rrrrrr nn07 020201
# 0A D0 80 02 rrrrrr ssssss 00
# 0B D0 A0 01 ssssss rrrrrr nn06
# 0A D0 80 02 rrrrrr ssssss 00
# 10 D0 A0 01 ssssss rrrrrr ff05 ssssss 0104
# 0A D0 80 02 rrrrrr ssssss 00
# 0E D0 A0 01 ssssss rrrrrr ff07 020201
# 0A D0 80 02 rrrrrr ssssss 02
# 0B D0 A0 01 ssssss rrrrrr ff06
# 0A D0 80 02 rrrrrr ssssss 00
sub
CUL_HM_Pair(@)
{
  my ($name, $hash, $len,$msgcnt,$cmd,$src,$dst,$p) = @_;
  my $iohash = $hash->{IODev};
  my $id = CUL_HM_Id($iohash);
  my $l4 = GetLogLevel($name,4);
  my $isPairWithSerial;
  my ($idstr, $s) = ($id, 0xA);
  $idstr =~ s/(..)/sprintf("%02X%s",$s++,$1)/ge;

  my $stc = substr($p, 26, 2);        # subTypeCode
  my $model = substr($p, 2, 4);
  my $dp = $culHmDevProps{$stc};

  $attr{$name}{model}   = $culHmModel{$model}? $culHmModel{$model} :"unknown";
  $attr{$name}{subType} = $dp ? $dp->{st} : "unknown";
  $attr{$name}{hmClass} = $dp ? $dp->{cl} : "unknown";
  $attr{$name}{serialNr} = pack('H*', substr($p, 6, 20));
  $attr{$name}{firmware} = sprintf("%0.1f", substr($p, 0, 2)/10);
  my $isSender  = (AttrVal($name,"hmClass","") eq "sender");

  my $stn = $attr{$name}{subType};    # subTypeName
  my $stt = $stn eq "unknown" ? "subType unknown" : "is a $stn";

  Log GetLogLevel($name,2),
        "CUL_HM pair: $name $stt, model $attr{$name}{model} ".
        "serialNr $attr{$name}{serialNr}";

  # Abort if we are not authorized
  if($dst eq "000000") {
    if(!$iohash->{hmPair}) {
      Log 4, $iohash->{NAME}. " pairing (hmPairForSec) not enabled";
      return "";
    }

  } elsif($dst ne $id) {
    return "" ;

  } elsif($iohash->{hmPairSerial}) {
    delete($iohash->{hmPairSerial});
    $isPairWithSerial = 1;

  }
      

  if($stn eq "unknown") {
    Log GetLogLevel($name,1), "CUL_HM unknown subType $stc, cannot pair";
    return "";
  }

  my $pairButtons = substr($p, 30, 4);
  if($pairButtons eq "0000") { # Sender pair mode, before btn is pressed
    if($hash->{cmdStack}) {
      CUL_HM_SendCmd($hash, shift @{$hash->{cmdStack}}, 1, 1);
      delete($hash->{cmdStack}) if(!@{$hash->{cmdStack}});
    }
    return "";
  }

  delete($hash->{cmdStack});

  #if($isSender) {        # emulate a switch for a remote/etc
  if($stn eq "remote") {

    my ($mystc, $mymodel, $mybtn, $myserNr);
    $mymodel   = "0011";  # Emulate a HM-LC-SW1-PL
    $mystc     = "10";    # switch
    $mybtn     = "010100";# channel 1/1
    $myserNr   = unpack('H*', "FHEM$id");
    $pairButtons =~ m/(..)(..)/;
    my ($b1, $b2) = ($1, $2);

    CUL_HM_SendCmd($hash,
        $msgcnt."A000".$id.$src."19".$mymodel.$myserNr.$mystc.$mybtn, 1, 1);
    CUL_HM_SendCmd($hash,      "++A001$id$src${b1}05$src${b1}04", 1, 1);
    CUL_HM_PushCmdStack($hash, "++A001$id$src${b1}07020201");
    CUL_HM_PushCmdStack($hash, "++A001$id$src${b1}06");
    CUL_HM_PushCmdStack($hash, "++A001$id$src${b2}05$src${b2}04");
    CUL_HM_PushCmdStack($hash, "++A001$id$src${b2}07020201");
    CUL_HM_PushCmdStack($hash, "++A001$id$src${b2}06");

  } else {
    CUL_HM_SendCmd     ($hash, "++A001$id${src}00050000000000", 1, 1);
    CUL_HM_PushCmdStack($hash, "++A001$id${src}00080201$idstr");
    CUL_HM_PushCmdStack($hash, "++A001$id${src}0006");
  }

  return "";

}
    
###################################
sub
CUL_HM_SendCmd($$$$)
{
  my ($hash, $cmd, $sleep, $waitforack) = @_;
  my $io = $hash->{IODev};

  select(undef, undef, undef, 0.1*$sleep) if($sleep);

  $cmd =~ m/^(..)(.*)$/;
  my ($mn, $cmd2) = ($1, $2);

  if($mn eq "++") {
    $mn = $io->{HM_CMDNR} ? ($io->{HM_CMDNR} +1) : 1;
    $mn = 0 if($mn > 255);

  } else {
    $mn = hex($mn);

  }

  $io->{HM_CMDNR} = $mn;
  $cmd = sprintf("As%02X%02x%s", length($cmd2)/2+1, $mn, $cmd2);
  IOWrite($hash, "", $cmd);
  if($waitforack) {
    $hash->{ackWaiting} = $cmd;
    $hash->{ackCmdSent} = 1;
    InternalTimer(gettimeofday()+0.4, "CUL_HM_Resend", $hash, 0);
  }
  $cmd =~ m/As(..)(..)(....)(......)(......)(.*)/;
  CUL_HM_DumpProtocol("CUL_HM SND", $io, ($1,$2,$3,$4,$5,$6));
}

###################################
sub
CUL_HM_PushCmdStack($$)
{
  my ($hash, $cmd) = @_;
  my @arr = ();
  $hash->{cmdStack} = \@arr if(!$hash->{cmdStack});
  push(@{$hash->{cmdStack}}, $cmd);
}

###################################
sub
CUL_HM_Resend($)
{
  my $hash = shift;
  my $name = $hash->{NAME};
  if($hash->{ackCmdSent} == 3) {
    delete($hash->{ackCmdSent});
    delete($hash->{ackWaiting});
    delete($hash->{cmdStack});
    $hash->{STATE} = "MISSING ACK";
    DoTrigger($name, "MISSING ACK");
    return;
  }
  IOWrite($hash, "", $hash->{ackWaiting});
  $hash->{ackCmdSent}++;
  DoTrigger($name, "resend nr ".$hash->{ackCmdSent});
  InternalTimer(gettimeofday()+0.4, "CUL_HM_Resend", $hash, 0);
}

###################################
sub
CUL_HM_Id($)
{
  my ($io) = @_;
  return "123456" if(!$io || !defined($io->{FHTID}));
  return AttrVal($io->{NAME}, "hmId", "F1".$io->{FHTID});
}

my %culHmBits = (
  "8000"          => { txt => "DEVICE_INFO",  params => {
                       FIRMWARE       => '00,2,$val/=10',
                       TYPE           => "02,4",
                       SERIALNO       => '06,20,$val=pack("H*",$val)',
                       CLASS          => "26,2",
                       PEER_CHANNEL_A => "28,2",
                       PEER_CHANNEL_B => "30,2",
                       UNKNOWN        => "32,2", } },
  "8002;p01=01"   => { txt => "ACK_STATUS",  params => {
                       CHANNEL        => "02,2",
                       STATUS         => "04,2",
                       RSSI           => "08,2", } },
  "8002"          => { txt => "ACK" },
  "8401;p02=010A" => { txt => "PAIR_SERIAL", params => {
                       SERIALNO       => '04,,$val=pack("H*",$val)', } },
  "A001;p11=01"   => { txt => "CONFIG_PEER_ADD", params => {
                       CHANNEL        => "00,2",
                       PEER_ADDRESS   => "04,6",
                       PEER_CHANNEL_A => "10,2",
                       PEER_CHANNEL_B => "12,2", } },
  "A001;p11=03"   => { txt => "CONFIG_PEER_LIST_REQ", params => {
                       CHANNEL => "0,2", } },
  "A001;p11=04"   => { txt => "CONFIG_PARAM_REQ", params => {
                       CHANNEL        => "00,2",
                       PEER_ADDRESS   => "04,6",
                       PEER_CHANNEL   => "10,2",
                       PARAM_LIST     => "12,2", } },
  "A001;p11=05"   => { txt => "CONFIG_START", params => {
                       CHANNEL        => "00,2",
                       PEER_ADDRESS   => "04,6",
                       PEER_CHANNEL   => "10,2",
                       PARAM_LIST     => "12,2", } },
  "A001;p11=06"   => { txt => "CONFIG_END", params => {
                       CHANNEL => "0,2", } },
  "A001;p11=08"   => { txt => "CONFIG_WRITE_INDEX", params => {
                       CHANNEL => "0,2",
                       DATA => '4,,$val =~ s/(..)(..)/ $1:$2/g', } },
  "A001;p11=0E"   => { txt => "CONFIG_STATUS_REQUEST", params => {
                       CHANNEL => "0,2", } },
  "A002"          => { txt => "Request AES", params => { 
                       DATA =>  "0," } },
  "A003"          => { txt => "AES reply",   params => {
                       DATA =>  "0," } },
  "A010;p01=01"   => { txt => "INFO_PEER_LIST", params => {
                       PEER_ADDR1 => "02,6", PEER_CH1 => "08,2",
                       PEER_ADDR2 => "10,6", PEER_CH2 => "16,2",
                       PEER_ADDR3 => "18,6", PEER_CH3 => "24,2",
                       PEER_ADDR4 => "26,6", PEER_CH4 => "32,2", } },
  "A010;p01=02"   => { txt => "INFO_PARAM_RESPONSE_PAIRS", params => {
                       DATA => "2,", } },
  "A010;p01=03"   => { txt => "INFO_PARAM_RESPONSE_SEQ", params => {
                       OFFSET => "2,2", 
                       DATA => "4,", } },
  "A011;p02=0400" => { txt => "RESET" },
  "A011;p01=02"   => { txt => "SET" , params => {
                       CHANNEL  => "02,2", 
                       VALUE    => "04,2", 
                       RAMPTIME => "06,2", 
                       ONTIME   => "08,2",
                       DURATION => '10,4,$val=CUL_HM_decodeTime16($val)', } }, 
  "A03E"          => { txt => "SWITCH", params => {
                       DST      => "00,6", 
                       UNKNOWN  => "06,2", 
                       CHANNEL  => "08,2", 
                       COUNTER  => "10,2", } },
  "A410;p01=06"   => { txt => "INFO_ACTUATOR_STATUS", params => {
                       CHANNEL => "2,2", 
                       STATUS  => '4,2', 
                       UNKNOWN => "6,2",
                       RSSI    => "8,2" } },
  "A440"          => { txt => "REMOTE", params => {
                       BUTTON        => '00,02,$val=(hex($val)&0x3F)',
                       LONG          => '00,02,$val=(hex($val)&0x40)?1:0',
                       LOWBAT        => '00,02,$val=(hex($val)&0x80)?1:0',
                       COUNTER       => "02,02", } },
);

sub
CUL_HM_DumpProtocol($$@)
{
  my ($prefix, $iohash, $len,$cnt,$cmd,$src,$dst,$p) = @_;
  my $iname = $iohash->{NAME};
  my $ev = AttrVal($iname, "hmProtocolEvents", 0);
  my $l4 = GetLogLevel($iname, 4);
  return if(!$ev && $attr{global}{verbose} < $l4);

  my $p01 = substr($p,0,2);
  my $p02 = substr($p,0,4);
  my $p11 = substr($p,2,2);

  $cmd = "0A$1" if($cmd =~ m/0B(..)/);
  $cmd = "A4$1" if($cmd =~ m/84(..)/);

  my $ps;
  $ps = $culHmBits{"$cmd;p11=$p11"} if(!$ps);
  $ps = $culHmBits{"$cmd;p01=$p01"} if(!$ps);
  $ps = $culHmBits{"$cmd;p02=$p02"} if(!$ps);
  $ps = $culHmBits{"$cmd"}         if(!$ps);
  my $txt = "";
  if($ps) {
    $txt = $ps->{txt};
    if($ps->{params}) {
      $ps = $ps->{params};
      foreach my $k (sort {$ps->{$a} cmp $ps->{$b} } keys %{$ps}) {
        my ($o,$l,$expr) = split(",", $ps->{$k}, 3);
        last if(length($p) <= $o);
        my $val = $l ? substr($p,$o,$l) : substr($p,$o);
        eval $expr if($expr);
        $txt .= " $k:$val";
      }
    }
    $txt = " ($txt)" if($txt);
  }
  my $msg  = "$prefix L:$len N:$cnt CMD:$cmd SRC:$src DST:$dst $p$txt";
  Log $l4, $msg;
  DoTrigger($iname, $msg) if($ev);
}

my @culHmTimes8 = ( 0.1, 1, 5, 10, 60, 300, 600, 3600 );
sub
CUL_HM_encodeTime8($)
{
  my $v = shift;
  return "00" if($v < 0.1);
  for(my $i = 0; $i < @culHmTimes8; $i++) {
    if($culHmTimes8[$i] * 32 > $v) {
      for(my $j = 0; $j < 32; $j++) {
        if($j*$culHmTimes8[$i] >= $v) {
          return sprintf("%X", $i*32+$j);
        }
      }
    }
  }
  return "FF";
}

sub
CUL_HM_decodeTime8($)
{
  my $v = hex(shift);
  return "undef" if($v > 255);
  my $v1 = int($v/32);
  my $v2 = $v%32;
  return $v2 * $culHmTimes8[$v1];
}

sub
CUL_HM_encodeTime16($)
{
  my $v = shift;
  my $ret = "FFFF";
  my $mul = 20;

  return "0000" if($v < 0.05);
  for(my $i = 0; $i < 16; $i++) {
    if($v*$mul < 0xfff) {
     $ret=sprintf("%03X%X", $v*$mul, $i);
     last;
    }
    $mul /= 2;
  }
  my $v2 = CUL_HM_decodeTime16($ret);
  return ($ret, "Timeout $v rounded to $v2") if($v != $v2);
  return ($ret, "");
}

sub
CUL_HM_decodeTime16($)
{
  my $v = hex(shift);
  my $m = int($v/16);
  my $e = $v % 16;
  my $mul = 0.05;
  while($e--) {
    $mul *= 2;
  }
  return $mul*$m;
}

1;
