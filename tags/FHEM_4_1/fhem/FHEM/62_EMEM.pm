##############################################
package main;

use strict;
use warnings;
use Time::HiRes qw(gettimeofday);

sub EMEM_Get($@);
sub EMEM_Set($@);
sub EMEM_Define($$);
sub EMEM_GetStatus($);

###################################
sub
EMEM_Initialize($)
{
  my ($hash) = @_;

  $hash->{GetFn}     = "EMEM_Get";
  $hash->{DefFn}     = "EMEM_Define";

  $hash->{AttrList}  = "dummy:1,0 model;EM1000EM loglevel:0,1,2,3,4,5,6";
}

###################################
sub
EMEM_GetStatus($)
{
  my ($hash) = @_;

  if(!$hash->{LOCAL}) {
    InternalTimer(gettimeofday()+300, "EMEM_GetStatus", $hash);
  }

  my $dnr = $hash->{DEVNR};
  my $name = $hash->{NAME};

  my $d = IOWrite($hash, sprintf("7a%02x", $dnr-1));
  if(!defined($d)) {
    my $msg = "EMEM $name read error";
    Log GetLogLevel($name,2), $msg;
    return $msg;
  }

  if($d eq ((pack('H*',"00") x 45) . pack('H*',"FF") x 6)) {
    my $msg = "EMEM no device no. $dnr present";
    Log GetLogLevel($name,2), $msg;
    return $msg;
  }

  my $pulses=w($d,13);
  my $iec = 1000;
  my $cur_power = $pulses / 100;

  if($cur_power > 30) { # 20Amp x 3 Phase
    my $msg = "EMEM Bogus reading: curr. power is reported to be $cur_power setting to -1";
    Log GetLogLevel($name,2), $msg;
    #return $msg;
    $cur_power = -1.0;
  }

  my %vals;
  $vals{"5min_pulses"}        = $pulses;
  $vals{"energy_kWh_h"}       = sprintf("%0.3f", dw($d,33) / $iec);
  $vals{"energy_today_kWh_d"} = sprintf("%0.3f", dw($d,37) / $iec);
  $vals{"energy_total_kWh"}   = sprintf("%0.3f", dw($d,41) / $iec);
  $vals{"power_kW"}           = sprintf("%.3f", $cur_power);
  $vals{"alarm_PA_W"}         = w($d,45);
  $vals{"price_CF"}           = sprintf("%.3f", w($d,47)/10000);


  my $tn = TimeNow();
  my $idx = 0;
  foreach my $k (keys %vals) {
    my $v = $vals{$k};
    $hash->{CHANGED}[$idx++] = "$k: $v";
    $hash->{READINGS}{$k}{TIME} = $tn;
    $hash->{READINGS}{$k}{VAL} = $v
  }

  if(!$hash->{LOCAL}) {
    DoTrigger($name, undef) if($init_done);
  }

  $hash->{STATE} = "$cur_power kW";
  Log GetLogLevel($name,4), "EMEM $name: $cur_power kW / $vals{energy_kWh_h} kWh/h";

  return $hash->{STATE};
}

###################################
sub
EMEM_Get($@)
{
  my ($hash, @a) = @_;

  return "argument is missing" if(int(@a) != 2);

  my $d = $hash->{DEVNR};
  my $msg;

  if($a[1] ne "status") {
    return "unknown get value, valid is status";
  }
  $hash->{LOCAL} = 1;
  my $v = EMEM_GetStatus($hash);
  delete $hash->{LOCAL};

  return "$a[0] $a[1] => $v";
}

#############################
sub
EMEM_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);

  return "syntax: define <name> EMEM devicenumber"
    if(@a != 3 || $a[2] !~ m,^[5-8]$,);
  $hash->{DEVNR} = $a[2];
  AssignIoPort($hash);


  # InternalTimer blocks if init_done is not true
  my $oid = $init_done;
  $init_done = 1;
  EMEM_GetStatus($hash);
  $init_done = $oid;
  return undef;
}

1;
