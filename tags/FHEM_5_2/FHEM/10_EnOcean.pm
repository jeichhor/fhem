##############################################
# $Id$
package main;

use strict;
use warnings;

sub EnOcean_Define($$);
sub EnOcean_Initialize($);
sub EnOcean_Parse($$);
sub EnOcean_Set($@);
sub EnOcean_MD15Cmd($$$);

my %rorgname = ("F6"=>"switch",     # RPS
                "D5"=>"contact",    # 1BS
                "A5"=>"sensor",     # 4BS
               );
my @ptm200btn = ("AI", "A0", "BI", "B0", "CI", "C0", "DI", "D0");
my %ptm200btn;

# Some Manufacturers (e.g. Jaeger Direkt) also sell EnOcean products without an
# intry in the table below. This table is only needed for A5 category devices
my %manuf = (
  "001" => "Peha",
  "002" => "Thermokon",
  "003" => "Servodan",
  "004" => "EchoFlex Solutions",
  "005" => "Omnio AG",
  "006" => "Hardmeier electronics",
  "007" => "Regulvar Inc",
  "008" => "Ad Hoc Electronics",
  "009" => "Distech Controls",
  "00A" => "Kieback + Peter",
  "00B" => "EnOcean GmbH",
  "00C" => "Probare",
  "00D" => "Eltako",
  "00E" => "Leviton",
  "00F" => "Honeywell",
  "010" => "Spartan Peripheral Devices",
  "011" => "Siemens",
  "012" => "T-Mac",
  "013" => "Reliable Controls Corporation",
  "014" => "Elsner Elektronik GmbH",
  "015" => "Diehl Controls",
  "016" => "BSC Computer",
  "017" => "S+S Regeltechnik GmbH",
  "018" => "Masco Corporation",
  "019" => "Intesis Software SL",
  "01A" => "Res.",
  "01B" => "Lutuo Technology",
  "01C" => "CAN2GO",
);

my %subTypes = (
  "A5.20.01" => "MD15",
);

sub
EnOcean_Initialize($)
{
  my ($hash) = @_;

  $hash->{Match}     = "^EnOcean:";
  $hash->{DefFn}     = "EnOcean_Define";
  $hash->{ParseFn}   = "EnOcean_Parse";
  $hash->{SetFn}     = "EnOcean_Set";
  $hash->{AttrList}  = "IODev do_not_notify:1,0 ignore:0,1 " .
                       "showtime:1,0 loglevel:0,1,2,3,4,5,6 model " .
                       "subType:switch,contact,sensor,windowHandle,SR04,MD15,".
                       "dimmer,dimmCtrl actualTemp";

  for(my $i=0; $i<@ptm200btn;$i++) {
    $ptm200btn{$ptm200btn[$i]} = "$i:30";
  }
  $ptm200btn{released} = "0:20";
  return undef;
}

#############################
sub
EnOcean_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);
  my $name = $hash->{NAME};
  return "wrong syntax: define <name> EnOcean 8-digit-hex-code"
        if(int(@a)!=3 || $a[2] !~ m/^[A-F0-9]{8}$/i);

  $modules{EnOcean}{defptr}{uc($a[2])} = $hash;
  AssignIoPort($hash);
  # Help FHEMWEB split up devices
  $attr{$name}{subType} = $1 if($name =~ m/EnO_(.*)_$a[2]/);
  return undef;
}


#############################
sub
EnOcean_Set($@)
{
  my ($hash, @a) = @_;
  return "no set value specified" if(@a < 2);

  my $name = $hash->{NAME};
  my $st = AttrVal($name, "subType", "");
  my $ll2 = GetLogLevel($name, 2);

  shift @a;
  my $tn = TimeNow();

  for(my $i = 0; $i < @a; $i++) {
    my $cmd = $a[$i];

    #####################
    # See also http://www.oscat.de/community/index.php/topic,985.30.html
    if($st eq "MD15") {
      my %sets = (
        "desired-temp"   => "\\d+(\\.\\d)?",
        "actuator"       => "\\d+",
        "unattended"     => "",
        "initialize"     => "",
      );
      my $re = $sets{$a[0]};
      return "Unknown argument $cmd, choose one of ".join(" ", sort keys %sets)
        if(!defined($re));
      return "Need a parameter" if($re && @a < 2);
      return "Argument $a[1] is incorrect (expect $re)"
        if($re && $a[1] !~ m/^$re$/);

      $hash->{CMD} = $cmd;
      $hash->{READINGS}{CMD}{TIME} = $tn;
      $hash->{READINGS}{CMD}{VAL} = $cmd;

      my $arg = "true";
      if($re) {
        $arg = $a[1];
        shift(@a);
      }

      $hash->{READINGS}{$cmd}{TIME} = $tn;
      $hash->{READINGS}{$cmd}{VAL} = $arg;

   } elsif($st eq "dimmCtrl") { # Tested for Eltako-Dimmer
     if($cmd eq "teach") {
      my $data=sprintf("A502000000%s00", $hash->{DEF});
      Log $ll2, "dimmCtrl.Teach: " . $data;
       IOWrite($hash, "000A0001", $data); # len:000a optlen:00 pakettype:1(radio)

     } elsif($cmd eq "dimm") {
       return "Usage: dimm percent [time 01-FF FF:slowest] [on/off]" if(@a<2);
       my $time=0;
       my $onoff=1;
       # for eltako relative (0-100) (but not compliant to EEP because DB0.2 is 0)
       my $dimVal=$a[1];
       shift(@a);
       if(defined($a[1])) { $time=$a[1]; shift(@a); }
       if(defined($a[1])) { $onoff=($a[1] eq "off") ? 0 : 1; shift(@a); }
       # EEP: A5/38/08 Central Command ->Typ 0x02: Dimming
       my $data=sprintf("A502%02X%02X%02X%s00", $dimVal, $time, $onoff|0x08, $hash->{DEF});
       IOWrite($hash, "000A0001", $data);
       Log $ll2, "dimmCtrl.dimm: " . $data;

     } else {
      return "Unknown argument $cmd, choose one of: teach, dimm"

     }

    ###########################
    } else {                                          # Simulate a PTM
      my ($c1,$c2) = split(",", $cmd, 2);
      return "Unknown argument $cmd, choose one of " .
                                  join(" ", sort keys %ptm200btn)
            if(!defined($ptm200btn{$c1}) || ($c2 && !defined($ptm200btn{$c2})));
      Log $ll2, "EnOcean: set $name $cmd";

      my ($db_3, $status) = split(":", $ptm200btn{$c1}, 2);
      $db_3 <<= 5;
      $db_3 |= 0x10 if($c1 ne "released"); # set the pressed flag
      if($c2) {
        my ($d2, undef) = split(":", $ptm200btn{$c2}, 2);
        $db_3 |= ($d2<<1) | 0x01;
      }
      IOWrite($hash, "",
                sprintf("6B05%02X000000%s%s", $db_3, $hash->{DEF}, $status));

    }

    select(undef, undef, undef, 0.1) if($i < int(@a)-1);
  }

  my $cmd = join(" ", @a);
  $hash->{CHANGED}[0] = $cmd;
  $hash->{STATE} = $cmd;
  $hash->{READINGS}{state}{TIME} = $tn;
  $hash->{READINGS}{state}{VAL} = $cmd;
  return undef;
}

#############################
sub
EnOcean_Parse($$)
{
  my ($iohash, $msg) = @_;
  my (undef,$rorg,$data,$id,$status,$odata) = split(":", $msg);

  my $rorgname = $rorgname{$rorg};
  if(!$rorgname) {
    Log 2, "Unknown EnOcean RORG ($rorg) received from $id";
    return "";
  }

  my $hash = $modules{EnOcean}{defptr}{$id}; 
  if(!$hash) {
    Log 3, "EnOcean Unknown device with ID $id, please define it";
    return "UNDEFINED EnO_${rorgname}_$id EnOcean $id";
  }

  my $name = $hash->{NAME};
  my $ll4 = GetLogLevel($name, 4);
  Log $ll4, "$name: ORG:$rorg DATA:$data ID:$id STATUS:$status";

  my @event;
  #push @event, "1:rp_counter:".(hex($status)&0xf);

  my $dl = length($data);
  my $db_3 = hex substr($data,0,2);
  my $db_2 = hex substr($data,2,2) if($dl > 2);
  my $db_1 = hex substr($data,4,2) if($dl > 4);
  my $db_0 = hex substr($data,6,2) if($dl > 6);
  my $st = AttrVal($name, "subType", "");

  #################################
  # RPS: PTM200 based switch/remote or a windowHandle
  if($rorg eq "F6") {
    my $nu =  ((hex($status)&0x10)>>4);

    # unused flags (AFAIK)
    #push @event, "1:T21:".((hex($status)&0x20)>>5);
    #push @event, "1:NU:$nu";

    if($nu) {

      # Theoretically there can be a released event with some of the A0,BI
      # pins set, but with the plastic cover on this wont happen.
      $msg  = $ptm200btn[($db_3&0xe0)>>5];
      $msg .= ",".$ptm200btn[($db_3&0x0e)>>1] if($db_3 & 1);
      $msg .= " released" if(!($db_3 & 0x10));

    } else {

      # Couldnt test
      if($db_3 == 112) { # KeyCard
        $msg = "keycard inserted";

      # Only the windowHandle is setting these bits when nu=0
      } elsif($db_3 & 0xC0) {
        $msg = "closed"           if($db_3 == 0xF0);
        $msg = "open"             if($db_3 == 0xE0);
        $msg = "tilted"           if($db_3 == 0xD0);
        $msg = "open from tilted" if($db_3 == 0xC0);

      } else {
        if($st eq "keycard") {
          $msg = "keycard removed";
          
        } else {
          $msg = (($db_3&0x10) ? "pressed" : "released");

        }

      }
      
    }

    # released events are disturbing when using a remote, since it overwrites
    # the "real" state immediately
    my $event = "state";
    $event = "buttons" if($msg =~ m/released$/);

    push @event, "3:$event:$msg";

  #################################
  # 1BS. Only contact is defined in the EEP2.1 for 1BS
  } elsif($rorg eq "D5") {
    push @event, "3:state:" . ($db_3&1 ? "closed" : "open");
    push @event, "3:learnBtn:on" if(!($db_3&0x8));

  #################################
  } elsif($rorg eq "A5") {

    if(($db_0 & 0x08) == 0) {
      if($db_0 & 0x80) {
        my $fn = sprintf "%02x", ($db_3>>2);
        my $tp = sprintf "%02X", ((($db_3&3) << 5) | ($db_2 >> 3));
        my $mf = sprintf "%03X", ((($db_2&7) << 8) | $db_1);
        $mf = $manuf{$mf} if($manuf{$mf});
        my $m = "teach-in:class A5.$fn.$tp (manufacturer: $mf)";
        Log 1, $m;
        push @event, "3:$m";
        my $st = "A5.$fn.$tp";
        $st = $subTypes{$st} if($subTypes{$st});
        $attr{$name}{subType} = $st;

        if("$fn.$tp" eq "20.01" && $iohash->{pair}) {      # MD15
          select(undef, undef, undef, 0.1);                # max 10 Seconds
          EnOcean_A5Cmd($hash, "800800F0", "00000000");
          select(undef, undef, undef, 0.5);
          EnOcean_MD15Cmd($hash, $name, 128); # 128 == 20 degree C
        }

      } else {
        push @event, "3:teach-in:no type/manuf. data transmitted";

      }

    } elsif($st eq "SR04") {
      my ($fspeed, $temp, $present);
      $fspeed = 3;
      $fspeed = 2      if($db_3 >= 145);
      $fspeed = 1      if($db_3 >= 165);
      $fspeed = 0      if($db_3 >= 190);
      $fspeed = "Auto" if($db_3 >= 210);
      $temp   = sprintf("%0.1f", $db_1/6.375);      # 40..0
      $present= $db_0&0x1 ? "no" : "yes";

      push @event, "3:state:temperature $temp";
      push @event, "3:set_point:$db_3";
      push @event, "3:fan:$fspeed";
      push @event, "3:present:$present" if($present eq "yes");
      push @event, "3:learnBtn:on" if(!($db_0&0x8));
      push @event, "3:T:$temp SP: $db_3 F: $fspeed P: $present";

    } elsif($st eq "MD15") {
      push @event, "3:state:$db_3 %";
      push @event, "3:currentValue:$db_3";
      push @event, "3:serviceOn:"    . (($db_2 & 0x80) ? "yes" : "no");
      push @event, "3:energyInput:"  . (($db_2 & 0x40) ? "enabled":"disabled");
      push @event, "3:energyStorage:". (($db_2 & 0x20) ? "charged":"empty");
      push @event, "3:battery:"      . (($db_2 & 0x10) ? "ok" : "empty");
      push @event, "3:cover:"        . (($db_2 & 0x08) ? "open" : "closed");
      push @event, "3:tempSensor:"   . (($db_2 & 0x04) ? "failed" : "ok");
      push @event, "3:window:"       . (($db_2 & 0x02) ? "open" : "closed");
      push @event, "3:actuatorStatus:".(($db_2 & 0x01) ? "obstructed" : "ok");
      push @event, "3:measured-temp:". sprintf "%.1f", ($db_1*40/255);
      EnOcean_MD15Cmd($hash, $name, $db_1);
      

    } elsif($st eq "dimmer") {
      # todo: create a more general solution for the central-command responses

      # response command from (Eltako-)Actor ( Central-Command:A5/38/08 )
      if($db_3 eq 0x01) { # switch
        push @event, "3:state:" . (($db_0 & 0x01) ? "on": "off");
        push @event, "3:time:" . ($db_2<<8 + $db_1);
        push @event, "3:timeType:" . (($db_0 & 0x02) ? "delay": "duration");

      } elsif($db_3 eq 0x02) { # dimm
        push @event, "3:state:" . (($db_0 & 0x01) ? "on": "off");
        push @event, "3:dimmValue:$db_2";

      } elsif($db_3 eq 0x03) { # setpoint-switch, todo
      } elsif($db_3 eq 0x04) { # basic setpoint, todo
      } elsif($db_3 eq 0x05) { # control-variable, todo
      } elsif($db_3 eq 0x06) { # fan-stage, todo
      }

    } else {
      push @event, "3:state:$db_3";
      push @event, "3:sensor1:$db_3";
      push @event, "3:sensor2:$db_2";
      push @event, "3:sensor3:$db_1";
      push @event, "3:D3:".(($db_0&0x8)?1:0);
      push @event, "3:D2:".(($db_0&0x4)?1:0);
      push @event, "3:D1:".(($db_0&0x2)?1:0);
      push @event, "3:D0:".(($db_0&0x1)?1:0);

    }

  }

  # Flag & 1: reading
  # Flag & 2: changed

  my $tn = TimeNow();
  my @changed;
  for(my $i = 0; $i < int(@event); $i++) {
    my ($flag, $vn, $vv) = split(":", $event[$i], 3);

    if($flag & 2) {
      if($vn eq "state") {
        $hash->{STATE} = $vv;
        push @changed, $vv;

      } else {
        push @changed, "$vn: $vv";

      }
    }

    if($flag & 1) {
      $hash->{READINGS}{$vn}{TIME} = TimeNow();
      $hash->{READINGS}{$vn}{VAL} = $vv;
    }
  }
  $hash->{CHANGED} = \@changed;
  
  return $name;
}

sub
EnOcean_MD15Cmd($$$)
{
  my ($hash, $name, $db_1) = @_;
  my $cmd = ReadingsVal($name, "CMD", undef);
  if($cmd) {
    my $msg;        # Unattended
    my $arg1 = ReadingsVal($name, $cmd, 0); # Command-Argument

    if($cmd eq "actuator") {
      $msg = sprintf("%02X000000", $arg1);

    } elsif($cmd eq "desired-temp") {
      $msg = sprintf("%02X%02X0400", $arg1*255/40, 
                     AttrVal($name, "actualTemp", ($db_1*40/255)) * 255/40);

    } elsif($cmd eq "initialize") {
      $msg = sprintf("00006400");

    }

    if($msg) {
      select(undef, undef, undef, 0.2);
      EnOcean_A5Cmd($hash, $msg, "00000000");
      if($cmd eq "initialize") {
        delete($defs{$name}{READINGS}{CMD});
        delete($defs{$name}{READINGS}{$cmd});
      }
    }
  }
}

sub
EnOcean_A5Cmd($$$)
{
  my ($hash, $msg, $org) = @_; 
  IOWrite($hash, "000A0701", # varLen=0A optLen=07 msgType=01=radio, 
          sprintf("A5%s%s0001%sFF00",$msg,$org,$hash->{DEF}));
          # type=A5 msg:4 senderId:4 status=00 subTelNum=01 destId:4 dBm=FF Security=00
}

1;
