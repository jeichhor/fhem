##############################################
# See ZWDongle.pm for inspiration
# TODO
# - versioned commands
# - use central readings functions
# - Generate MISSING ACK
# - implement (global?) on-for-timer
# - better autocreate integration
# - get support in FHEMWEB
# - class meter: get 
# - class SWITCH_ALL
package main;

use strict;
use warnings;

sub ZWave_Parse($$@);
sub ZWave_Set($@);
sub ZWave_Get($@);
sub ZWave_Cmd($$@);
sub ZWave_ParseMeter($);
sub ZWave_SetClasses($$$$);

use vars qw(%zw_func_id);

my @zwave_models = qw(
  Everspring_AN1582 Everspring_AN1583
);

my %zwave_id2class;
my %zwave_class = (
  NO_OPERATION             => { id => '00', },
  BASIC                    => { id => '20',
    set   => { basicValue  => "01%02x", },
    get   => { basicStatus => "02",     }, 
    parse => { "..200.(.*)"  => '"basicReport:$1"',}, },
  CONTROLLER_REPLICATION   => { id => '21', },
  APPLICATION_STATUS       => { id => '22', },
  ZIP_SERVICES             => { id => '23', },
  ZIP_SERVER               => { id => '24', },
  SWITCH_BINARY            => { id => '25',
    set   => { off         => "0100",
               on          => "01FF",
               reportOn    => "03FF",
               reportOff   => "0300",     },
    get   => { swbStatus   => "02",       },
    parse => { "03250300"  => "state:off",
               "032503ff"  => "state:on",  }, } ,
  SWITCH_MULTILEVEL        => { id => '26', },
  SWITCH_ALL               => { id => '27', },
  SWITCH_TOGGLE_BINARY     => { id => '28', },
  SWITCH_TOGGLE_MULTILEVEL => { id => '29', },
  CHIMNEY_FAN              => { id => '2A', },
  SCENE_ACTUATOR_CONF      => { id => '2C', },
  SCENE_CONTROLLER_CONF    => { id => '2D', },
  ZIP_ADV_SERVICES         => { id => '2F', },
  SCENE_ACTIVATION         => { id => '2b', },
  ZIP_CLIENT               => { id => '2e', },
  SENSOR_BINARY            => { id => '30', 
    get   => { sbStatus    => "02",       },
    parse => { "03300300"  => "state:closed",
               "033003ff"  => "state:open",  },},
  SENSOR_MULTILEVEL        => { id => '31', },
  METER                    => { id => '32',
    parse => { "..3202(.*)"=> 'ZWave_ParseMeter($1)' }, },
  ZIP_ADV_SERVER           => { id => '33', },
  ZIP_ADV_CLIENT           => { id => '34', },
  METER_PULSE              => { id => '35', },
  THERMOSTAT_HEATING       => { id => '38', },
  THERMOSTAT_MODE          => { id => '40', },
  THERMOSTAT_OPERATING_STATE => { id => '42', },
  THERMOSTAT_SETPOINT      => { id => '43', },
  THERMOSTAT_FAN_MODE      => { id => '44', },
  THERMOSTAT_FAN_STATE     => { id => '45', },
  CLIMATE_CONTROL_SCHEDULE => { id => '46', },
  THERMOSTAT_SETBACK       => { id => '47', },
  BASIC_WINDOW_COVERING    => { id => '50', },
  MTP_WINDOW_COVERING      => { id => '51', },
  MULTI_INSTANCE           => { id => '60', },
  DOOR_LOCK                => { id => '62', },
  USER_CODE                => { id => '63', },
  CONFIGURATION            => { id => '70', 
    set   => { configDefault=>"04%02x80",
               configByte  => "04%02x01%02x",
               configWord  => "04%02x02%04x",
               configLong  => "04%02x04%08x", },
    get   => { config      => "05%02x", },
    parse => { "..7006(..)..(.*)" => '"config_$1:".hex($2)',}, },
  ALARM                    => { id => '71', 
    get   => { alarm       => "04%02x", },
    parse => { "..7105(..)(..)" => '"alarm_type_$1:level $2"',}, },
  MANUFACTURER_SPECIFIC    => { id => '72', },
  POWERLEVEL               => { id => '73', },
  PROTECTION               => { id => '75', },
  LOCK                     => { id => '76', },
  NODE_NAMING              => { id => '77', },
  GROUPING_NAME            => { id => '7B', },
  FIRMWARE_UPDATE_MD       => { id => '7a', },
  REMOTE_ASSOCIATION_ACTIVATE => { id => '7c', },
  REMOTE_ASSOCIATION       => { id => '7d', },
  BATTERY                  => { id => '80',
    get   => { battery     => "02" },
    parse => { "038003(..)"=> '"battery:".hex($1)." %"' }, },
  CLOCK                    => { id => '81', },
  HAIL                     => { id => '82', },
  WAKE_UP                  => { id => '84', 
    set   => { wakeupInterval => "04%06x%02x" },
    get   => { wakeupInterval => "05" },
    parse => { "028407"    => 'wakeup:notification',
               "..8406(......)(..)" =>
                '"wakeupReport:interval:".hex($1)." target:".hex($2)',}, },
  ASSOCIATION              => { id => '85', 
    set   => { associationAdd => "01%02x%02x*",
               associationDel => "04%02x%02x*", },
    get   => { association => "02%02x",      },
    parse => { "..8503(..)(..)..(.*)" => '"assocGroup_$1:Max:$2 Nodes:$3"',}, },
  VERSION                  => { id => '86',
    get   => { version     => "11",       },
    parse => { "078612(..)(..)(..)(..)(..)" =>
    'sprintf("Lib:%d Prot:%d.%d App:%d.%d",hex($1),hex($2),hex($3),hex($4),hex($5))', } },
  INDICATOR                => { id => '87', },
  PROPRIETARY              => { id => '88', },
  LANGUAGE                 => { id => '89', },
  TIME_PARAMETERS          => { id => '8B', },
  GEOGRAPHIC_LOCATION      => { id => '8C', },
  COMPOSITE                => { id => '8D', },
  MULTI_CMD                => { id => '8F', },
  TIME                     => { id => '8a', },
  MULTI_INSTANCE_ASSOCIATION => { id => '8E', },
  ENERGY_PRODUCTION        => { id => '90', },
  MANUFACTURER_PROPRIETARY => { id => '91', },
  SCREEN_MD                => { id => '92', },
  SCREEN_ATTRIBUTES        => { id => '93', },
  SIMPLE_AV_CONTROL        => { id => '94', },
  AV_CONTENT_DIRECTORY_MD  => { id => '95', },
  AV_RENDERER_STATUS       => { id => '96', },
  AV_CONTENT_SEARCH_MD     => { id => '97', },
  SECURITY                 => { id => '98', },
  AV_TAGGING_MD            => { id => '99', },
  IP_CONFIGURATION         => { id => '9A', },
  ASSOCIATION_COMMAND_CONFIGURATION => { id => '9B', },
  SENSOR_ALARM             => { id => '9C', },
  SENSOR_CONFIGURATION     => { id => '9E', },
  SILENCE_ALARM            => { id => '9d', },
  MARK                     => { id => 'ef', },
  NON_INTEROPERABLE        => { id => 'f0', },
  );


  sub
ZWave_Initialize($)
{
  my ($hash) = @_;
  $hash->{Match}     = ".*";
  $hash->{SetFn}     = "ZWave_Set";
  $hash->{GetFn}     = "ZWave_Get";
  $hash->{DefFn}     = "ZWave_Define";
  $hash->{UndefFn}   = "ZWave_Undef";
  $hash->{ParseFn}   = "ZWave_Parse";
  $hash->{AttrList}  = "IODev do_not_notify:1,0 ".
    "ignore:1,0 dummy:1,0 showtime:1,0 classes ".
    "loglevel:0,1,2,3,4,5,6 " .
    "model:".join(",", sort @zwave_models);
  map { $zwave_id2class{$zwave_class{$_}{id}} = $_ } keys %zwave_class;
}


#############################
  sub
ZWave_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);
  my $name   = shift @a;
  my $type = shift(@a); # always ZWave

  my $u = "wrong syntax for $name: define <name> ZWave homeId id [classes]";
  return $u if(int(@a) < 2 || int(@a) > 3);

  my $homeId = lc(shift @a);
  my $id     = shift @a;

  return "define $name: wrong homeId ($homeId): need an 8 digit hex value"
                   if( ($homeId !~ m/^[a-f0-9]{8}$/i) );
  return "define $name: wrong id ($id): need a number"
                   if( ($id !~ m/^\d+$/i) );

  $id = sprintf("%02x", $id);
  $hash->{homeId} = $homeId;
  $hash->{id}     = $id;

  $modules{ZWave}{defptr}{"$homeId $id"} = $hash;
  AssignIoPort($hash);  # FIXME: should take homeId into account

  if(@a) {
    ZWave_SetClasses($homeId, $id, undef, $a[0]);

    if($attr{$name}{classes} =~ m/ASSOCIATION/) {
      my $iodev = $hash->{IODev};
      my $homeReading = ReadingsVal($iodev->{NAME}, "homeId", "") if($iodev);
      my $ctrlId = $1 if($homeReading && $homeReading =~ m/CtrlNodeId:(..)/);

      if($ctrlId) {
        Log 1, "Adding the controller $ctrlId to association group 1";
        IOWrite($hash, "00", "130a04850101${ctrlId}05");

      } else {
        Log 1, "Cannot associate $name, missing controller id";
      }
    }
  }
  return undef;
}

###################################
sub
ZWave_Cmd($$@)
{
  my ($type, $hash, @a) = @_;
  my $ret = undef;
  return "no $type argument specified" if(int(@a) < 2);
  my $name = shift(@a);
  my $cmd  = shift(@a);

  # Collect the commands from the distinct classes
  my %cmdList;
  my $classes = AttrVal($name, "classes", "");
  foreach my $cl (split(" ", $classes)) {
    my $ptr = $zwave_class{$cl}{$type} if($zwave_class{$cl}{$type});
    next if(!$ptr);
    foreach my $k (keys %{$ptr}) {
      if(!$cmdList{$k}) {
        $cmdList{$k}{fmt} = $ptr->{$k};
        $cmdList{$k}{id}  = $zwave_class{$cl}{id};
      }
    }
  }
  return ("Unknown $type argument $cmd, choose one of "
                        . join(" ",sort keys %cmdList))
    if(!$cmdList{$cmd});


  ################################
  # ZW_SEND_DATA,nodeId,CMD,ACK|AUTO_ROUTE
  my $id = $hash->{id};
  my $cmdFmt = $cmdList{$cmd}{fmt};
  my $cmdId  = $cmdList{$cmd}{id};

  my $nArg = 0;
  $nArg = int(split("%", $cmdFmt))-1 if($cmdFmt =~ m/%/);
  my $parTxt = ($nArg == 0 ? "no parameter" : 
               ($nArg == 1 ? "one parameter" : 
                             "$nArg parameters"));
  if($cmdFmt =~ m/^(.*)\*$/) {
    $cmdFmt = $1;
    return "$type $cmd needs at least $parTxt" if($nArg > int(@a));
    $cmdFmt .= ("%02x" x (int(@a)-$nArg));

  } else {
    return "$type $cmd needs $parTxt" if($nArg != int(@a));
  }
  $cmdFmt = sprintf($cmdFmt, @a) if($nArg);
  my $len = sprintf("%02x", length($cmdFmt)/2+1);

  my $data = "13$id$len$cmdId${cmdFmt}05";
  if($classes =~ m/WAKE_UP/) {
    if(!$hash->{WakeUp}) {
      my @arr = ();
      $hash->{WakeUp} = \@arr;
    }
    push @{$hash->{WakeUp}}, $data;
    return ($type eq "get" ? "Scheduled for sending after WAKEUP" : undef);
  }
  IOWrite($hash, "00", $data);

  my $val;
  if($type eq "get") {
    no strict "refs";
    my $iohash = $hash->{IODev};
    my $fn = $modules{$iohash->{TYPE}}{ReadAnswerFn};
    my ($err, $data) = &{$fn}($iohash, $cmd, "^000400$id");
    use strict "refs";

    return $err if($err);
    $val =  ZWave_Parse($iohash, $data, 1);

  } else {
    $cmd .= " ".join(" ", @a) if(@a);

  }

  my $tn = TimeNow();
  if($type eq "set") {
    $hash->{CHANGED}[0] = $cmd;
    $hash->{STATE} = $cmd;
    $hash->{READINGS}{state}{TIME} = $tn;
    $hash->{READINGS}{state}{VAL} = $cmd;

  } else {
    my $mval = $val;
    ($cmd, $mval) = split(":", $val) if($val);
    $hash->{READINGS}{$cmd}{TIME} = $tn;
    $hash->{READINGS}{$cmd}{VAL} = $mval;

  }
  return $val;
}

sub ZWave_Set($@) { return ZWave_Cmd("set", shift, @_); }
sub ZWave_Get($@) { return ZWave_Cmd("get", shift, @_); }


sub
ZWave_ParseMeter($)
{
  my ($val) = @_;
  return if($val !~ m/^(..)(..)(.*)$/);
  my ($v1, $v2, $v3) = (hex($1) & 0x1f, hex($2), $3);
  my @prectab = (1,10,100,1000,10000,100000,1000000, 10000000);
  my $prec  = $prectab[($v2 >> 5) & 0x7];
  my $scale = ($v2 >> 3) & 0x3;
  my $size  = ($v2 >> 0) & 0x7;
  my @txt = ("undef", "power", "gas", "water");
  my $txt = ($v1 > $#txt ? "undef" : $txt[$v1]);
  my %unit = (power => ["kWh", "kVAh", "W", "pulseCount"],
              gas   => ["m3",  "feet3", "undef", "pulseCount"],
              water => ["m3",  "feet3", "USgallons", "pulseCount"]);
  my $unit = $txt eq "undef" ? "undef" : $unit{$txt}[$scale];
  $v3 = hex(substr($v3, 0, 2*$size))/$prec;
  return "$txt:$v3 $unit";
}

sub
ZWave_SetClasses($$$$)
{
  my ($homeId, $id, $type6, $classes) = @_;

  my $def = $modules{ZWave}{defptr}{"$homeId $id"};
  if(!$def) {
    $type6 = $zw_type6{$type6} if($type6 && $zw_type6{$type6});
    $id = hex($id);
    return "UNDEFINED ZWave_${type6}_$id ZWave $homeId $id $classes"
  }

  my @classes;
  for my $classId (grep /../, split(/(..)/, lc($classes))) {
    push @classes, $zwave_id2class{$classId} if($zwave_id2class{$classId});
  }
  my $name = $def->{NAME};
  $attr{$name}{classes} = join(" ", @classes) if(@classes);
  $def->{DEF} = "$homeId ".hex($id);
  return "";
}

sub
ZWave_Parse($$@)
{
  my ($iodev, $msg, $local) = @_;
  my $homeId = $iodev->{homeId};
  my $ioName = $iodev->{NAME};
  if(!$homeId) {
    Log 1, "ERROR: $ioName homeId is not set!" if(!$iodev->{errReported});
    $iodev->{errReported} = 1;
    return;
  }
  my $ll4 = AttrVal($ioName, "loglevel", 4);

  return "" if($msg !~ m/00(..)(..)(..)(..*)/); # Ignore unknown commands 
  my ($cmd, $callbackid, $id, $arg) = ($1, $2, $3, $4);
  $cmd = $zw_func_id{$cmd} if($zw_func_id{$cmd});

  #####################################
  # Controller commands
  my $evt;

  if($cmd eq 'ZW_ADD_NODE_TO_NETWORK' ||
     $cmd eq 'ZW_REMOVE_NODE_FROM_NETWORK') {
    my @vals = ("learnReady", "nodeFound", "slave",
                "controller", "", "done", "failed");
    $evt = ($id eq "00" || hex($id)>@vals+1) ? "unknownArg" : $vals[hex($id)-1];
    if($evt eq "slave" &&
       $arg =~ m/(..)....(..)..(.*)$/) {
      my ($id,$type6,$classes) = ($1, $2, $3);
      return ZWave_SetClasses($homeId, $id, $type6, $classes)
        if($cmd eq 'ZW_ADD_NODE_TO_NETWORK');
    }

  } elsif($cmd eq "ZW_APPLICATION_UPDATE" && $arg =~ m/....(..)..(.*)$/) {
      my ($type6,$classes) = ($1, $2, $3);
      return ZWave_SetClasses($homeId, $id, $type6, $classes);

  }

  if($evt) {
    return "$cmd $evt" if($local);
    DoTrigger($ioName, "$cmd $evt");
    Log $ll4, "$ioName $cmd $evt";
    return "";

  } else {
    Log $ll4, "$ioName $cmd $id ($arg)";

  }


  ######################################
  # device messages
  return "" if($cmd ne "APPLICATION_COMMAND_HANDLER" || $arg !~ m/^..(..)/);
  my $class = $1;
  my $hash = $modules{ZWave}{defptr}{"$homeId $id"};
  if(!$hash) {
    $id = hex($id);
    Log 3, "Unknown ZWave device $homeId $id, please define it";
    return "";
  }


  my $className = $zwave_id2class{$class} ? $zwave_id2class{$class} : "UNKNOWN";
  my $ptr = $zwave_class{$className}{parse} if($zwave_class{$className}{parse});
  if(!$ptr) {
    Log $ll4, "$hash->{NAME}: Unknown message ($className $arg)";
    return "";
  }

  my @event;
  foreach my $k (keys %{$ptr}) {
    if($arg =~ m/$k/) {
      my $val = $ptr->{$k};
      $val = eval $val if(index($val, '$') >= 0);
      push @event, $val;
    }
  }

  return "" if(!@event);
  return join(" ", @event) if($local);

  if($hash->{WakeUp} && @{$hash->{WakeUp}}) {
    IOWrite($hash, "00", shift @{$hash->{WakeUp}});
  }


  my @changed;
  my $tn = TimeNow();
  for(my $i = 0; $i < int(@event); $i++) {
    next if($event[$i] eq "");
    my ($vn, $vv) = split(":", $event[$i], 2);
    if($vn eq "state") {
      if($hash->{STATE} ne $vv) {
        $hash->{STATE} = $vv;
        push @changed, $vv;
      }
      push @changed, "reportedState:$vv";

    } else {
      push @changed, "$vn: $vv";

    }
    $hash->{READINGS}{$vn}{TIME} = $tn;
    $hash->{READINGS}{$vn}{VAL} = $vv;
  }
  $hash->{CHANGED} = \@changed;
  return $hash->{NAME};
}

#####################################
sub
ZWave_Undef($$)
{
  my ($hash, $arg) = @_;
  my $homeId = $hash->{homeId};
  my $id = $hash->{id};
  delete $modules{ZWave}{defptr}{"$homeId $id"};
  return undef;
}

1;

=begin html

<a name="CUL"></a>
<h3>CUL</h3>
<ul>
text
</ul>

=end html
