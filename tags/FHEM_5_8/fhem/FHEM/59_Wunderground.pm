# $Id$
##############################################################################
#
#     59_Wunderground.pm
#
#     Copyright by Julian Pawlowski
#     e-mail: julian.pawlowski at gmail.com
#
#     This file is part of fhem.
#
#     Fhem is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 2 of the License, or
#     (at your option) any later version.
#
#     Fhem is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#
#     You should have received a copy of the GNU General Public License
#     along with fhem.  If not, see <http://www.gnu.org/licenses/>.
#
##############################################################################

# http://api.wunderground.com/weather/api

package main;

use strict;
use warnings;
use vars qw(%data);
use HttpUtils;
use utf8;
use Encode qw(encode_utf8 decode_utf8);
use Unit;
use Data::Dumper;

sub Wunderground_Hash2Readings($$;$);

###################################
sub Wunderground_Initialize($) {
    my ($hash) = @_;

    Log3 $hash, 5, "Wunderground_Initialize: Entering";

    my $webhookFWinstance =
      join( ",", devspec2array('TYPE=FHEMWEB:FILTER=TEMPORARY!=1') );

    $hash->{SetFn}         = "Wunderground_Set";
    $hash->{DefFn}         = "Wunderground_Define";
    $hash->{AttrFn}        = "Wunderground_Attr";
    $hash->{UndefFn}       = "Wunderground_Undefine";
    $hash->{DbLog_splitFn} = "Unit_DbLog_split";
    $hash->{parseParams}   = 1;

    $hash->{AttrList} =
"disable:0,1 timeout:1,2,3,4,5 pollInterval:300,450,600,750,900 wu_lang:en,de,at,ch,nl,fr,pl wu_pws:1,0 wu_bestfct:1,0 stateReadings stateReadingsFormat:0,1 "
      . "wu_features:multiple-strict,alerts,almanac,astronomy,conditions,currenthurricane,forecast,forecast10day,hourly,hourly10day "
      . $readingFnAttributes;

    $hash->{readingsDesc} = {
        'UV'         => { rtype => 'uvi' },
        'dewpoint'   => { rtype => 'c', formula_symbol => 'Td', },
        'dewpoint_f' => { rtype => 'f', formula_symbol => 'Td', },
        'fc0_high_c' =>
          { rtype => 'c', format => '%i', formula_symbol => 'Th', },
        'fc0_high_f' =>
          { rtype => 'f', format => '%i', formula_symbol => 'Th', },
        'fc0_humidity'       => { rtype => 'pct', formula_symbol => 'H' },
        'fc0_humidity_max'   => { rtype => 'pct', formula_symbol => 'H' },
        'fc0_humidity_min'   => { rtype => 'pct', formula_symbol => 'H' },
        'fc0_icon_url'       => { rtype => 'url_http' },
        'fc0_icon_url_night' => { rtype => 'url_http' },
        'fc0_low_c' =>
          { rtype => 'c', format => '%i', formula_symbol => 'Tl', },
        'fc0_low_f' =>
          { rtype => 'f', format => '%i', formula_symbol => 'Tl', },
        'fc0_rain_day'           => { rtype => 'mm' },
        'fc0_rain_day_in'        => { rtype => 'in' },
        'fc0_rain_night'         => { rtype => 'mm' },
        'fc0_rain_night_in'      => { rtype => 'in' },
        'fc0_snow_day'           => { rtype => 'cm' },
        'fc0_snow_day_in'        => { rtype => 'in' },
        'fc0_snow_night'         => { rtype => 'cm' },
        'fc0_snow_night_in'      => { rtype => 'in' },
        'fc0_title'              => { rtype => 'weekday', showLong => 1 },
        'fc0_title_night'        => { rtype => 'weekday_night', showLong => 1 },
        'fc0_wind_direction'     => { rtype => 'compasspoint' },
        'fc0_wind_direction_max' => { rtype => 'compasspoint' },
        'fc0_wind_speed'         => { rtype => 'kmph', formula_symbol => 'Ws' },
        'fc0_wind_speed_max'     => { rtype => 'kmph', formula_symbol => 'Ws' },
        'fc0_wind_speed_max_mph' => { rtype => 'mph', formula_symbol => 'Ws' },
        'fc0_wind_speed_mph'     => { rtype => 'mph', formula_symbol => 'Ws' },
        'fc1_high_c' =>
          { rtype => 'c', format => '%i', formula_symbol => 'Th', },
        'fc1_high_f' =>
          { rtype => 'f', format => '%i', formula_symbol => 'Th', },
        'fc1_humidity'       => { rtype => 'pct', formula_symbol => 'H' },
        'fc1_humidity_max'   => { rtype => 'pct', formula_symbol => 'H' },
        'fc1_humidity_min'   => { rtype => 'pct', formula_symbol => 'H' },
        'fc1_icon_url'       => { rtype => 'url_http' },
        'fc1_icon_url_night' => { rtype => 'url_http' },
        'fc1_low_c' =>
          { rtype => 'c', format => '%i', formula_symbol => 'Tl', },
        'fc1_low_f' =>
          { rtype => 'f', format => '%i', formula_symbol => 'Tl', },
        'fc1_rain_day'           => { rtype => 'mm' },
        'fc1_rain_day_in'        => { rtype => 'in' },
        'fc1_rain_night'         => { rtype => 'mm' },
        'fc1_rain_night_in'      => { rtype => 'in' },
        'fc1_snow_day'           => { rtype => 'cm' },
        'fc1_snow_day_in'        => { rtype => 'in' },
        'fc1_snow_night'         => { rtype => 'cm' },
        'fc1_snow_night_in'      => { rtype => 'in' },
        'fc1_title'              => { rtype => 'weekday', showLong => 1 },
        'fc1_title_night'        => { rtype => 'weekday_night', showLong => 1 },
        'fc1_wind_direction'     => { rtype => 'compasspoint' },
        'fc1_wind_direction_max' => { rtype => 'compasspoint' },
        'fc1_wind_speed'         => { rtype => 'kmph', formula_symbol => 'Ws' },
        'fc1_wind_speed_max'     => { rtype => 'kmph', formula_symbol => 'Ws' },
        'fc1_wind_speed_max_mph' => { rtype => 'mph', formula_symbol => 'Ws' },
        'fc1_wind_speed_mph'     => { rtype => 'mph', formula_symbol => 'Ws' },
        'fc2_high_c' =>
          { rtype => 'c', format => '%i', formula_symbol => 'Th', },
        'fc2_high_f' =>
          { rtype => 'f', format => '%i', formula_symbol => 'Th', },
        'fc2_humidity'       => { rtype => 'pct', formula_symbol => 'H' },
        'fc2_humidity_max'   => { rtype => 'pct', formula_symbol => 'H' },
        'fc2_humidity_min'   => { rtype => 'pct', formula_symbol => 'H' },
        'fc2_icon_url'       => { rtype => 'url_http' },
        'fc2_icon_url_night' => { rtype => 'url_http' },
        'fc2_low_c' =>
          { rtype => 'c', format => '%i', formula_symbol => 'Tl', },
        'fc2_low_f' =>
          { rtype => 'f', format => '%i', formula_symbol => 'Tl', },
        'fc2_rain_day'       => { rtype => 'mm' },
        'fc2_rain_day_in'    => { rtype => 'in' },
        'fc2_rain_night'     => { rtype => 'mm' },
        'fc2_rain_night_in'  => { rtype => 'in' },
        'fc2_snow_day'       => { rtype => 'cm' },
        'fc2_snow_day_in'    => { rtype => 'in' },
        'fc2_snow_night'     => { rtype => 'cm' },
        'fc2_snow_night_in'  => { rtype => 'in' },
        'fc2_title'          => { rtype => 'weekday', showLong => 1 },
        'fc2_title_night'    => { rtype => 'weekday_night', showLong => 1, },
        'fc2_wind_direction' => { rtype => 'compasspoint' },
        'fc2_wind_direction_max' => { rtype => 'compasspoint' },
        'fc2_wind_speed'         => { rtype => 'kmph', formula_symbol => 'Ws' },
        'fc2_wind_speed_max'     => { rtype => 'kmph', formula_symbol => 'Ws' },
        'fc2_wind_speed_max_mph' => { rtype => 'mph', formula_symbol => 'Ws' },
        'fc2_wind_speed_mph'     => { rtype => 'mph', formula_symbol => 'Ws' },
        'fc3_high_c' =>
          { rtype => 'c', format => '%i', formula_symbol => 'Th', },
        'fc3_high_f' =>
          { rtype => 'f', format => '%i', formula_symbol => 'Th', },
        'fc3_humidity'       => { rtype => 'pct', formula_symbol => 'H' },
        'fc3_humidity_max'   => { rtype => 'pct', formula_symbol => 'H' },
        'fc3_humidity_min'   => { rtype => 'pct', formula_symbol => 'H' },
        'fc3_icon_url'       => { rtype => 'url_http' },
        'fc3_icon_url_night' => { rtype => 'url_http' },
        'fc3_low_c' =>
          { rtype => 'c', format => '%i', formula_symbol => 'Tl', },
        'fc3_low_f' =>
          { rtype => 'f', format => '%i', formula_symbol => 'Tl', },
        'fc3_rain_day'           => { rtype => 'mm' },
        'fc3_rain_day_in'        => { rtype => 'in' },
        'fc3_rain_night'         => { rtype => 'mm' },
        'fc3_rain_night_in'      => { rtype => 'in' },
        'fc3_snow_day'           => { rtype => 'cm' },
        'fc3_snow_day_in'        => { rtype => 'in' },
        'fc3_snow_night'         => { rtype => 'cm' },
        'fc3_snow_night_in'      => { rtype => 'in' },
        'fc3_title'              => { rtype => 'weekday', showLong => 1 },
        'fc3_title_night'        => { rtype => 'weekday_night', showLong => 1 },
        'fc3_wind_direction'     => { rtype => 'compasspoint' },
        'fc3_wind_direction_max' => { rtype => 'compasspoint' },
        'fc3_wind_speed'         => { rtype => 'kmph', formula_symbol => 'Ws' },
        'fc3_wind_speed_max'     => { rtype => 'kmph', formula_symbol => 'Ws' },
        'fc3_wind_speed_max_mph' => { rtype => 'mph', formula_symbol => 'Ws' },
        'fc3_wind_speed_mph'     => { rtype => 'mph', formula_symbol => 'Ws' },
        'feelslike_c'            => { rtype => 'c', formula_symbol => 'Tf', },
        'feelslike_f'            => { rtype => 'f', formula_symbol => 'Tf', },
        'forecast_url'           => { rtype => 'url_http' },
        'history_url'            => { rtype => 'url_http' },
        'humidity'               => { rtype => 'pct', formula_symbol => 'H' },
        'icon_url'               => { rtype => 'url_http' },
        'israining'              => { rtype => 'bool', },
        'lastQueryResult'        => { rtype => 'oknok' },
        'moon_age'               => { rtype => 'd' },
        'moon_pct'               => { rtype => 'pct' },
        'moon_rise'              => { rtype => 'time' },
        'moon_set'               => { rtype => 'time' },
        'ob_url'                 => { rtype => 'url_http' },
        'pressure'               => { rtype => 'hpamb' },
        'pressure_in'            => { rtype => 'inhg' },
        'pressure_trend'         => { rtype => 'trend' },
        'rain'                   => { rtype => 'mm' },
        'rain_day'               => { rtype => 'mm' },
        'rain_day_in'            => { rtype => 'in' },
        'rain_in'                => { rtype => 'in' },
        'solarradiation'         => { rtype => 'wpsm' },
        'sunrise'                => { rtype => 'time' },
        'sunset'                 => { rtype => 'time' },
        'temp_c'                 => { rtype => 'c' },
        'temp_f'                 => { rtype => 'f' },
        'visibility' => {
            rtype => 'km',
            scope => { empty_replace => '--.-' }
        },
        'visibility_mi' => {
            rtype => 'mi',
            scope => { empty_replace => '--.-' }
        },
        'wind_chill' => {
            rtype          => 'c',
            formula_symbol => 'Wc',
            scope          => { empty_replace => '--.-' },
        },
        'wind_chill_f' => {
            rtype          => 'f',
            formula_symbol => 'Wc',
            scope          => { empty_replace => '--.-' }
        },
        'wind_direction' => { rtype => 'compasspoint' },
        'wind_gust'      => { rtype => 'kmph', formula_symbol => 'Wg' },
        'wind_gust_mph'  => { rtype => 'mph', formula_symbol => 'Wg' },
        'wind_speed'     => { rtype => 'kmph', formula_symbol => 'Ws' },
        'wind_speed_mph' => { rtype => 'mph', formula_symbol => 'Ws' }
    };

    return;
}

#####################################
sub Wunderground_GetStatus($;$) {
    my ( $hash, $delay ) = @_;
    my $name = $hash->{NAME};
    $hash->{INTERVAL} = AttrVal( $name, "pollInterval", "300" );
    my $bestfct = AttrVal( $name, "wu_bestfct", undef );
    my $features =
      AttrVal( $name, "wu_features", "astronomy,conditions,forecast" );
    my $lang = AttrVal( $name, "wu_lang", "en" );
    my $pws  = AttrVal( $name, "wu_pws",  undef );
    my $interval = (
          $delay
        ? $delay
        : $hash->{INTERVAL}
    );

    Log3 $name, 5,
      "Wunderground $name: called function Wunderground_GetStatus()";

    RemoveInternalTimer($hash);
    InternalTimer( gettimeofday() + $interval,
        "Wunderground_GetStatus", $hash, 0 );

    return
      if ( $delay || AttrVal( $name, "disable", 0 ) == 1 );

    my $langmap = {
        at      => 'OS',
        de      => 'DL',
        'en-gb' => 'LI',
        gb      => 'LI',
        uk      => 'LI',
    };

    if ( defined( $langmap->{ lc($lang) } ) ) {
        $hash->{LANG} = $langmap->{ lc($lang) };
    }
    else {
        $hash->{LANG} = uc($lang);
    }

    $features =~ s/,{2,}/,/g;
    $features =~ s/\s//g;
    $features =~ s/,/\//g;
    $features .= "/lang:" . $hash->{LANG};
    $features .= "/pws:$pws" if ( defined($pws) );
    $features .= "/bestfct:$bestfct" if ( defined($bestfct) );

    Wunderground_SendCommand( $hash, $features );

    return;
}

###################################
sub Wunderground_Set($$$) {
    my ( $hash, $a, $h ) = @_;
    my $name = $hash->{NAME};

    Log3 $name, 5, "Wunderground $name: called function Wunderground_Set()";

    return "Argument is missing" if ( int(@$a) < 1 );

    my $usage = "Unknown argument " . @$a[1] . ", choose one of update:noArg";

    my $cmd = '';
    my $result;

    # update
    if ( lc( @$a[1] ) eq "update" ) {
        Log3 $name, 3, "Wunderground set $name " . @$a[1];
        Wunderground_GetStatus($hash);
    }

    # return usage hint
    else {
        return $usage;
    }

    return $result;
}

###################################
sub Wunderground_Define($$$) {
    my ( $hash, $a, $h ) = @_;
    my $name  = $hash->{NAME};
    my $infix = "Wunderground";

    Log3 $name, 5, "Wunderground $name: called function Wunderground_Define()";

    eval {
        require JSON;
        import JSON qw( decode_json );
    };
    return "Please install Perl JSON to use module Wunderground"
      if ($@);

    if ( int(@$a) < 2 ) {
        my $msg = "Wrong syntax: define <name> Wunderground <api-key> <pws-id>";
        Log3 $name, 4, $msg;
        return $msg;
    }

    $hash->{TYPE} = "Wunderground";

    $hash->{API_KEY} = @$a[2];
    $hash->{QUERY}   = @$a[3];

    $hash->{QUERY} = "pws:" . $hash->{QUERY}
      if ( $hash->{QUERY} =~ /^[A-Z]{3,}\d{2,}$/ );

    if ( $init_done && !defined( $hash->{OLDDEF} ) ) {
        fhem 'attr ' . $name . ' stateReadings temp_c humidity';
        fhem 'attr ' . $name . ' stateReadingsFormat 1';
        fhem 'attr ' . $name . ' wu_features astronomy,conditions,forecast';
    }

    # start the status update timer
    Wunderground_GetStatus( $hash, 2 );

    return;
}

###################################
sub Wunderground_Attr(@) {
    my ( $cmd, $name, $attrName, $attrVal ) = @_;
    my $hash = $defs{$name};

    Log3 $name, 5, "Wunderground $name: called function Wunderground_Attr()";

    return
"Invalid value for attribute $attrName: minimum value is 1 second, maximum 5 seconds"
      if ( $attrVal
        && $attrName eq "timeout"
        && ( $attrVal < 1 || $attrVal > 5 ) );

    return
      "Invalid value for attribute $attrName: minimum value is 300 seconds"
      if ( $attrVal && $attrName eq "pollInterval" && $attrVal < 300 );

    return undef;
}

############################################################################################################
#
#   Begin of helper functions
#
############################################################################################################

###################################
sub Wunderground_SendCommand($$) {
    my ( $hash, $features ) = @_;
    my $name   = $hash->{NAME};
    my $apikey = $hash->{API_KEY};
    my $query  = $hash->{QUERY};
    my $URL =
      "https://api.wunderground.com/api/%APIKEY%/%FEATURES%/q/%QUERY%.json";

    Log3 $name, 5,
      "Wunderground $name: called function Wunderground_SendCommand()";

    $URL =~ s/%APIKEY%/$apikey/;
    $URL =~ s/%FEATURES%/$features/;
    $URL =~ s/%QUERY%/$query/;

    Log3 $name, 5, "Wunderground $name: GET " . urlDecode($URL);

    HttpUtils_NonblockingGet(
        {
            url     => $URL,
            timeout => AttrVal( $name, "timeout", "3" ),
            hash    => $hash,
            method  => "GET",
            header =>
"agent: FHEM-Wunderground/1.0.0\r\nUser-Agent: FHEM-Wunderground/1.0.0\r\nAccept: application/json",
            httpversion => "1.1",
            callback    => \&Wunderground_ReceiveCommand,
        }
    );

    return;
}

###################################
sub Wunderground_ReceiveCommand($$$) {
    my ( $param, $err, $data ) = @_;
    my $hash = $param->{hash};
    my $name = $hash->{NAME};
    my $lastQueryResult =
      ReadingsVal( $name, "lastQueryResult", "Initialized" );
    my $state = "Initialized";
    my $return;

    Log3 $name, 5,
      "Wunderground $name: called function Wunderground_ReceiveCommand()";

    readingsBeginUpdate($hash);

    # service not reachable
    if ($err) {
        Log3 $name, 4, "Wunderground $name: RCV TIMEOUT: $err";

        $lastQueryResult = "unavailable";
    }

    # data received
    elsif ($data) {
        Log3 $name, 4, "Wunderground $name: RCV";

        if ( $data ne "" ) {

            # fix malformed JSON ...
            $data =~ s/^[\s\r\n0-9a-zA-Z]*//;
            $data =~ s/[\s\r\n0-9a-zA-Z]*$//;
            $data =~ s/[\r\n]+[0-9a-zA-Z]+[\r\n]+//g;

            eval '$return = decode_json( Encode::encode_utf8($data) ); 1';
            if ($@) {

                Log3 $name, 5,
"Wunderground $name: RES ERROR - unable to parse malformed JSON: $@\n"
                  . $data;

                return undef;
            }
            else {
                Log3 $name, 5, "Wunderground $name: RES";
            }
        }

        $lastQueryResult = "undefined";

        #######################
        # process return data
        #
        if ( $return && ref($return) eq "HASH" ) {
            $lastQueryResult = Wunderground_Hash2Readings( $hash, $return );
        }
    }

    # state
    my $stateReadings       = AttrVal( $name, "stateReadings",       "" );
    my $stateReadingsLang   = AttrVal( $name, "stateReadingsLang",   "en" );
    my $stateReadingsFormat = AttrVal( $name, "stateReadingsFormat", "0" );

    # $state =
    #   makeSTATE( $name, $stateReadings,
    #     $stateReadingsLang, $stateReadingsFormat );

    $state = makeSTATE( $name, $stateReadings, $stateReadingsFormat );

    readingsBulkUpdate( $hash, "state", $state );
    readingsBulkUpdateIfChanged( $hash, "lastQueryResult", $lastQueryResult );
    readingsEndUpdate( $hash, 1 );

    return;
}

###################################
sub Wunderground_Hash2Readings($$;$) {
    my ( $hash, $h, $r ) = @_;
    my $name = $hash->{NAME};
    my $lang = AttrVal( $name, "wu_lang", "en" );
    my $loop = 0;
    $loop = 1 if ( defined($r) );

    if ( ref($h) eq "HASH" ) {
        foreach my $k ( keys %{$h} ) {

            # error
            return $h->{response}{error}{type}
              if ( $k eq "response"
                && defined( $h->{response}{error}{type} ) );

            next
              if ( $k eq "image"
                || $k eq "response"
                || $k eq "station_id"
                || $k =~ /^.*_string$/ );

            my $reading;
            my $cr = $k;

            # hash level1 renaming
            $cr = "" if ( $cr eq "current_observation" );

            # custom reading
            $cr = "condition"      if ( $cr eq "weather" );
            $cr = "dewpoint"       if ( $cr eq "dewpoint_c" );
            $cr = "humidity"       if ( $cr eq "relative_humidity" );
            $cr = "pressure"       if ( $cr eq "pressure_mb" );
            $cr = "rain"           if ( $cr eq "precip_1hr_metric" );
            $cr = "rain_day"       if ( $cr eq "precip_today_metric" );
            $cr = "rain_in"        if ( $cr eq "precip_1hr_in" );
            $cr = "rain_day_in"    if ( $cr eq "precip_today_in" );
            $cr = "wind_direction" if ( $cr eq "wind_degrees" );
            $cr = "wind_gust"      if ( $cr eq "wind_gust_kph" );
            $cr = "wind_gust_mph"  if ( $cr eq "wind_gust_mph" );
            $cr = "wind_speed"     if ( $cr eq "wind_kph" );
            $cr = "wind_speed_mph" if ( $cr eq "wind_mph" );
            $cr = "wind_chill"     if ( $cr eq "windchill_c" );
            $cr = "wind_chill_f"   if ( $cr eq "windchill_f" );
            $cr = "visibility"     if ( $cr eq "visibility_km" );

            next
              if ( $cr =~ /^sun_phase(.*)$/
                || $cr eq "date"
                || $cr eq "wind_dir" );
            next if ( $r && $r =~ /^display_location.*$/ );

            # observation_*
            if ( $cr =~ /^observation_.*$/ ) {
                $hash->{LAST_OBSERVATION} = $h->{observation_epoch};
                next;
            }

            # local_*
            elsif ( $cr =~ /^local_.*$/ ) {
                $hash->{LAST} = $h->{local_epoch};
                next;
            }

            # moon_phase
            elsif ( $cr =~ /^moon_phase(.*)$/ ) {
                my $sunrise = $h->{moon_phase}{sunrise}{hour} . ":"
                  . $h->{moon_phase}{sunrise}{minute};
                my $sunset = $h->{moon_phase}{sunset}{hour} . ":"
                  . $h->{moon_phase}{sunset}{minute};
                my $moonrise = $h->{moon_phase}{moonrise}{hour} . ":"
                  . $h->{moon_phase}{moonrise}{minute};
                my $moonset = $h->{moon_phase}{moonset}{hour} . ":"
                  . $h->{moon_phase}{moonset}{minute};

                $sunrise =~ s/^(\d):(\d\d)$/0$1:$2/;
                $sunrise =~ s/^(\d\d):(\d)$/$1:0$2/;
                $sunset =~ s/^(\d):(\d\d)$/0$1:$2/;
                $sunset =~ s/^(\d\d):(\d)$/$1:0$2/;
                $moonrise =~ s/^(\d):(\d\d)$/0$1:$2/;
                $moonrise =~ s/^(\d\d):(\d)$/$1:0$2/;
                $moonset =~ s/^(\d):(\d\d)$/0$1:$2/;
                $moonset =~ s/^(\d\d):(\d)$/$1:0$2/;

                readingsBulkUpdate( $hash, "sunrise",  $sunrise );
                readingsBulkUpdate( $hash, "sunset",   $sunset );
                readingsBulkUpdate( $hash, "moonrise", $moonrise );
                readingsBulkUpdate( $hash, "moonset",  $moonset );

                readingsBulkUpdate( $hash, "moon_age",
                    $h->{moon_phase}{ageOfMoon} );
                readingsBulkUpdate( $hash, "moon_pct",
                    $h->{moon_phase}{percentIlluminated} );
                readingsBulkUpdate( $hash, "moon_phase",
                    $h->{moon_phase}{phaseofMoon} );
            }

            # hourly_forecast
            elsif ($r
                && $r =~ /^hourly_forecast(\d+)$/ )
            {
                my $period = $r;
                $period =~ s/[^\d]//g;
                $reading = "hfc" . $period . "_";

                readingsBulkUpdate( $hash, $reading . "condition",
                    $h->{conditions} );
                readingsBulkUpdate(
                    $hash,
                    $reading . "dewpoint_c",
                    $h->{dewpoint}{metric}
                );
                readingsBulkUpdate(
                    $hash,
                    $reading . "dewpoint_f",
                    $h->{dewpoint}{english}
                );
                readingsBulkUpdate(
                    $hash,
                    $reading . "feelslike_c",
                    $h->{feelslike}{metric}
                );
                readingsBulkUpdate(
                    $hash,
                    $reading . "feelslike_f",
                    $h->{feelslike}{english}
                );
                readingsBulkUpdate(
                    $hash,
                    $reading . "heatindex_c",
                    $h->{heatindex}{metric}
                );
                readingsBulkUpdate(
                    $hash,
                    $reading . "heatindex_f",
                    $h->{heatindex}{english}
                );
                readingsBulkUpdate( $hash, $reading . "humidity",
                    $h->{humidity} );
                readingsBulkUpdate( $hash, $reading . "icon", $h->{icon} );
                readingsBulkUpdate( $hash, $reading . "icon_url",
                    $h->{icon_url} );
                readingsBulkUpdate(
                    $hash,
                    $reading . "mslp_c",
                    $h->{mslp}{metric}
                );
                readingsBulkUpdate(
                    $hash,
                    $reading . "mslp_f",
                    $h->{mslp}{english}
                );
                readingsBulkUpdate( $hash, $reading . "pop", $h->{pop} );
                readingsBulkUpdate(
                    $hash,
                    $reading . "temp_c",
                    $h->{temp}{metric}
                );
                readingsBulkUpdate(
                    $hash,
                    $reading . "temp_f",
                    $h->{temp}{english}
                );
                readingsBulkUpdate(
                    $hash,
                    $reading . "rain",
                    $h->{qpf}{metric}
                );
                readingsBulkUpdate(
                    $hash,
                    $reading . "rain_in",
                    $h->{qpf}{english}
                );
                readingsBulkUpdate(
                    $hash,
                    $reading . "snow",
                    $h->{snow}{metric}
                );
                readingsBulkUpdate(
                    $hash,
                    $reading . "snow_in",
                    $h->{snow}{english}
                );
                readingsBulkUpdate(
                    $hash,
                    $reading . "wind_direction",
                    $h->{wdir}{degrees}
                );
                readingsBulkUpdate(
                    $hash,
                    $reading . "wind_chill",
                    $h->{windchill}{metric}
                );
                readingsBulkUpdate(
                    $hash,
                    $reading . "wind_chill_f",
                    $h->{windchill}{english}
                );
                readingsBulkUpdate(
                    $hash,
                    $reading . "wind_speed",
                    $h->{wspd}{metric}
                );
                readingsBulkUpdate(
                    $hash,
                    $reading . "wind_speed_mph",
                    $h->{wspd}{english}
                );
                readingsBulkUpdate( $hash, $reading . "sky", $h->{sky} );
                readingsBulkUpdate( $hash, $reading . "UV",  $h->{uvi} );

                my $time = $h->{FCTTIME}{hour} . ":" . $h->{FCTTIME}{min};

                $time =~ s/^(\d):(\d\d)$/0$1:$2/;
                readingsBulkUpdate( $hash, $reading . "time", $time );
            }

            # simpleforecast
            elsif ($r
                && $r =~ /^forecast\/simpleforecast\/forecastday(\d+)$/ )
            {
                my $period = $h->{period} - 1;
                $reading = "fc" . $period . "_";

                readingsBulkUpdate( $hash, $reading . "condition",
                    $h->{conditions} );
                readingsBulkUpdate(
                    $hash,
                    $reading . "high_c",
                    $h->{high}{celsius}
                );
                readingsBulkUpdate(
                    $hash,
                    $reading . "high_f",
                    $h->{high}{fahrenheit}
                );
                readingsBulkUpdate( $hash, $reading . "humidity",
                    $h->{avehumidity} );
                readingsBulkUpdate( $hash, $reading . "humidity_min",
                    $h->{minhumidity} );
                readingsBulkUpdate( $hash, $reading . "humidity_max",
                    $h->{maxhumidity} );
                readingsBulkUpdate( $hash, $reading . "icon", $h->{icon} );
                readingsBulkUpdate( $hash, $reading . "icon_url",
                    $h->{icon_url} );
                readingsBulkUpdate(
                    $hash,
                    $reading . "low_c",
                    $h->{low}{celsius}
                );
                readingsBulkUpdate(
                    $hash,
                    $reading . "low_f",
                    $h->{low}{fahrenheit}
                );
                readingsBulkUpdate( $hash, $reading . "pop", $h->{pop} );
                readingsBulkUpdate(
                    $hash,
                    $reading . "rain_day",
                    $h->{qpf_allday}{mm}
                );
                readingsBulkUpdate(
                    $hash,
                    $reading . "rain_day_in",
                    $h->{qpf_allday}{in}
                );
                readingsBulkUpdate(
                    $hash,
                    $reading . "rain_night",
                    $h->{qpf_night}{mm}
                );
                readingsBulkUpdate(
                    $hash,
                    $reading . "rain_night_in",
                    $h->{qpf_night}{in}
                );
                readingsBulkUpdate(
                    $hash,
                    $reading . "snow_day",
                    $h->{snow_allday}{cm}
                );
                readingsBulkUpdate(
                    $hash,
                    $reading . "snow_day_in",
                    $h->{snow_allday}{in}
                );
                readingsBulkUpdate(
                    $hash,
                    $reading . "snow_night",
                    $h->{snow_night}{cm}
                );
                readingsBulkUpdate(
                    $hash,
                    $reading . "snow_night_in",
                    $h->{snow_night}{in}
                );
                readingsBulkUpdate(
                    $hash,
                    $reading . "wind_direction",
                    $h->{avewind}{degrees}
                );
                readingsBulkUpdate(
                    $hash,
                    $reading . "wind_direction_max",
                    $h->{maxwind}{degrees}
                );
                readingsBulkUpdate(
                    $hash,
                    $reading . "wind_speed",
                    $h->{avewind}{kph}
                );
                readingsBulkUpdate(
                    $hash,
                    $reading . "wind_speed_mph",
                    $h->{avewind}{mph}
                );
                readingsBulkUpdate(
                    $hash,
                    $reading . "wind_speed_max",
                    $h->{maxwind}{kph}
                );
                readingsBulkUpdate(
                    $hash,
                    $reading . "wind_speed_max_mph",
                    $h->{maxwind}{mph}
                );
            }

            # txt_forecast
            elsif ($r
                && $r =~ /^forecast\/txt_forecast\/forecastday(\d+)$/ )
            {
                my $period = $h->{period};
                my $night =
                  (      $period eq "1"
                      || $period eq "3"
                      || $period eq "5"
                      || $period eq "7" ? "_night" : "" );

                if ( $period < 2 ) {
                    $period = "0";
                }
                elsif ( $period < 4 ) {
                    $period = "1";
                }
                elsif ( $period < 6 ) {
                    $period = "2";
                }
                elsif ( $period < 8 ) {
                    $period = "3";
                }

                $reading = "fc" . $period . "_";
                my $symbol_c =
                  Encode::encode_utf8( chr(0x202F) . chr(0x00B0) . 'C' );
                my $symbol_f =
                  Encode::encode_utf8( chr(0x202F) . chr(0x00B0) . 'F' );
                my $symbol_pct = Encode::encode_utf8( chr(0x202F) . '%' );
                my $symbol_kmh = Encode::encode_utf8( chr(0x00A0) . 'km/h' );
                my $symbol_mph = Encode::encode_utf8( chr(0x00A0) . 'mph' );
                $h->{fcttext_metric} =~ s/(\d)C/$1$symbol_c/g;
                $h->{fcttext} =~ s/(\d)F/$1$symbol_f/g;
                $h->{fcttext_metric} =~ s/(\d)\s*%/$1$symbol_pct/g;
                $h->{fcttext} =~ s/(\d)\s*%/$1$symbol_pct/g;
                $h->{fcttext_metric} =~ s/(\d)\s*km\/h/$1$symbol_kmh/g;
                $h->{fcttext} =~ s/(\d)\s*km\/h/$1$symbol_kmh/g;
                $h->{fcttext_metric} =~ s/(\d)\s*mph/$1$symbol_mph/g;
                $h->{fcttext} =~ s/(\d)\s*mph/$1$symbol_mph/g;

                readingsBulkUpdate( $hash, $reading . "icon$night",
                    $h->{icon} );
                readingsBulkUpdate( $hash, $reading . "icon_url$night",
                    $h->{icon_url} );
                readingsBulkUpdate( $hash, $reading . "pop$night", $h->{pop} );
                readingsBulkUpdate( $hash, $reading . "title$night",
                    $h->{title} );
                readingsBulkUpdate( $hash, $reading . "text$night",
                    $h->{fcttext_metric} );
                readingsBulkUpdate( $hash, $reading . "text_f$night",
                    $h->{fcttext} );

                $hash->{readingDesc}{"title$night"}{lang}  = $lang if ($lang);
                $hash->{readingDesc}{"text$night"}{lang}   = $lang if ($lang);
                $hash->{readingDesc}{"text_f$night"}{lang} = $lang if ($lang);
            }

            # almanac/temp_high
            elsif ($r
                && $r =~ /^almanac\/temp_high(.*)$/ )
            {
                $reading = "almanac_high_";
                readingsBulkUpdate( $hash,
                    $reading . "year", $h->{recordyear} );
                readingsBulkUpdate( $hash, $reading . "c", $h->{normal}{C} );
                readingsBulkUpdate( $hash, $reading . "f", $h->{normal}{F} );
                readingsBulkUpdate( $hash, $reading . "record_c",
                    $h->{record}{C} );
                readingsBulkUpdate( $hash, $reading . "record_f",
                    $h->{record}{F} );
            }
            elsif ($r
                && $r =~ /^almanac\/temp_low(.*)$/ )
            {
                $reading = "almanac_low_";
                readingsBulkUpdate( $hash,
                    $reading . "year", $h->{recordyear} );
                readingsBulkUpdate( $hash, $reading . "c", $h->{normal}{C} );
                readingsBulkUpdate( $hash, $reading . "f", $h->{normal}{F} );
                readingsBulkUpdate( $hash, $reading . "record_c",
                    $h->{record}{C} );
                readingsBulkUpdate( $hash, $reading . "record_f",
                    $h->{record}{F} );
            }

            elsif ( ref( $h->{$k} ) eq "HASH" || ref( $h->{$k} ) eq "ARRAY" ) {
                $reading .= $r . "/" if ( $r && $r ne "" );
                $reading .= $cr;

                Wunderground_Hash2Readings( $hash, $h->{$k}, $reading );
            }

            else {
                $reading .= $r . "_." if ( $r && $r ne "" );
                $reading .= $cr;
                my $value = $h->{$k};
                $value = "" if ( !defined($value) || $value =~ m/^n\/?a$/i );

                if ( $reading eq "icon" || $reading eq "icon_url" ) {
                    my $sunrise = ReadingsVal( $hash->{NAME}, "sunrise", 0 );
                    my $sunset  = ReadingsVal( $hash->{NAME}, "sunset",  0 );
                    $sunrise = time_str2num("1970-01-01 $sunrise:00")
                      if ($sunrise);
                    $sunset = time_str2num("1970-01-01 $sunset:00")
                      if ($sunset);
                    my (
                        $second,     $minute,    $hour,
                        $dayOfMonth, $month,     $yearOffset,
                        $dayOfWeek,  $dayOfYear, $daylightSavings
                    ) = localtime();
                    my $currentTime = ( ( $hour * 3600 ) + ( $minute * 60 ) );

                    # for icon and icon_url, make sure to add nt_ prefix
                    # during the night
                    if (
                        ( $currentTime > 43200 && $currentTime >= $sunset )
                        || (   $currentTime <= 43200
                            && $currentTime < $sunrise )
                      )
                    {
                        $value = "nt_" . $value if ( $reading eq "icon" );
                        $value = $1 . "nt_" . $2 . $3
                          if ( $reading eq "icon_url"
                            && $value =~ /^(.*\/)([A-Za-z0-9]+)(\.[a-z]+)$/ );
                    }

                    # for icon and icon_url, make sure to remove nt_ prefix
                    # during the daytime
                    else {
                        $value =~ s/^nt_//  if ( $reading eq "icon" );
                        $value =~ s/\/nt_// if ( $reading eq "icon_url" );
                    }
                }

                elsif ( $reading eq "almanac_.airport_code" ) {
                    $reading = "almanac_airport_code";
                }

                $value = "0"
                  if ( $reading =~ /^wind_(gust|speed).*$/
                    && looks_like_number($value)
                    && $value < 0 );

                $value =~ s/^(\d+)%$/$1/;

                readingsBulkUpdate( $hash, $reading, $value );
            }
        }
    }
    elsif ( ref($h) eq "ARRAY" ) {
        my $i = 0;

        foreach ( @{$h} ) {
            if ( ref($_) eq "HASH" || ref($_) eq "ARRAY" ) {
                Wunderground_Hash2Readings( $hash, $_, $r . $i );
            }
            else {
                readingsBulkUpdate( $hash, $r . $i, $_ );
            }

            $i++;
        }
    }

    return "ok" if ( !$loop );
}

###################################
sub Wunderground_Undefine($$$) {
    my ( $hash, $a, $h ) = @_;
    my $name = $hash->{NAME};

    if ( defined( $hash->{fhem}{infix} ) ) {
        Wunderground_removeExtension( $hash->{fhem}{infix} );
    }

    Log3 $name, 5,
      "Wunderground $name: called function Wunderground_Undefine()";

    # Stop the internal GetStatus-Loop and exit
    RemoveInternalTimer($hash);

    # release reverse pointer
    delete $modules{Wunderground}{defptr}{$name};

    return;
}

1;

=pod
=item device
=item summary Get weather data and forecast from Weather Underground
=item summary_DE Ruft Wetterdaten und Vorhersage von Weather Underground ab
=begin html

<a name="Wunderground" id="Wunderground"></a>
<h3>Wunderground</h3>
<ul>
  This module gets weather data and forecast from <a href="http://www.wunderground.com/">Weather Underground</a> weather service.
  <br><br>
  <a name="Wundergrounddefine"></a>
  <b>Define</b>
  <ul><br>
    <code>define &lt;name&gt; Wunderground &lt;api-key&gt; &lt;query&gt;</code>
    <br><br>
    Example:
    <ul><br>
      <code>
      define WUweather Wunderground d123ab11bb2c3456 IBAYERNM70<br>
      define WUweather Wunderground d123ab11bb2c3456 Germany/Berlin<br>
      </code><br>
    </ul>
    <br>
  </ul>
  <br><br>
  <a name="Wundergroundset"></a>
  <b>Set</b>
  <ul>
    <li>update - refresh data</li>
  </ul>
  <br><br>
  <a name="Wundergroundattr"></a>
  <b>Attributes</b>
  <ul>
    <li>pollInterval - Set regular polling interval in seconds (default=300)</li>
    <li>wu_bestfct - Use Weather Undergrond Best Forecast for forecast (default=1)</li>
    <li>wu_features - One or more of the data features to be fetched (default=astronomy,conditions,forecast)</li>
    <li>wu_lang - Returns the API response in the specified language (default=en)</li>
    <li>wu_pws - Use personal weather stations for conditions (default=1)</li>
  </ul>
  <br><br>
</ul>

=end html

=begin html_DE

<a name="Wunderground" id="Wunderground"></a>
<h3>Wunderground</h3>
<ul>
  Eine deutsche Version der Dokumentation ist derzeit nicht vorhanden. Die englische Version ist hier zu finden:
</ul>
<ul>
  <a href='http://fhem.de/commandref.html#Wunderground'>Wunderground</a>
</ul>

=end html_DE

=cut
