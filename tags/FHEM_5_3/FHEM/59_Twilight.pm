#
# 59_Twilight.pm
# written by Sebastian Stuecker based on Twilight.tcl http://www.homematic-wiki.info/mw/index.php/TCLScript:twilight
#
##############################################

package main;
use strict;
use warnings;
use POSIX;
use HttpUtils;

sub Twilight_calc($$$$$$$);
sub Twilight_getWeatherHorizon($);
sub Twilight_GetUpdate($);
sub Twilight_dayofyear($$$);
sub Twilight_my_gmt_offset();
sub Twilight_midnight_seconds();

sub
Twilight_dayofyear($$$)
{
  my ($day1,$month,$year)=@_;
  my @cumul_d_in_m = (0,31,59,90,120,151,181,212,243,273,304,334,365);
  my $doy=$cumul_d_in_m[--$month]+$day1;
  return $doy if $month < 2;
  return $doy unless $year % 4 == 0;
  return ++$doy unless $year % 100 == 0;
  return $doy unless $year % 400 == 0;
  return ++$doy;
}

sub
Twilight_my_gmt_offset()
{
  # inspired by http://stackoverflow.com/questions/2143528/whats-the-best-way-to-get-the-utc-offset-in-perl
  # avoid use of any CPAN module and ensure system independent behavior

  my $t = time;
  my @a = localtime($t);
  my @b = gmtime($t);
  my $hh = $a[2] - $b[2];
  my $mm = $a[1] - $b[1];
  # in the unlikely event that localtime and gmtime are in different years
  if ($a[5]*366+$a[4]*31+$a[3] > $b[5]*366+$b[4]*31+$b[3]) {
    $hh += 24;
  } elsif ($a[5]*366+$a[4]*31+$a[3] < $b[5]*366+$b[4]*31+$b[3]) {
    $hh -= 24;
  }
  if ($hh < 0 && $mm > 0) {
    $hh++;
    $mm = 60-$mm;
  }
  return $hh+($mm/60);
}

##################################### 
sub
Twilight_Initialize($)
{
  my ($hash) = @_;

# Consumer
  $hash->{DefFn}   = "Twilight_Define";
  $hash->{UndefFn} = "Twilight_Undef";
  $hash->{GetFn}   = "Twilight_Get";
  $hash->{AttrList}= "loglevel:0,1,2,3,4,5 event-on-update-reading ".
                        "event-on-change-reading";
}

sub
Twilight_Get($@)
{
  my ($hash, @a) = @_;
  return "argument is missing" if(int(@a) != 2);

  $hash->{LOCAL} = 1;
  Twilight_GetUpdate($hash);
  delete $hash->{LOCAL};
  my $reading= $a[1];
  my $value;

  if(defined($hash->{READINGS}{$reading})) {
        $value= $hash->{READINGS}{$reading}{VAL};
  } else {
        return "no such reading: $reading";
  }
  return "$a[0] $reading => $value";
}


sub
Twilight_Define($$)
{
  my ($hash, $def) = @_;
  # define <name> Twilight <latitude> <longitude> [indoor_horizon [Weather_Position]]
  # define MyTwilight Twilight 48.47 11.92 Weather_Position

  my @a = split("[ \t][ \t]*", $def);

  return "syntax: define <name> Twilight <latitude> <longitude> [indoor_horizon [Weather]]"
    if(int(@a) < 4 && int(@a) > 6);

  $hash->{STATE} = "0";
  my $latitude;
  my $longitude;
  my $name      = $a[0];
  if ($a[2] =~ /^[\+-]*[0-9]*\.*[0-9]*$/ && $a[2] !~ /^[\. ]*$/ ) {
     $latitude  = $a[2];
	 if($latitude>90){$latitude=90;}
	 if($latitude<-90){$latitude=-90;}
	 }else{return "Argument Latitude is not a valid number";}
  if ($a[3] =~ /^[\+-]*[0-9]*\.*[0-9]*$/ && $a[3] !~ /^[\. ]*$/ ) {
     $longitude  = $a[3];
	 if($longitude>180){$longitude=180;}
	 if($longitude<-180){$longitude=-180;}
	 }else{return "Argument Longitude is not a valid number";}
  my $weather   = "";
  my $indoor_horizon="4";
  if(int(@a)>5) { $weather=$a[5] }
  if(int(@a)>4) { if ($a[4] =~ /^[\+-]*[0-9]*\.*[0-9]*$/ && $a[4] !~ /^[\. ]*$/ ) {
	$indoor_horizon  = $a[4];
	if($indoor_horizon>20){ $indoor_horizon=20;}
	if($indoor_horizon<0){$indoor_horizon=0;}
  }else{return "Argument Indoor_Horizon is not a valid number";} }
   
  $hash->{LATITUDE}     = $latitude;
  $hash->{LONGITUDE}    = $longitude;
  $hash->{WEATHER}      = $weather;
  $hash->{INDOOR_HORIZON} = $indoor_horizon;
 
  Twilight_GetUpdate($hash);
  return undef;
}

sub
Twilight_Undef($$)
{
  my ($hash, $arg) = @_;

  RemoveInternalTimer($hash);
  return undef;
}


sub 
Twilight_midnight_seconds()
{
  my @time = localtime();
  my $secs = ($time[2] * 3600) + ($time[1] * 60) + $time[0];
  return $secs;
}


sub
Twilight_GetUpdate($)
{
  my ($hash) = @_; 
  my @sunrise_set;   
  
  readingsBeginUpdate($hash);
  my $latitude   = $hash->{LATITUDE};
  my $longitude  = $hash->{LONGITUDE};
  my $horizon    = $hash->{HORIZON};
  my $now        = time();
  my $midnight   = Twilight_midnight_seconds();
  my $midseconds = $now-$midnight;
  my $year  = strftime("%Y",localtime);
  my $month = strftime("%m",localtime);
  my $day   = strftime("%d",localtime);
  my $doy   = Twilight_dayofyear($day,$month,$year)+(($year%4)/4);
  $doy+=($doy/365.0)/4.0;
  my $timezone=Twilight_my_gmt_offset();
  my $timediff=-0.171*sin(0.0337*$doy+0.465) -
                0.1299*sin(0.01787 * $doy - 0.168);
  my $declination=0.4095*sin(0.016906*($doy-80.086));
  my $twilight_midnight=$now+(0-$timediff-$longitude/15+$timezone)*3600;
  my $yesterday_offset;
  if($now<$twilight_midnight){
     $yesterday_offset=86400;
  }else{
     $yesterday_offset=0; 
  }
  
  Twilight_getWeatherHorizon($hash);
  readingsUpdate($hash,"condition",$hash->{CONDITION});
  if($hash->{WEATHER_HORIZON} > (89-$hash->{LATITUDE}+$declination) ){
    $hash->{WEATHER_HORIZON} = 89-$hash->{LATITUDE}+$declination;
  }

  my @names = ("_astro:-18", "_naut:-12", "_civil:-6",
               ":0", "_indoor:0", "_weather:0");
  for(my $cnt = 0; $cnt < 6; $cnt++) {
    my ($name, $deg) = split(":", $names[$cnt]);
    $sunrise_set[$cnt]{SR_NAME} = "sr$name";
    $sunrise_set[$cnt]{SS_NAME} = "ss$name";
    $sunrise_set[$cnt]{DEGREE}  = $deg;
  }
  $sunrise_set[4]{DEGREE}=$hash->{INDOOR_HORIZON};
  $sunrise_set[5]{DEGREE}=$hash->{WEATHER_HORIZON};
  
  for(my $i=0; $i<6; $i++) {
    ($sunrise_set[$i]{RISE}, $sunrise_set[$i]{SET})=
       Twilight_calc($latitude, $longitude, $sunrise_set[$i]{DEGREE},
                     $declination, $timezone, $midseconds, $timediff);
    readingsUpdate($hash, $sunrise_set[$i]{SR_NAME},
        $sunrise_set[$i]{RISE} eq "nan" ? "undefined" : 
        strftime("%H:%M:%S",localtime($sunrise_set[$i]{RISE})));
    readingsUpdate($hash, $sunrise_set[$i]{SS_NAME},
        $sunrise_set[$i]{SET} eq "nan" ? "undefined" : 
        strftime("%H:%M:%S",localtime($sunrise_set[$i]{SET})));
  }
  my $k=0;
  my $half="RISE"; 
  my $sname="SR_NAME"; 
  my $alarmOffset;

  for(my $i=0; $i < 12; $i++) {
    my $nexttime=$sunrise_set[6-abs($i-6)-$k]{$half};
    if($nexttime ne "nan" && $nexttime > $now) {
      readingsUpdate($hash, "light", 6-abs($i-6));
      readingsUpdate($hash, "nextEvent",
                            $sunrise_set[6-abs($i-6)-$k]{$sname});
      readingsUpdate($hash, "nextEventTime",
                            strftime("%H:%M:%S",localtime($nexttime)));

      if($i==5 || $i==6) { # Weather
        $alarmOffset = ($nexttime-$now)/2;
        $alarmOffset = 120 if($alarmOffset<120);
        $alarmOffset = 900 if($alarmOffset>900);

      } else {
        $alarmOffset = $nexttime-$now+10;

      }

      $hash->{STATE}=$i;
      last;
    }

    if($i == 5){ # Afternoon/evening
      $k=1;
      $half="SET";
      $sname="SS_NAME";
    }
  }

  if(!$alarmOffset) {
    $alarmOffset = 900;
    readingsUpdate($hash,"light", 0);
    $hash->{STATE}=0;
  }
  if(!$hash->{LOCAL}) {
    InternalTimer($now+$alarmOffset, "Twilight_GetUpdate", $hash, 0);
    readingsUpdate($hash,"nextUpdate",
                   strftime("%H:%M:%S",localtime($now+$alarmOffset)));
  }
  
  readingsEndUpdate($hash, defined($hash->{LOCAL} ? 0 : 1)); 
  return 1;
}

sub
Twilight_calc($$$$$$$)
{
  my ($latitude, $longitude, $horizon, $declination,
      $timezone, $midseconds, $timediff) = @_;
  my $suntime=0;
  my $sunrise=0;
  my $sunset=0;
  eval {
    $suntime = 12*acos((sin($horizon/57.29578) -
                        sin($latitude/57.29578) * sin($declination)) /
                       (cos($latitude/57.29578)*cos($declination))) /
                  3.141592 ;
    $sunrise = $midseconds +
               (12-$timediff -$suntime -$longitude/15+$timezone) *
               3600;
    $sunset  = $midseconds +
               (12-$timediff +$suntime -$longitude/15+$timezone) *
               3600;
  };
  $sunrise = $sunset = "nan" if($@);
  return $sunrise, $sunset;
}

sub
Twilight_getWeatherHorizon($)
{
  my $hash=shift;
  my @a_current = (25,25,25,25,20,10,10,10,10,10,10, 7,
                    7, 7, 5,10,10, 6, 6, 6,10, 6 ,6, 6,
                    6, 6, 6, 5, 5, 3, 3, 0, 0, 0, 0, 7,
                    0,15,15,15, 9,15, 8, 5,12, 6, 8, 8);
  # condition codes are described in FHEM wiki and in the documentation of the
  # yahoo weather API
  my $location=$hash->{WEATHER};
  my $xml = GetFileFromURL("http://weather.yahooapis.com/forecastrss?w=".
                            $location."&u=c",4.0);
  my $current;
  if($xml=~/code="(.*)"(\ *)temp/){
    if(defined($1)){
      $current=$1;
    }else{
      $current=-1;
   }
   if(($current>=0) && ($current <=47)) {
     $hash->{WEATHER_HORIZON}=$a_current[$current]+$hash->{INDOOR_HORIZON};
     $hash->{CONDITION}=$current;
     return 1;
   }
  }
  Log 1, "[TWILIGHT] No Weather location found at yahoo weather ".
        "for location ID: $location";
  $hash->{WEATHER_HORIZON}="0";
  $hash->{CONDITION}="-1";
}
1;

