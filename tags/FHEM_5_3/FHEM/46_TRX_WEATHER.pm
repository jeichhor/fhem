#################################################################################
# 46_TRX_WEATHER.pm
# FHEM module to decode weather sensor messages for RFXtrx
#
# The following devices are implemented to be received:
#
# temperature sensors (TEMP):
# * "THR128" 	is THR128/138, THC138
# * "THGR132N" 	is THC238/268,THN132,THWR288,THRN122,THN122,AW129/131
# * "THWR800" 	is THWR800
# * "RTHN318"	is RTHN318
# * "TX3_T" 	is LaCrosse TX3, TX4, TX17
# * "TS15C" 	is TS15C
#
# temperature/humidity sensors (TEMPHYDRO):
# * "THGR228N"	is THGN122/123, THGN132, THGR122/228/238/268
# * "THGR810"	is THGR810
# * "RTGR328"	is RTGR328
# * "THGR328"	is THGR328
# * "WTGR800_T"	is WTGR800
# * "THGR918"	is THGR918, THGRN228, THGN500
# * "TFATS34C"	is TFA TS34C
# * "WT450H"	is UPM WT450H
#
# temperature/humidity/pressure sensors (TEMPHYDROBARO):
# * "BTHR918"	is BTHR918
# * "BTHR918N"	is BTHR918N, BTHR968
#
# rain gauge sensors (RAIN):
# * "RGR918" 	is RGR126/682/918
# * "PCR800"	is PCR800
# * "TFA_RAIN"	is TFA
# * "RG700"	is UPM RG700
#
# wind sensors (WIND):
# * "WTGR800_A" is WTGR800
# * "WGR800_A"	is WGR800
# * "WGR918"	is STR918, WGR918
# * "TFA_WIND"	is TFA
# * "WDS500" is UPM WDS500
#
# Weighing scales (WEIGHT): 
# "BWR101" is Oregon Scientific BWR101
# "GR101" is Oregon Scientific GR101
#
# Copyright (C) 2012 Willi Herzig
#
#  This script is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# Some code was derived and modified from xpl-perl 
# from the following two files:
#	xpl-perl/lib/xPL/Utils.pm:
#	xpl-perl/lib/xPL/RF/Oregon.pm:
#
#SEE ALSO
# Project website: http://www.xpl-perl.org.uk/
# AUTHOR: Mark Hindess, soft-xpl-perl@temporalanomaly.com
#
# Copyright (C) 2007, 2009 by Mark Hindess
#
# This library is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself, either Perl version 5.8.7 or,
# at your option, any later version of Perl 5 you may have available.

##################################
#
# values for "set global verbose"
# 4: log unknown protocols
# 5: log decoding hexlines for debugging
#
# $Id$
package main;

use strict;
use warnings;

# Hex-Debugging into READING hexline? YES = 1, NO = 0
my $TRX_HEX_debug = 0;

my $time_old = 0;

sub
TRX_WEATHER_Initialize($)
{
  my ($hash) = @_;

  $hash->{Match}     = "^..(50|51|52|54|55|56|5d).*";
  $hash->{DefFn}     = "TRX_WEATHER_Define";
  $hash->{UndefFn}   = "TRX_WEATHER_Undef";
  $hash->{ParseFn}   = "TRX_WEATHER_Parse";
  $hash->{AttrList}  = "IODev ignore:1,0 event-on-update-reading event-on-change-reading do_not_notify:1,0 loglevel:0,1,2,3,4,5,6";

}

#####################################
sub
TRX_WEATHER_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);

	my $a = int(@a);
	#print "a0 = $a[0]";
  return "wrong syntax: define <name> TRX_WEATHER code" if(int(@a) != 3);

  my $name = $a[0];
  my $code = $a[2];

  $hash->{CODE} = $code;
  $modules{TRX_WEATHER}{defptr}{$code} = $hash;
  AssignIoPort($hash);

  return undef;
}

#####################################
sub
TRX_WEATHER_Undef($$)
{
  my ($hash, $name) = @_;
  delete($modules{TRX_WEATHER}{defptr}{$name});
  return undef;
}

# --------------------------------------------
# sensor types 

my %types =
  (
   # TEMP
   0x5008 => { part => 'TEMP', method => \&TRX_WEATHER_common_temp, },
   # HYDRO
   0x5108 => { part => 'HYDRO', method => \&TRX_WEATHER_common_hydro, },
   # TEMP HYDRO
   0x520a => { part => 'TEMPHYDRO', method => \&TRX_WEATHER_common_temphydro, },
   # TEMP HYDRO BARO
   0x540d => { part => 'TEMPHYDROBARO', method => \&TRX_WEATHER_common_temphydrobaro, },
   # RAIN
   0x550b => { part => 'RAIN', method => \&TRX_WEATHER_common_rain, },
   # WIND
   0x5610 => { part => 'WIND', method => \&TRX_WEATHER_common_anemometer, },
   # WEIGHT
   0x5D08 => { part => 'WEIGHT', method => \&TRX_WEATHER_common_weight, },
  );

# --------------------------------------------

#my $DOT = q{.};
# Important: change it to _, because FHEM uses regexp
my $DOT = q{_};

my @TRX_WEATHER_winddir_name=("N","NNE","NE","ENE","E","ESE","SE","SSE","S","SSW","SW","WSW","W","WNW","NW","NNW");

# --------------------------------------------
# The following functions are changed:
#	- some parameter like "parent" and others are removed
#	- @res array return the values directly (no usage of xPL::Message)

sub TRX_WEATHER_temperature {
  my ($bytes, $dev, $res, $off) = @_;

  my $temp =
    (
    (($bytes->[$off] & 0x80) ? -1 : 1) *
        (($bytes->[$off] & 0x7f)*256 + $bytes->[$off+1]) 
    )/10;

  push @$res, {
       		device => $dev,
       		type => 'temp',
       		current => $temp,
		units => 'Grad Celsius'
  	}

}

sub TRX_WEATHER_chill_temperature {
  my ($bytes, $dev, $res, $off) = @_;

  my $temp =
    (
    (($bytes->[$off] & 0x80) ? -1 : 1) *
        (($bytes->[$off] & 0x7f)*256 + $bytes->[$off+1]) 
    )/10;

  push @$res, {
       		device => $dev,
       		type => 'chilltemp',
       		current => $temp,
		units => 'Grad Celsius'
  	}

}

sub TRX_WEATHER_humidity {
  my ($bytes, $dev, $res, $off) = @_;
  my $hum = $bytes->[$off];
  my $hum_str = ['dry', 'comfortable', 'normal',  'wet']->[$bytes->[$off+1]];
  push @$res, {
	device => $dev,
	type => 'humidity',
	current => $hum,
	string => $hum_str,
	units => '%'
  }
}

sub TRX_WEATHER_pressure {
  my ($bytes, $dev, $res, $off) = @_;

  #my $offset = 795 unless ($offset);
  my $hpa = ($bytes->[$off])*256 + $bytes->[$off+1];
  my $forecast = { 0x00 => 'noforecast',
		   0x01 => 'sunny',
                   0x02 => 'partly',
                   0x03 => 'cloudy',
                   0x04 => 'rain',
                 }->{$bytes->[$off+2]} || 'unknown';
  push @$res, {
	device => $dev,
	type => 'pressure',
	current => $hpa,
	units => 'hPa',
	forecast => $forecast,
  };
}

sub TRX_WEATHER_simple_battery {
  my ($bytes, $dev, $res, $off) = @_;

  my $battery;

  my $battery_level = $bytes->[$off] & 0x0f;
  if ($battery_level == 0x9) { $battery = 'ok'}
  elsif ($battery_level == 0x0) { $battery = 'low'}
  else { 
	$battery = sprintf("unknown-%02x",$battery_level);
  }

  push @$res, {
	device => $dev,
	type => 'battery',
	current => $battery,
  };
}

sub TRX_WEATHER_battery {
  my ($bytes, $dev, $res, $off) = @_;

  my $battery;

  my $battery_level = ($bytes->[$off] & 0x0f) + 1;

  if ($battery_level > 5) {
    $battery = sprintf("ok %d0%%",$battery_level);
  } else {
    $battery = sprintf("low %d0%%",$battery_level);
  }

  push @$res, {
	device => $dev,
	type => 'battery',
	current => $battery,
  };
}


# Test if to use longid for device type
sub TRX_WEATHER_use_longid {
  my ($longids,$dev_type) = @_;

  return 0 if ($longids eq "");
  return 0 if ($longids eq "0");

  return 1 if ($longids eq "1");
  return 1 if ($longids eq "ALL");

  return 1 if(",$longids," =~ m/,$dev_type,/);

  return 0;
}

# ------------------------------------------------------------
#
sub TRX_WEATHER_common_anemometer {
    	my $type = shift;
	my $longids = shift;
    	my $bytes = shift;

  my $subtype = sprintf "%02x", $bytes->[1];
  #Log 1,"subtype=$subtype";
  my $dev_type;

  my %devname =
    (	# HEXSTRING => "NAME"
	0x01 => "WTGR800_A",
	0x02 => "WGR800",
	0x03 => "WGR918",
	0x04 => "TFA_WIND",
	0x05 => "WDS500", # UPM WDS500
  );

  if (exists $devname{$bytes->[1]}) {
  	$dev_type = $devname{$bytes->[1]};
  } else {
  	Log 1,"TRX_WEATHER: common_anemometer error undefined subtype=$subtype";
  	my @res = ();
  	return @res;
  }

  #my $seqnbr = sprintf "%02x", $bytes->[2];
  #Log 1,"seqnbr=$seqnbr";

  my $dev_str = $dev_type;
  if (TRX_WEATHER_use_longid($longids,$dev_type)) {
  	$dev_str .= $DOT.sprintf("%02x", $bytes->[3]);
  }
  if ($bytes->[4] > 0) {
  	$dev_str .= $DOT.sprintf("%d", $bytes->[4]);
  }

  my @res = ();

  # hexline debugging
  if ($TRX_HEX_debug) {
    my $hexline = ""; for (my $i=0;$i<@$bytes;$i++) { $hexline .= sprintf("%02x",$bytes->[$i]);} 
    push @res, { device => $dev_str, type => 'hexline', current => $hexline, units => 'hex', };
  }

  my $dir = $bytes->[5]*256 + $bytes->[6];
  my $dirname = $TRX_WEATHER_winddir_name[$dir/22.5];

  my $avspeed = $bytes->[7]*256 + $bytes->[8];
  my $speed = $bytes->[9]*256 + $bytes->[10];

  if ($dev_type eq "TFA_WIND") {
  	TRX_WEATHER_temperature($bytes, $dev_str, \@res, 11); 
  	TRX_WEATHER_chill_temperature($bytes, $dev_str, \@res, 13); 
  }

  push @res, {
	device => $dev_str,
	type => 'speed',
	current => $speed,
	average => $avspeed,
	units => 'mps',
  } , {
	device => $dev_str,
	type => 'direction',
	current => $dir,
	string => $dirname,
	units => 'degrees',
  };

  TRX_WEATHER_simple_battery($bytes, $dev_str, \@res, 15);

  return @res;
}


# -----------------------------
sub TRX_WEATHER_common_temp {
  my $type = shift;
  my $longids = shift;
  my $bytes = shift;

  my $subtype = sprintf "%02x", $bytes->[1];
  #Log 1,"subtype=$subtype";
  my $dev_type;

  my %devname =
    (	# HEXSTRING => "NAME"
	0x01 => "THR128",
	0x02 => "THGR132N", # was THGR228N,
	0x03 => "THWR800",
	0x04 => "RTHN318",
	0x05 => "TX3", # LaCrosse TX3
	0x06 => "TS15C", 
  );

  if (exists $devname{$bytes->[1]}) {
  	$dev_type = $devname{$bytes->[1]};
  } else {
  	Log 1,"RFX_WEATHER: common_temp error undefined subtype=$subtype";
  	my @res = ();
  	return @res;
  }

  #my $seqnbr = sprintf "%02x", $bytes->[2];
  #Log 1,"seqnbr=$seqnbr";

  my $dev_str = $dev_type;
  if (TRX_WEATHER_use_longid($longids,$dev_type)) {
  	$dev_str .= $DOT.sprintf("%02x", $bytes->[3]);
  }
  if ($bytes->[4] > 0) {
  	$dev_str .= $DOT.sprintf("%d", $bytes->[4]);
  }
  #Log 1,"dev_str=$dev_str";

  my @res = ();

  # hexline debugging
  if ($TRX_HEX_debug) {
    my $hexline = ""; for (my $i=0;$i<@$bytes;$i++) { $hexline .= sprintf("%02x",$bytes->[$i]);} 
    push @res, { device => $dev_str, type => 'hexline', current => $hexline, units => 'hex', };
  }

  TRX_WEATHER_temperature($bytes, $dev_str, \@res, 5); 
  TRX_WEATHER_simple_battery($bytes, $dev_str, \@res, 7);
  return @res;
}

# -----------------------------
sub TRX_WEATHER_common_hydro {
  my $type = shift;
  my $longids = shift;
  my $bytes = shift;

  my $subtype = sprintf "%02x", $bytes->[1];
  #Log 1,"subtype=$subtype";
  my $dev_type;

  my %devname =
    (	# HEXSTRING => "NAME"
	0x01 => "TX3", # LaCrosse TX3
  );

  if (exists $devname{$bytes->[1]}) {
  	$dev_type = $devname{$bytes->[1]};
  } else {
  	Log 1,"RFX_WEATHER: common_hydro error undefined subtype=$subtype";
  	my @res = ();
  	return @res;
  }

  my $dev_str = $dev_type;
  if (TRX_WEATHER_use_longid($longids,$dev_type)) {
  	$dev_str .= $DOT.sprintf("%02x", $bytes->[3]);
  }
  if ($bytes->[4] > 0) {
  	$dev_str .= $DOT.sprintf("%d", $bytes->[4]);
  }
  #Log 1,"dev_str=$dev_str";

  my @res = ();

  # hexline debugging
  if ($TRX_HEX_debug) {
    my $hexline = ""; for (my $i=0;$i<@$bytes;$i++) { $hexline .= sprintf("%02x",$bytes->[$i]);} 
    push @res, { device => $dev_str, type => 'hexline', current => $hexline, units => 'hex', };
  }

  TRX_WEATHER_humidity($bytes, $dev_str, \@res, 5); 
  TRX_WEATHER_simple_battery($bytes, $dev_str, \@res, 7);
  return @res;
}

# -----------------------------
sub TRX_WEATHER_common_temphydro {
  my $type = shift;
  my $longids = shift;
  my $bytes = shift;

  my $subtype = sprintf "%02x", $bytes->[1];
  #Log 1,"subtype=$subtype";
  my $dev_type;

  my %devname =
    (	# HEXSTRING => "NAME"
	0x01 => "THGR228N", # THGN122/123, THGN132, THGR122/228/238/268
	0x02 => "THGR810",
	0x03 => "RTGR328",
	0x04 => "THGR328",
	0x05 => "WTGR800_T",
	0x06 => "THGR918",
	0x07 => "TFATS34C",
	0x08 => "WT450H",
  );

  if (exists $devname{$bytes->[1]}) {
  	$dev_type = $devname{$bytes->[1]};
  } else {
  	Log 1,"RFX_WEATHER: common_temphydro error undefined subtype=$subtype";
  	my @res = ();
  	return @res;
  }

  my $dev_str = $dev_type;
  if (TRX_WEATHER_use_longid($longids,$dev_type)) {
  	$dev_str .= $DOT.sprintf("%02x", $bytes->[3]);
  }
  if ($bytes->[4] > 0) {
  	$dev_str .= $DOT.sprintf("%d", $bytes->[4]);
  }

  my @res = ();

  # hexline debugging
  if ($TRX_HEX_debug) {
    my $hexline = ""; for (my $i=0;$i<@$bytes;$i++) { $hexline .= sprintf("%02x",$bytes->[$i]);} 
    push @res, { device => $dev_str, type => 'hexline', current => $hexline, units => 'hex', };
  }

  TRX_WEATHER_temperature($bytes, $dev_str, \@res, 5);
  TRX_WEATHER_humidity($bytes, $dev_str, \@res, 7); 
  TRX_WEATHER_simple_battery($bytes, $dev_str, \@res, 9);
  return @res;
}

# -----------------------------
sub TRX_WEATHER_common_temphydrobaro {
  my $type = shift;
  my $longids = shift;
  my $bytes = shift;

  my $subtype = sprintf "%02x", $bytes->[1];
  #Log 1,"subtype=$subtype";
  my $dev_type;

  my %devname =
    (	# HEXSTRING => "NAME"
	0x01 => "BTHR918",
	0x02 => "BTHR918N",
  );

  if (exists $devname{$bytes->[1]}) {
  	$dev_type = $devname{$bytes->[1]};
  } else {
  	Log 1,"RFX_WEATHER: common_temphydrobaro error undefined subtype=$subtype";
  	my @res = ();
  	return @res;
  }

  my $dev_str = $dev_type;
  if (TRX_WEATHER_use_longid($longids,$dev_type)) {
  	$dev_str .= $DOT.sprintf("%02x", $bytes->[3]);
  }
  if ($bytes->[4] > 0) {
  	$dev_str .= $DOT.sprintf("%d", $bytes->[4]);
  }
  #Log 1,"dev_str=$dev_str";

  my @res = ();

  # hexline debugging
  if ($TRX_HEX_debug) {
    my $hexline = ""; for (my $i=0;$i<@$bytes;$i++) { $hexline .= sprintf("%02x",$bytes->[$i]);} 
    push @res, { device => $dev_str, type => 'hexline', current => $hexline, units => 'hex', };
  }

  TRX_WEATHER_temperature($bytes, $dev_str, \@res, 5); 
  TRX_WEATHER_humidity($bytes, $dev_str, \@res, 7); 
  TRX_WEATHER_pressure($bytes, $dev_str, \@res, 9);
  TRX_WEATHER_simple_battery($bytes, $dev_str, \@res, 12);
  return @res;
}

# -----------------------------
sub TRX_WEATHER_common_rain {
  my $type = shift;
  my $longids = shift;
  my $bytes = shift;


  my $subtype = sprintf "%02x", $bytes->[1];
  #Log 1,"subtype=$subtype";
  my $dev_type;

  my %devname =
    (	# HEXSTRING => "NAME"
	0x01 => "RGR918",
	0x02 => "PCR800",
	0x03 => "TFA_RAIN",
	0x04 => "RG700",
  );

  if (exists $devname{$bytes->[1]}) {
  	$dev_type = $devname{$bytes->[1]};
  } else {
  	Log 1,"TRX_WEATHER: common_rain error undefined subtype=$subtype";
  	my @res = ();
  	return @res;
  }

  my $dev_str = $dev_type;
  if (TRX_WEATHER_use_longid($longids,$dev_type)) {
  	$dev_str .= $DOT.sprintf("%02x", $bytes->[3]);
  }
  if ($bytes->[4] > 0) {
  	$dev_str .= $DOT.sprintf("%d", $bytes->[4]);
  }

  my @res = ();

  # hexline debugging
  if ($TRX_HEX_debug) {
    my $hexline = ""; for (my $i=0;$i<@$bytes;$i++) { $hexline .= sprintf("%02x",$bytes->[$i]);} 
    push @res, { device => $dev_str, type => 'hexline', current => $hexline, units => 'hex', };
  }

  my $rain = $bytes->[5]*256 + $bytes->[6];
  if ($dev_type eq "RGR918") {
  	push @res, {
		device => $dev_str,
		type => 'rain',
		current => $rain,
		units => 'mm/h',
  	};
  } elsif ($dev_type eq "PCR800") {
	$rain = $rain / 100;
  	push @res, {
		device => $dev_str,
		type => 'rain',
		current => $rain,
		units => 'mm/h',
  	};
  }

  my $train = ($bytes->[7]*256*256 + $bytes->[8]*256 + $bytes->[9])/10; # total rain
  push @res, {
	device => $dev_str,
	type => 'train',
	current => $train,
	units => 'mm',
  };

  TRX_WEATHER_battery($bytes, $dev_str, \@res, 10);
  return @res;
}

# ------------------------------------------------------------
#
sub TRX_WEATHER_common_weight {
    	my $type = shift;
	my $longids = shift;
    	my $bytes = shift;

  my $subtype = sprintf "%02x", $bytes->[1];
  #Log 1,"subtype=$subtype";
  my $dev_type;

  my %devname =
    (	# HEXSTRING => "NAME"
	0x01 => "BWR101",
	0x02 => "GR101",
  );

  if (exists $devname{$bytes->[1]}) {
  	$dev_type = $devname{$bytes->[1]};
  } else {
  	Log 1,"TRX_WEATHER: common_weight error undefined subtype=$subtype";
  	my @res = ();
  	return @res;
  }

  #my $seqnbr = sprintf "%02x", $bytes->[2];
  #Log 1,"seqnbr=$seqnbr";

  my $dev_str = $dev_type;
  if (TRX_WEATHER_use_longid($longids,$dev_type)) {
  	$dev_str .= $DOT.sprintf("%02x", $bytes->[3]);
  }
  if ($bytes->[4] > 0) {
  	$dev_str .= $DOT.sprintf("%d", $bytes->[4]);
  }

  my @res = ();

  # hexline debugging
  if ($TRX_HEX_debug) {
    my $hexline = ""; for (my $i=0;$i<@$bytes;$i++) { $hexline .= sprintf("%02x",$bytes->[$i]);} 
    push @res, { device => $dev_str, type => 'hexline', current => $hexline, units => 'hex', };
  }

  my $weight = ($bytes->[5]*256 + $bytes->[6])/10;

  push @res, {
	device => $dev_str,
	type => 'weight',
	current => $weight,
	units => 'kg',
  };

  #TRX_WEATHER_simple_battery($bytes, $dev_str, \@res, 7);

  return @res;
}


# -----------------------------
sub
TRX_WEATHER_Parse($$)
{
  my ($iohash, $hexline) = @_;

  #my $hashname = $iohash->{NAME};
  #my $longid = AttrVal($hashname,"longids","");
  #Log 1,"2: name=$hashname, attr longids = $longid";

  my $longids = 0;
  if (defined($attr{$iohash->{NAME}}{longids})) {
  	$longids = $attr{$iohash->{NAME}}{longids};
  	#Log 1,"0: attr longids = $longids";
  }

  my $time = time();
  # convert to binary
  my $msg = pack('H*', $hexline);
  if ($time_old ==0) {
  	Log 5, "TRX_WEATHER: decoding delay=0 hex=$hexline";
  } else {
  	my $time_diff = $time - $time_old ;
  	Log 5, "TRX_WEATHER: decoding delay=$time_diff hex=$hexline";
  }
  $time_old = $time;

  # convert string to array of bytes. Skip length byte
  my @rfxcom_data_array = ();
  foreach (split(//, substr($msg,1))) {
    push (@rfxcom_data_array, ord($_) );
  }

  my $num_bytes = ord($msg);

  if ($num_bytes < 3) {
    return;
  }

  my $type = $rfxcom_data_array[0];

  my $sensor_id = unpack('H*', chr $type);

  my $key = ($type << 8) + $num_bytes;

  my $rec = $types{$key};

  unless ($rec) {
    Log 4, "TRX_WEATHER: ERROR: Unknown sensor_id=$sensor_id message='$hexline'";
    Log 1, "TRX_WEATHER: ERROR: Unknown sensor_id=$sensor_id message='$hexline'";
    return "";
  }
  
  my $method = $rec->{method};
  unless ($method) {
    Log 4, "TRX_WEATHER: Possible message from Oregon part '$rec->{part}'";
    Log 4, "TRX_WEATHER: sensor_id=$sensor_id";
    return;
  }

  my @res;

  if (! defined(&$method)) {
    Log 4, "TRX_WEATHER: Error: Unknown function=$method. Please define it in file $0";
    Log 4, "TRX_WEATHER: sensor_id=$sensor_id\n";
    return "";
  } else {
    #Log 1, "TRX_WEATHER: parsing sensor_id=$sensor_id message='$hexline'";
    @res = $method->($rec->{part}, $longids, \@rfxcom_data_array);
  }

  # get device name from first entry
  my $device_name = $res[0]->{device};
  #Log 1, "device_name=$device_name";

  if (! defined($device_name)) {
    Log 4, "TRX_WEATHER: error device_name undefined\n";
    return "";
  }

  my $def = $modules{TRX_WEATHER}{defptr}{"$device_name"};
  if(!$def) {
	Log 3, "TRX_WEATHER: Unknown device $device_name, please define it";
    	return "UNDEFINED $device_name TRX_WEATHER $device_name";
  }
  # Use $def->{NAME}, because the device may be renamed:
  my $name = $def->{NAME};
  return "" if(IsIgnored($name));

  my $n = 0;
  my $tm = TimeNow();

  my $i;
  my $val = "";
  my $sensor = "";

  readingsBeginUpdate($def);
  foreach $i (@res){
 	#print "!> i=".$i."\n";
	#printf "%s\t",$i->{device};
	if ($i->{type} eq "temp") { 
			#printf "Temperatur %2.1f %s ; ",$i->{current},$i->{units};
			$val .= "T: ".$i->{current}." ";

			$sensor = "temperature";			
			readingsUpdate($def, $sensor, $i->{current});
  	} 
	elsif ($i->{type} eq "chilltemp") { 
			#printf "Temperatur %2.1f %s ; ",$i->{current},$i->{units};
			$val .= "CT: ".$i->{current}." ";

			$sensor = "windchill";			
			readingsUpdate($def, $sensor, $i->{current});
  	} 
	elsif ($i->{type} eq "humidity") { 
			#printf "Luftfeuchtigkeit %d%s, %s ;",$i->{current},$i->{units},$i->{string};
			$val .= "H: ".$i->{current}." ";

			$sensor = "humidity";			
			readingsUpdate($def, $sensor, $i->{current});
	}
	elsif ($i->{type} eq "battery") { 
			#printf "Batterie %d%s; ",$i->{current},$i->{units};
			my $tmp_battery = $i->{current};
			my @words = split(/\s+/,$i->{current});
			$val .= "BAT: ".$words[0]." "; #use only first word

			$sensor = "battery";			
			readingsUpdate($def, $sensor, $i->{current});
	}
	elsif ($i->{type} eq "pressure") { 
			#printf "Luftdruck %d %s, Vorhersage=%s ; ",$i->{current},$i->{units},$i->{forecast};
			# do not add it due to problems with hms.gplot
			$val .= "P: ".$i->{current}." ";

			$sensor = "pressure";			
			readingsUpdate($def, $sensor, $i->{current});

			$sensor = "forecast";			
			readingsUpdate($def, $sensor, $i->{forecast});
	}
	elsif ($i->{type} eq "speed") { 
			$val .= "W: ".$i->{current}." ";
			$val .= "WA: ".$i->{average}." ";

			$sensor = "wind_speed";			
			readingsUpdate($def, $sensor, $i->{current});

			$sensor = "wind_avspeed";			
			readingsUpdate($def, $sensor, $i->{average});
	}
	elsif ($i->{type} eq "direction") { 
			$val .= "WD: ".$i->{current}." ";
			$val .= "WDN: ".$i->{string}." ";

			$sensor = "wind_dir";
			readingsUpdate($def, $sensor, $i->{current} . " " . $i->{string});
	}
	elsif ($i->{type} eq "rain") { 
			$val .= "RR: ".$i->{current}." ";

			$sensor = "rain_rate";			
			readingsUpdate($def, $sensor, $i->{current});
	}
	elsif ($i->{type} eq "train") { 
			$val .= "TR: ".$i->{current}." ";

			$sensor = "rain_total";			
			readingsUpdate($def, $sensor, $i->{current});
	}
	elsif ($i->{type} eq "flip") { 
			$val .= "F: ".$i->{current}." ";

			$sensor = "rain_flip";			
			readingsUpdate($def, $sensor, $i->{current});
	}
	elsif ($i->{type} eq "uv") { 
			$val .= "UV: ".$i->{current}." ";
			$val .= "UVR: ".$i->{risk}." ";

			$sensor = "uv_val";			
			readingsUpdate($def, $sensor, $i->{current});

			$sensor = "uv_risk";			
			readingsUpdate($def, $sensor, $i->{risk});
	}
	elsif ($i->{type} eq "weight") { 
			$val .= "W: ".$i->{current}." ";

			$sensor = "weight";			
			readingsUpdate($def, $sensor, $i->{current});
	}
	elsif ($i->{type} eq "hexline") { 
			$sensor = "hexline";			
			readingsUpdate($def, $sensor, $i->{current});
	}
	else { 
			print "\nTRX_WEATHER: Unknown: "; 
			print "Type: ".$i->{type}.", ";
			print "Value: ".$i->{current}."\n";
	}
  }

  if ("$val" ne "") {
    # remove heading and trailing space chars from $val
    $val =~ s/^\s+|\s+$//g;

    $def->{STATE} = $val;
    readingsUpdate($def, "state", $val);
  }

  readingsEndUpdate($def, 1);

  return $name;
}

1;
