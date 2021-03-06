#
#
# 59_Weather.pm
# maintainer: Dr. Boris Neubert 2009-06-01
# e-mail: omega at online dot de
# Port to Yahoo by Erwin Menschhorn 2012-08-30
# e-mail emenschhorn at gmail dot com
#
##############################################
# $Id$
package main;

use strict;
use warnings;
use Time::HiRes qw(gettimeofday);

#
# uses the Yahoo! Weather API: http://developer.yahoo.com/weather/
#


# Mapping / translation of current weather codes 0-47
my @YahooCodes_en = (
       'tornado', 'tropical storm', 'hurricane', 'severe thunderstorms', 'thunderstorms', 'mixed rain and snow',
       'mixed rain and sleet', 'mixed snow and sleet', 'freezing drizzle', 'drizzle', 'freezing rain' ,'showers',
       'showers', 'snow flurries', 'light snow showers', 'blowing snow', 'snow', 'hail',
       'sleet', 'dust', 'foggy', 'haze', 'smoky', 'blustery',
       'windy', 'cold', 'cloudy',
       'mostly cloudy', # night
       'mostly cloudy', # day
       'partly cloudy', # night
       'partly cloudy', # day
       'clear', #night
       'sunny',
       'fair', #night
       'fair', #day
       'mixed rain and hail',
       'hot', 'isolated thunderstorms', 'scattered thunderstorms', 'scattered thunderstorms', 'scattered showers', 'heavy snow',
       'scattered snow showers', 'heavy snow', 'partly cloudy', 'thundershowers', 'snow showers', 'isolated thundershowers');

my @YahooCodes_de = (
       'Tornado', 'schwerer Sturm', 'Sturm', 'schwere Gewitter', 'Gewitter', 'Regen und Schnee',
       'Regen und Graupel', 'Schnee und Graupel', 'Eisregen', 'Nieselregen', 'gefrierender Regen' ,'Schauer',
       'Schauer', 'Schneetreiben', 'leichter Schneeschauer', 'Schneeverwehungen', 'Schnee', 'Hagel',
       'Graupel', 'Staub', 'Nebel', 'Dunst', 'Smog', 'Sturm',
       'windig', 'kalt', 'wolkig',
       'überwiegend wolkig', # night
       'überwiegend wolkig', # day
       'teilweise wolkig', # night
       'teilweise wolkig', # day
       'klar', # night
       'sonnig',
       'bewölkt', # night
       'bewölkt', # day
       'Regen und Hagel',
       'heiß', 'einzelne Gewitter', 'vereinzelt Gewitter', 'vereinzelt Gewitter', 'vereinzelt Schauer', 'starker Schneefall',
       'vereinzelt Schneeschauer', 'starker Schneefall', 'teilweise wolkig', 'Gewitterregen', 'Schneeschauer', 'vereinzelt Gewitter');

my @YahooCodes_nl = (
       'tornado', 'zware storm', 'orkaan', 'hevig onweer', 'onweer',
       'regen en sneeuw',
       'regen en ijzel', 'sneeuw en ijzel', 'aanvriezende motregen',
       'motregen', 'aanvriezende regen' ,'regenbuien',
       'buien', 'sneeuw windstoten', 'lichte sneeuwbuien',
       'stuifsneeuw', 'sneeuw', 'hagel',
       'ijzel', 'stof', 'mist', 'waas', 'smog', 'heftig',
       'winderig', 'koud', 'bewolkt',
       'overwegend bewolkt', # night
       'overwegend bewolkt', # day
       'gedeeltelijk bewolkt', # night
       'gedeeltelijk bewolkt', # day
       'helder', #night
       'zonnig',
       'bewolkt', #night
       'bewolkt', #day
       'regen en hagel',
       'heet', 'plaatselijk onweer', 'af en toe onweer', 'af en toe onweer', 'af en toe regenbuien', 'hevige sneeuwval',
       'af en toe sneeuwbuien', 'hevige sneeuwval', 'deels bewolkt',
       'onweersbuien', 'sneeuwbuien', 'af en toe onweersbuien');


my %pressure_trend_txt_en = ( 0 => "steady", 1 => "rising", 2 => "falling" );
my %pressure_trend_txt_de = ( 0 => "gleichbleibend", 1 => "steigend", 2 => "fallend" );
my %pressure_trend_txt_nl = ( 0 => "stabiel", 1 => "stijgend", 2 => "dalend" );
my %pressure_trend_sym = ( 0 => "=", 1 => "+", 2 => "-" );


my @directions_txt_en = ('N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', 'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW');
my @directions_txt_de = ('N', 'NNO', 'NO', 'ONO', 'O', 'OSO', 'SO', 'SSO', 'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW');
my @directions_txt_nl = ('N', 'NNO', 'NO', 'ONO', 'O', 'OZO', 'ZO', 'ZZO', 'Z', 'ZZW', 'ZW', 'WZW', 'W', 'WNW', 'NW', 'NNW');

my %wdays_txt_en = ('Mon' => 'Mon', 'Tue' => 'Tue', 'Wed'=> 'Wed', 'Thu' => 'Thu', 'Fri' => 'Fri', 'Sat' => 'Sat', 'Sun' => 'Sun');
my %wdays_txt_de = ('Mon' => 'Mo', 'Tue' => 'Di', 'Wed'=> 'Mi', 'Thu' => 'Do', 'Fri' => 'Fr', 'Sat' => 'Sa', 'Sun' => 'So');
my %wdays_txt_nl = ('Mon' => 'Maa', 'Tue' => 'Din', 'Wed'=> 'Woe', 'Thu' => 'Don', 'Fri' => 'Vri', 'Sat' => 'Zat', 'Sun' => 'Zon');

my @iconlist = (
       'storm', 'storm', 'storm', 'thunderstorm', 'thunderstorm', 'rainsnow',
       'sleet', 'snow', 'drizzle', 'drizzle', 'icy' ,'chance_of_rain',
       'chance_of_rain', 'snowflurries', 'chance_of_snow', 'heavysnow', 'snow', 'heavyrain',
       'sleet', 'dust', 'fog', 'haze', 'smoke', 'flurries',
       'windy', 'icy', 'cloudy', 'mostlycloudy_night', 'mostlycloudy', 'partly_cloudy_night',
       'partly_cloudy', 'clear', 'sunny', 'mostly_clear_night', 'overcast', 'heavyrain',
       'clear', 'scatteredthunderstorms', 'scatteredthunderstorms', 'scatteredthunderstorms', 'scatteredshowers', 'heavysnow',
       'chance_of_snow', 'heavysnow', 'partly_cloudy', 'heavyrain', 'chance_of_snow', 'scatteredshowers');

#####################################
sub Weather_Initialize($) {

  my ($hash) = @_;

  $hash->{DefFn}   = "Weather_Define";
  $hash->{UndefFn} = "Weather_Undef";
  $hash->{GetFn}   = "Weather_Get";
  $hash->{SetFn}   = "Weather_Set";
  $hash->{AttrList}= "loglevel:0,1,2,3,4,5 localicons event-on-update-reading event-on-change-reading";

}

###################################
sub latin1_to_utf8($) {

  # http://perldoc.perl.org/perluniintro.html, UNICODE IN OLDER PERLS
  my ($s)= @_;
  $s =~ s/([\x80-\xFF])/chr(0xC0|ord($1)>>6).chr(0x80|ord($1)&0x3F)/eg;
  return $s;
}

###################################

sub temperature_in_c($$) {
  my ($temperature, $unitsystem)= @_;
  return $unitsystem ne "SI" ? int(($temperature-32)*5/9+0.5) : $temperature;
}

sub wind_in_km_per_h($$) {
  my ($wind, $unitsystem)= @_;
  return $unitsystem ne "SI" ? int(1.609344*$wind+0.5) : $wind;
}

sub degrees_to_direction($@) {
   my ($degrees,@directions_txt_i18n) = @_;
   my $mod = int((($degrees + 11.25) % 360) / 22.5);
   return $directions_txt_i18n[$mod];
}

###################################
sub Weather_UpdateReading($$$$) {

  my ($hash,$prefix,$key,$value)= @_;

  #Log 1, "DEBUG WEATHER: $prefix $key $value";

  my $unitsystem= $hash->{READINGS}{unit_system}{VAL};
  
  if($key eq "low") {
        $key= "low_c";
        $value= temperature_in_c($value,$unitsystem);
  } elsif($key eq "high") {
        $key= "high_c";
        $value= temperature_in_c($value,$unitsystem);
  } elsif($key eq "humidity") {
        # standardize reading - allow generic logging of humidity.
        $value=~ s/.*?(\d+).*/$1/; # extract numeric
  }

  my $reading= $prefix . $key;

  readingsUpdate($hash,$reading,$value);
  if($reading eq "temp_c") {
    readingsUpdate($hash,"temperature",$value); # additional entry for compatibility
  }
  if($reading eq "wind_condition") {
    $value=~ s/.*?(\d+).*/$1/; # extract numeric
    readingsUpdate($hash,"wind",wind_in_km_per_h($value,$unitsystem)); # additional entry for compatibility
  }

  return 1;
}


################################### 
sub Weather_RetrieveData($)
{
  my ($hash)= @_;
  
  my $location= $hash->{LOCATION}; # WOEID [WHERE-ON-EARTH-ID], go to http://weather.yahoo.com to find out
  my $units= $hash->{UNITS}; 

  my $fc = undef;
  my $xml = GetFileFromURL("http://weather.yahooapis.com/forecastrss?w=" . $location . "&u=" . $units, 3, undef, 1);
  return 0 if( ! defined $xml || $xml eq "");

  my $lang= $hash->{LANG};
  my @YahooCodes_i18n;
  my %wdays_txt_i18n;
  my @directions_txt_i18n;
  my %pressure_trend_txt_i18n;

  if($lang eq "de") {
    @YahooCodes_i18n= @YahooCodes_de;
    %wdays_txt_i18n= %wdays_txt_de;
    @directions_txt_i18n= @directions_txt_de;
    %pressure_trend_txt_i18n= %pressure_trend_txt_de;
  } elsif($lang eq "nl") {
    @YahooCodes_i18n= @YahooCodes_nl;
    %wdays_txt_i18n= %wdays_txt_nl;
    @directions_txt_i18n= @directions_txt_nl;
    %pressure_trend_txt_i18n= %pressure_trend_txt_nl;
  } else {
    @YahooCodes_i18n= @YahooCodes_en;
    %wdays_txt_i18n= %wdays_txt_en;
    @directions_txt_i18n= @directions_txt_en;
    %pressure_trend_txt_i18n= %pressure_trend_txt_en;
  }


  foreach my $l (split("<",$xml)) {
          #Log 1, "DEBUG WEATHER: line=\"$l\"";
          next if($l eq "");                   # skip empty lines
          $l =~ s/(\/|\?)?>$//;                # strip off /> and >
          my ($tag,$value)= split(" ", $l, 2); # split tag data=..... at the first blank
          next if(!defined($tag) || ($tag !~ /^yweather:/));
          $fc= 0 if($tag eq "yweather:condition");
          $fc++ if($tag eq "yweather:forecast");
          my $prefix= $fc ? "fc" . $fc ."_" : "";
  
          ### location
          if ($tag eq "yweather:location" ) {
            $value =~/city="(.*?)" .*country="(.*?)".*/;
            my $loc = "";
            $loc = $1 if (defined($1)); 
            $loc .= ", $2" if (defined($2)); 
            readingsUpdate($hash, "city", $loc);
          }
        
          ### current condition and forecast
          if (($tag eq "yweather:condition" ) || ($tag eq "yweather:forecast" )) {
             my $code = (($value =~/code="([0-9]*?)".*/) ? $1 : undef);
             if (defined($code)) { 
               readingsUpdate($hash, $prefix . "code", $code); 
               my $text = $YahooCodes_i18n[$code];
               if ($text) { readingsUpdate($hash, $prefix . "condition", $text); } 
               #### add icon logic here - generate from code
               $text = $iconlist[$code];
               readingsUpdate($hash, $prefix . "icon", $text) if ($text); 
             }  
          }

          ### current condition 
          if ($tag eq "yweather:condition" ) {
             my $temp = (($value =~/temp="([0-9.]*?)".*/) ? $1 : undef);
             if ($temp) { 
                readingsUpdate($hash, "temperature", $temp); 
                readingsUpdate($hash, "temp_c", $temp); # compatibility
                $temp = int(( $temp * 9  / 5 ) + 32.5);  # Celsius to Fahrenheit
                readingsUpdate($hash, "temp_f", $temp); # compatibility
             }  

             my $datum = (($value =~/date=".*? ([0-9].*)".*/) ? $1 : undef);  
             readingsUpdate($hash, "current_date_time", $datum) if (defined($1)); 

             my $day = (($value =~/date="(.*?), .*/) ? $1 : undef);  
             if ($day) {  
                readingsUpdate($hash, "day_of_week", $wdays_txt_i18n{$day}); 
             }          
          }

          ### forecast 
          if ($tag eq "yweather:forecast" ) {
             my $low_c = (($value =~/low="([0-9.]*?)".*/) ? $1 : undef);
             if ($low_c) { readingsUpdate($hash, $prefix . "low_c", $low_c); }  
             my $high_c = (($value =~/high="([0-9.]*?)".*/) ? $1 : undef);
             if ($high_c) { readingsUpdate($hash, $prefix . "high_c", $high_c); }  
             my $day1 = (($value =~/day="(.*?)" .*/) ? $1 : undef); # forecast
             if ($day1) { 
                readingsUpdate($hash, $prefix . "day_of_week", $wdays_txt_i18n{$day1}); 
             }   
          }

          ### humidiy / Pressure
          if ($tag eq "yweather:atmosphere" ) {
            $value =~/humidity="([0-9.]*?)" .*visibility="([0-9.]*?|\s*?)" .*pressure="([0-9.]*?)"  .*rising="([0-9.]*?)" .*/;

            if ($1) { readingsUpdate($hash, "humidity", $1); }
            my $vis = (($2 eq "") ? " " : int($2+0.5));   # clear visibility field
            readingsUpdate($hash, "visibility", $vis);
            if ($3) { readingsUpdate($hash, "pressure", int($3+0.5)); } 
            if ($4) {
              readingsUpdate($hash, "pressure_trend", $4);
              readingsUpdate($hash, "pressure_trend_txt", $pressure_trend_txt_i18n{$4});
              readingsUpdate($hash, "pressure_trend_sym", $pressure_trend_sym{$4});
            }
          }

          ### wind
          if ($tag eq "yweather:wind" ) {
            $value =~/chill="([0-9.]*?)" .*direction="([0-9.]*?)" .*speed="([0-9.]*?)" .*/;
            readingsUpdate($hash, "wind_chill", $1) if (defined($1)); 
            readingsUpdate($hash, "wind_direction", $2) if (defined($2));
            my $windspeed= defined($3) ? int($3+0.5) : "";
            readingsUpdate($hash, "wind_speed", $windspeed);
            readingsUpdate($hash, "wind", $windspeed); # duplicate for compatibility
            if (defined($2) & defined($3)) {
              my $wdir = degrees_to_direction($2,@directions_txt_i18n);
              readingsUpdate($hash, "wind_condition", "Wind: $wdir $windspeed km/h"); # compatibility
            }
          }   
  }
}  #end sub



###################################
sub Weather_GetUpdate($)
{
  my ($hash) = @_;

  if(!$hash->{LOCAL}) {
    InternalTimer(gettimeofday()+$hash->{INTERVAL}, "Weather_GetUpdate", $hash, 1);
  }

  readingsBeginUpdate($hash);

  Weather_RetrieveData($hash);

  my $temperature= $hash->{READINGS}{temperature}{VAL};
  my $humidity= $hash->{READINGS}{humidity}{VAL};
  my $wind= $hash->{READINGS}{wind}{VAL};
  my $val= "T: $temperature  H: $humidity  W: $wind";
  Log GetLogLevel($hash->{NAME},4), "Weather ". $hash->{NAME} . ": $val";
  $hash->{STATE}= $val;
  addEvent($hash, $val);
  readingsEndUpdate($hash, defined($hash->{LOCAL} ? 0 : 1)); # DoTrigger, because sub is called by a timer instead of dispatch
      
  return 1;
}

# Perl Special: { $defs{Weather}{READINGS}{condition}{VAL} }
# conditions: Mostly Cloudy, Overcast, Clear, Chance of Rain

###################################
sub Weather_Get($@) {

  my ($hash, @a) = @_;

  return "argument is missing" if(int(@a) != 2);

  $hash->{LOCAL} = 1;
  Weather_GetUpdate($hash);
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

###################################

sub Weather_Set($@) {
  my ($hash, @a) = @_;

  my $cmd= $a[1];

  # usage check
  if((@a == 2) && ($a[1] eq "update")) {
    RemoveInternalTimer($hash);
    Weather_GetUpdate($hash);
    return undef;
  } else {
    return "Unknown argument $cmd, choose one of update";
  }
}


#####################################
sub Weather_Define($$) {

  my ($hash, $def) = @_;

  # define <name> Weather <location> [interval]
  # define MyWeather Weather "Maintal,HE" 3600

  my @a = split("[ \t][ \t]*", $def);

  return "syntax: define <name> Weather <location> [interval [en|de|nl]]"
    if(int(@a) < 3 && int(@a) > 5); 

  $hash->{STATE} = "Initialized";
  $hash->{fhem}{interfaces}= "temperature;humidity;wind";

  my $name      = $a[0];
  my $location  = $a[2];
  my $interval  = 3600;
  my $lang      = "en"; 
  if(int(@a)>=4) { $interval= $a[3]; }
  if(int(@a)==5) { $lang= $a[4]; } 

  $hash->{LOCATION}     = $location;
  $hash->{INTERVAL}     = $interval;
  $hash->{LANG}         = $lang;
  $hash->{UNITS}        = "c"; # hardcoded to use degrees centigrade (Celsius)
  $hash->{READINGS}{current_date_time}{TIME}= TimeNow();
  $hash->{READINGS}{current_date_time}{VAL}= "none";

  $hash->{LOCAL} = 1;
  Weather_GetUpdate($hash);
  delete $hash->{LOCAL};

  InternalTimer(gettimeofday()+$hash->{INTERVAL}, "Weather_GetUpdate", $hash, 0);

  return undef;
}

#####################################
sub Weather_Undef($$) {

  my ($hash, $arg) = @_;

  RemoveInternalTimer($hash);
  return undef;
}

#####################################

# Icon Parameter

use constant ICONHIGHT => 120;
use constant ICONWIDTH => 175;
use constant ICONSCALE => 0.5;

#####################################

sub
WeatherIconIMGTag($) {

  my $width= int(ICONSCALE*ICONWIDTH);
  my ($icon)= @_;
  my $url= FW_IconURL("weather/$icon");
  my $style= " width=$width";
  return "<img src=\"$url\"$style alt=\"$icon\">";
  
}

#####################################
sub
WeatherAsHtml($)
{

  my ($d) = @_;
  $d = "<none>" if(!$d);
  return "$d is not a Weather instance<br>"
        if(!$defs{$d} || $defs{$d}{TYPE} ne "Weather");

  my $width= int(ICONSCALE*ICONWIDTH);
      
  my $ret = sprintf("<table><tr><th width=%d></th><th></th></tr>", $width);
  $ret .= sprintf('<tr><td width=%d>%s</td><td>%s<br>%s°C  %s%%<br>%s</td></tr>',
        $width,
        WeatherIconIMGTag(ReadingsVal($d, "icon", "")),
        ReadingsVal($d, "condition", ""),
        ReadingsVal($d, "temp_c", ""), ReadingsVal($d, "humidity", ""),
        ReadingsVal($d, "wind_condition", ""));

  for(my $i=1; $i<=2; $i++) {
    #  Yahoo provides only 2 days.
    #next if (ReadingsVal($d, "fc${i}_code", "") eq ""); # MH skip non existent entries

    $ret .= sprintf('<tr><td width=%d>%s</td><td>%s: %s<br>min %s°C max %s°C</td></tr>',
        $width,
        WeatherIconIMGTag(ReadingsVal($d, "fc${i}_icon", "")),
        ReadingsVal($d, "fc${i}_day_of_week", ""),
        ReadingsVal($d, "fc${i}_condition", ""),
        ReadingsVal($d, "fc${i}_low_c", ""), ReadingsVal($d, "fc${i}_high_c", ""));
  }

  $ret .= "</table>";
  return $ret;
}

#####################################


1;
