################################################################
#
#  Copyright notice
#
#  (c) 2009 Copyright: Kai 'wusel' Siering (wusel+fhem at uu dot org)
#  All rights reserved
#
#  This code is free software; you can redistribute it and/or modify
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
###############################################

###########################
# 17_SIS_PMS.pm
# Module for FHEM
#
# Contributed by Kai 'wusel' Siering <wusel+fhem@uu.org> in 2010
# Based in part on work for FHEM by other authors ...
# $Id$
###########################

package main;

use strict;
use warnings;

my $SIS_PMS_cmds ="off on on-till off-till toggle";

sub
SIS_PMS_Initialize($)
{
  my ($hash) = @_;

  $hash->{Match}     = "^socket ..:..:..:..:.. . state o.*";
  $hash->{SetFn}     = "SIS_PMS_Set";
#  $hash->{StateFn}   = "SIS_PMS_SetState";
  $hash->{DefFn}     = "SIS_PMS_Define";
  $hash->{UndefFn}   = "SIS_PMS_Undef";
  $hash->{ParseFn}   = "SIS_PMS_Parse";
}


#############################
sub
SIS_PMS_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);

  my $u = "wrong syntax: define <name> SIS_PMS <serial> <socket>";

  return $u if(int(@a) < 4);

  my $serial = $a[2];
  my $socketnr = $a[3];
  my $name = $a[0];
  my $serialnocolon=$serial;
  $serialnocolon =~ s/:/_/g;

  $modules{SIS_PMS}{defptr}{$name}  = $hash;
  $hash->{SERIAL} = $serial;
  $hash->{SOCKET} = $socketnr;
  $hash->{NAME} = $name;
  $modules{SIS_PMS}{defptr}{$serialnocolon . $socketnr} = $hash;
  $hash->{PREV}{STATE} = "undefined";
  AssignIoPort($hash);
}


#############################
sub
SIS_PMS_Undef($$)
{
  my ($hash, $name) = @_;
#
#  foreach my $c (keys %{ $hash->{CODE} } ) {
#    $c = $hash->{CODE}{$c};
#
#    # As after a rename the $name my be different from the $defptr{$c}{$n}
#    # we look for the hash.
#    foreach my $dname (keys %{ $modules{SIS_PMS}{defptr}{$c} }) {
#      delete($modules{SIS_PMS}{defptr}{$c}{$dname})
#        if($modules{SIS_PMS}{defptr}{$c}{$dname} == $hash);
#    }
#  }
  return undef;
}


#############################
sub
SIS_PMS_Parse($$)
{
    my ($hash, $msg) = @_;
    my $serial;
    my $socknr;
    my $sockst;
    my $dummy;
    my $serialnocolon;
    
    
    # Msg format: 
    # ^socket ..:..:..:..:.. . state o.*";

    ($dummy, $serial, $socknr, $dummy, $sockst) = split(' ', $msg);
    $serialnocolon=$serial;
    $serialnocolon =~ s/:/_/g;

    my $def = $modules{SIS_PMS}{defptr}{$serialnocolon . $socknr};
    if($def) {
	Log 5, "SIS_PMS: Found device as " . $def->{NAME};
	if($def->{STATE} ne $sockst) {
	    $def->{READINGS}{PREVSTATE}{TIME} = TimeNow();
	    $def->{READINGS}{PREVSTATE}{VAL} = $def->{STATE};
	    Log 3, "SIS_PMS " . $def->{NAME} ." state changed from " . $def->{STATE} . " to $sockst";
	    $def->{PREV}{STATE} = $def->{STATE};
	    $def->{CHANGED}[0] = $sockst;
	    DoTrigger($def->{NAME}, undef);
	}
	$def->{STATE} = $sockst;
	$def->{READINGS}{STATE}{TIME} = TimeNow();
	$def->{READINGS}{STATE}{VAL} = $sockst;
	Log 5, "SIS_PMS " . $def->{NAME} ." state $sockst";

	return $def->{NAME};
    } else {
	my $devname=$serial;
	
	$devname =~ s/:/_/g;
	Log 3, "SIS_PMS Unknown device $serial $socknr, please define it";
	return "UNDEFINED SIS_PMS_$devname.$socknr SIS_PMS $serial $socknr";
    }
}


#############################
sub
SIS_PMS_Do_On_Till($@)
{
  my ($hash, @a) = @_;
  return "Timespec (HH:MM[:SS]) needed for the on-till command" if(@a != 3);

  my ($err, $hr, $min, $sec, $fn) = GetTimeSpec($a[2]);
  return $err if($err);

  my @lt = localtime;
  my $hms_till = sprintf("%02d:%02d:%02d", $hr, $min, $sec);
  my $hms_now = sprintf("%02d:%02d:%02d", $lt[2], $lt[1], $lt[0]);
  if($hms_now ge $hms_till) {
    Log 4, "on-till: won't switch as now ($hms_now) is later than $hms_till";
    return "";
  }

  my @b = ($a[0], "on");
  SIS_PMS_Set($hash, @b);
  my $tname = $hash->{NAME} . "_till";
  CommandDelete(undef, $tname) if($defs{$tname});
  CommandDefine(undef, "$tname at $hms_till set $a[0] off");

}

#############################
sub
SIS_PMS_Do_Off_Till($@)
{
  my ($hash, @a) = @_;
  return "Timespec (HH:MM[:SS]) needed for the off-till command" if(@a != 3);

  my ($err, $hr, $min, $sec, $fn) = GetTimeSpec($a[2]);
  return $err if($err);

  my @lt = localtime;
  my $hms_till = sprintf("%02d:%02d:%02d", $hr, $min, $sec);
  my $hms_now = sprintf("%02d:%02d:%02d", $lt[2], $lt[1], $lt[0]);
  if($hms_now ge $hms_till) {
    Log 4, "off-till: won't switch as now ($hms_now) is later than $hms_till";
    return "";
  }

  my @b = ($a[0], "off");
  SIS_PMS_Set($hash, @b);
  my $tname = $hash->{NAME} . "_till";
  CommandDelete(undef, $tname) if($defs{$tname});
  CommandDefine(undef, "$tname at $hms_till set $a[0] on");

}


###################################
sub
SIS_PMS_Set($@)
{
    my ($hash, @a) = @_;
    my $ret = undef;
    my $na = int(@a);
    
    my $what = lc($a[1]);

    return "no set value specified" if($na < 2 || $na > 3);

    my @cmds=split(" ", $SIS_PMS_cmds);
    my $ncmds=int(@cmds);
    my $i;
    my $known_cmd=0;

    for($i=0; $i<$ncmds; $i++) {
	if($cmds[$i] eq $what) {
	    $known_cmd++;
	}
    }
    if($known_cmd==0) {
	return "Unknown argument $what, choose one of $SIS_PMS_cmds";
    }

    return SIS_PMS_Do_On_Till($hash, @a) if($a[1] eq "on-till");
    return SIS_PMS_Do_Off_Till($hash, @a) if($a[1] eq "off-till");

    my $prevstate=$hash->{STATE};
    my $currstate=$what;

    if($what eq "toggle") {
	if($prevstate eq "on") {
	    $currstate="off";
	} elsif($prevstate eq "off") {
	    $currstate="on";
	}
    }
    
    if($prevstate ne $currstate) {
	$hash->{READINGS}{PREVSTATE}{TIME} = TimeNow();
	$hash->{READINGS}{PREVSTATE}{VAL} = $prevstate;
	Log 3, "SIS_PMS " . $hash->{NAME} ." state changed from $prevstate to $currstate";
	$hash->{PREV}{STATE} = $prevstate;
	$hash->{CHANGED}[0] = $currstate;
	$hash->{STATE} = $currstate;
	$hash->{READINGS}{STATE}{TIME} = TimeNow();
	$hash->{READINGS}{STATE}{VAL} = $currstate;
#	DoTrigger($hash->{NAME}, undef);
    }

    my $msg;
    $msg=sprintf("%s %s %s", $hash->{SERIAL}, $hash->{SOCKET}, $what);

    IOWrite($hash, $what, $msg);

    return $ret;
}


1;
