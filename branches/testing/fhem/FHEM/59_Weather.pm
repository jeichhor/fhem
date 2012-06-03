#
#
# 59_Weather.pm
# written by Dr. Boris Neubert 2009-06-01
# e-mail: omega at online dot de
#
##############################################
# $Id$
package main;



use strict;
use warnings;
use Time::HiRes qw(gettimeofday);

my $UseWeatherGoogle= 0; # if you want Weather:Google back please set this to 1 and uncomment below.
#  use Weather::Google;

# taken from Daniel "Possum" LeWarne's Google::Weather module
# http://cpansearch.perl.org/src/POSSUM/Weather-Google-0.05/lib/Weather/Google.pm

# Mapping of current supported encodings
my %DEFAULT_ENCODINGS = (
    en      => 'latin1',
    da      => 'latin1',
    de      => 'latin1',
    es      => 'latin1',
    fi      => 'latin1',
    fr      => 'latin1',
    it      => 'latin1',
    ja      => 'utf-8',
    ko      => 'utf-8',
    nl      => 'latin1',
    no      => 'latin1',
    'pt-BR' => 'latin1',
    ru      => 'utf-8',
    sv      => 'latin1',
    'zh-CN' => 'utf-8',
    'zh-TW' => 'utf-8',
);

#####################################
sub Weather_Initialize($) {

  my ($hash) = @_;

# Provider
#  $hash->{Clients} = undef;

# Consumer
  $hash->{DefFn}   = "Weather_Define";
  $hash->{UndefFn} = "Weather_Undef";
  $hash->{GetFn}   = "Weather_Get";
  $hash->{AttrList}= "loglevel:0,1,2,3,4,5 event-on-update-reading event-on-change-reading";

}

###################################
sub latin1_to_utf8($) {

  # http://perldoc.perl.org/perluniintro.html, UNICODE IN OLDER PERLS
  my ($s)= @_;
  $s =~ s/([\x80-\xFF])/chr(0xC0|ord($1)>>6).chr(0x80|ord($1)&0x3F)/eg;
  return $s;
}

###################################

sub temperature_in_c {
  my ($temperature, $unitsystem)= @_;
  return $unitsystem ne "SI" ? int(($temperature-32)*5/9+0.5) : $temperature;
}

sub wind_in_km_per_h {
  my ($wind, $unitsystem)= @_;
  return $unitsystem ne "SI" ? int(1.609344*$wind+0.5) : $wind;
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
sub Weather_RetrieveDataDirectly($)
{
  my ($hash)= @_;
  my $location= $hash->{LOCATION};
  #$location =~ s/([^\w()â€™*~!.-])/sprintf '%%%02x', ord $1/eg;
  my $lang= $hash->{LANG}; 

  my $fc = undef;
  my $xml = GetHttpFile("www.google.com:80", "/ig/api?weather=" . $location . "&hl=" . $lang);
  return 0 if($xml eq "");
  foreach my $l (split("<",$xml)) {
          #Log 1, "DEBUG WEATHER: line=\"$l\"";
          next if($l eq "");                   # skip empty lines
          $l =~ s/(\/|\?)?>$//;                # strip off /> and >
          my ($tag,$value)= split(" ", $l, 2); # split tag data=..... at the first blank
          #Log 1, "DEBUG WEATHER: tag=\"$tag\" value=\"$value\"";
          $fc= 0 if($tag eq "current_conditions");
          $fc++ if($tag eq "forecast_conditions");
          next if(!defined($value) || ($value !~ /^data=/));
          my $prefix= $fc ? "fc" . $fc ."_" : "";
          my $key= $tag;
          $value=~ s/^data=\"(.*)\"$/$1/;      # extract DATA from data="DATA"
          if($DEFAULT_ENCODINGS{$lang} eq "latin1") {
            $value= latin1_to_utf8($value); # latin1 -> UTF-8
          }
          #Log 1, "DEBUG WEATHER: prefix=\"$prefix\" tag=\"$tag\" value=\"$value\"";
          Weather_UpdateReading($hash,$prefix,$key,$value);
  }
}

###################################
sub Weather_RetrieveDataViaWeatherGoogle($)
{
  my ($hash)= @_;

  # get weather information from Google weather API
  # see http://search.cpan.org/~possum/Weather-Google-0.03/lib/Weather/Google.pm

  my $location= $hash->{LOCATION};
  my $lang= $hash->{LANG};
  my $name = $hash->{NAME};
  my $WeatherObj;

  Log 4, "$name: Updating weather information for $location, language $lang.";
  eval {
        $WeatherObj= new Weather::Google($location, {language => $lang});
  };

  if($@) {
        Log 1, "$name: Could not retrieve weather information.";
        return 0;
  }

  # the current conditions contain temp_c and temp_f
  my $current = $WeatherObj->current_conditions;
  foreach my $condition ( keys ( %$current ) ) {
        my $value= $current->{$condition};
        Weather_UpdateReading($hash,"",$condition,$value);
  }

  my $fci= $WeatherObj->forecast_information;
  foreach my $i ( keys ( %$fci ) ) {
        my $reading= $i;
        my $value= $fci->{$i};
        Weather_UpdateReading($hash,"",$i,$value);
  }

  # the forecast conditions contain high and low (temperature)
  for(my $t= 0; $t<= 3; $t++) {
        my $fcc= $WeatherObj->forecast_conditions($t);
        my $prefix= sprintf("fc%d_", $t);
        foreach my $condition ( keys ( %$fcc ) ) {
                my $value= $fcc->{$condition};
                Weather_UpdateReading($hash,$prefix,$condition,$value);
        }
  }

}

###################################
sub Weather_GetUpdate($)
{
  my ($hash) = @_;

  if(!$hash->{LOCAL}) {
    InternalTimer(gettimeofday()+$hash->{INTERVAL}, "Weather_GetUpdate", $hash, 1);
  }

  
  readingsBeginUpdate($hash);

  if($UseWeatherGoogle) {
    Weather_RetrieveDataViaWeatherGoogle($hash);
  } else {
    Weather_RetrieveDataDirectly($hash);
  }

  my $temperature= $hash->{READINGS}{temperature}{VAL};
  my $humidity= $hash->{READINGS}{humidity}{VAL};
  my $wind= $hash->{READINGS}{wind}{VAL};
  my $val= "T: $temperature  H: $humidity  W: $wind";
  Log GetLogLevel($hash->{NAME},4), "Weather ". $hash->{NAME} . ": $val";
  $hash->{STATE}= $val;
  
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


#####################################
sub Weather_Define($$) {

  my ($hash, $def) = @_;

  # define <name> Weather <location> [interval]
  # define MyWeather Weather "Maintal,HE" 3600

  my @a = split("[ \t][ \t]*", $def);

  return "syntax: define <name> Weather <location> [interval [en|de|fr|es]]" 
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


sub
WeatherIconURL() {

  use constant GOOGLEURL => "http://www.google.de";

  my ($icon,$path)= @_;
  return GOOGLEURL . $icon unless(defined($path));

  # strip off path and extension
  $icon =~ s,$/ig/images/weather(.*)\.gif^,$1,;

  # day and night icons
  my $dayicon= "${icon}.png";
  my $nighticon= "${icon}_night.png";
  

}


# sub
# WeatherAsHtmlLocal()
# {
#   my ($d, $source) = @_;
#   $d = "<none>" if(!$d);
#   return "$d is not a Weather instance<br>"
#         if(!$defs{$d} || $defs{$d}{TYPE} ne "Weather");
# 
#   my $ret = "<table class='weather'>";
#   $ret .= sprintf('<tr><td colspan=2 class="weather_cityname">%s</td></tr>'."\n",
#         ReadingsVal($d, "city", ""));
# 
#   my $icon = ReadingsVal($d, "icon", "na.png");
#   $icon =~ s,/ig/images/weather(.*)\.gif,$1\.png, if ($imgHome =~ m/fhem/i);
#   ### check if _night-icon should be used. If sunrise is installed, use isday(), otherweise night from 7pm til 6am
#   my $isnight;
#   if(exists &isday) {
#                 $isnight = !isday();
#         } else {
#                 $isnight = ($hour > 18 || $hour < 7);
#   }
#   ###check if night-icon exists. If so, use it.
#   if ($isnight) {
#                 my $nighticon = $icon;
#                 $nighticon =~ s,.png,_night.png,;
#                 my $checknighticon = AttrVal("global", "modpath", "") . $imgHome . $nighticon;
#                 $checknighticon =~ s,fhem\/icons\/,FHEM\/,;
#                 Log 1, "checknighticon: $checknighticon   --- ".((-f $checknighticon ) ? "existiert" : "existiert nicht");
#                 $icon = $nighticon if(-f $checknighticon);
#   }
#   ###Print current day
# #  Log 1, "Icon0: $imgHome  $icon";
#    $ret .= sprintf('<tr><td colspan=2 class="weathericon_act"><img src="%s%s" class="weathericon_act"></tr><tr><td colspan=2 class="weather_act"><span class="weathertemp_act">%s °C</span><br><span class="weathertext_act"><a href="'."$FW_ME?detail=weblink_$d".'">Aktuell: %s</a><br>Feuchtigkeit: %s&#037<br>%s</span></td></tr>'."\n",
#         $imgHome, $icon,
#         ReadingsVal($d, "temp_c", ""),
#         ReadingsVal($d, "condition", ""),
#         ReadingsVal($d, "humidity", ""),
#         ReadingsVal($d, "wind_condition", ""));
#   ###Print 4 day forecast
#   for(my $i=1; $i<=4; $i++) {
#     my $icon = ReadingsVal($d, "fc${i}_icon", "na.png");
#         if ($imgHome =~ m/fhem/i) {
#                 $icon =~ s,/ig/images/weather(.*)\.gif,$1\.png,  ;
#         }
#     my $dayname = ReadingsVal($d, "fc${i}_day_of_week", "");
#     $dayname = "Heute" if($i==1);
#     $dayname = "Morgen" if($i==2);
# 
# #       Log 1, "Icon$i: $imgHome  $icon";
#     $ret .= sprintf('<tr><td class="weathericon"><img src="%s%s" class="weathericon"></td><td class="weathertext"><span class="weather_dayname">%s:</span><br>%s<br>Min: %s°C | Max: %s°C</td></tr>'."\n",
#         $imgHome, $icon,
#         $dayname,
#         ReadingsVal($d, "fc${i}_condition", ""),
#         ReadingsVal($d, "fc${i}_low_c", ""), ReadingsVal($d, "fc${i}_high_c", ""));
#   }
# 
#   $ret .= "</table>";
#   return $ret;
# 
# 
# }

#####################################
# This has to be modularized in the future.
sub
WeatherAsHtml($)
{
  my ($d) = @_;
  $d = "<none>" if(!$d);
  return "$d is not a Weather instance<br>"
        if(!$defs{$d} || $defs{$d}{TYPE} ne "Weather");
  my $imgHome="http://www.google.com";

  my $ret = "<table>";
  $ret .= sprintf('<tr><td><img src="%s%s"></td><td>%s<br>temp %s, hum %s, %s</td></tr>',
        $imgHome, ReadingsVal($d, "icon", ""),
        ReadingsVal($d, "condition", ""),
        ReadingsVal($d, "temp_c", ""), ReadingsVal($d, "humidity", ""),
        ReadingsVal($d, "wind_condition", ""));

  for(my $i=1; $i<=4; $i++) {
    $ret .= sprintf('<tr><td><img src="%s%s"></td><td>%s: %s<br>min %s max %s</td></tr>',
        $imgHome, ReadingsVal($d, "fc${i}_icon", ""),
        ReadingsVal($d, "fc${i}_day_of_week", ""),
        ReadingsVal($d, "fc${i}_condition", ""),
        ReadingsVal($d, "fc${i}_low_c", ""), ReadingsVal($d, "fc${i}_high_c", ""));
  }

  $ret .= "</table>";
  return $ret;
}

#####################################


1;
