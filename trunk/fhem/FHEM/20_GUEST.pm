# $Id$
##############################################################################
#
#     20_GUEST.pm
#     Submodule of 10_RESIDENTS.
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
#
# Version: 1.0.1
#
# Major Version History:
# - 1.0.0 - 2014-02-08
# -- First release
#
##############################################################################

package main;

use strict;
use warnings;
use Time::Local;
use Data::Dumper;

sub GUEST_Set($@);
sub GUEST_Define($$);
sub GUEST_Undefine($$);

###################################
sub GUEST_Initialize($) {
    my ($hash) = @_;

    Log3 $hash, 5, "GUEST_Initialize: Entering";

    $hash->{SetFn}   = "GUEST_Set";
    $hash->{DefFn}   = "GUEST_Define";
    $hash->{UndefFn} = "GUEST_Undefine";
    $hash->{AttrList} =
"rg_locationHome rg_locationWayhome rg_locationUnderway rg_autoGoneAfter:12,16,24,26,28,30,36,48,60 rg_showAllStates:0,1 rg_realname:group,alias rg_states rg_locations rg_moods rg_moodDefault rg_moodSleepy "
      . $readingFnAttributes;
}

###################################
sub GUEST_Define($$) {
    my ( $hash, $def ) = @_;
    my @a = split( "[ \t][ \t]*", $def );
    my $name = $hash->{NAME};
    my $name_attr;

    Log3 $name, 5, "GUEST $name: called function GUEST_Define()";

    if ( int(@a) < 2 ) {
        my $msg = "Wrong syntax: define <name> GUEST [RESIDENTS-DEVICE-NAMES]";
        Log3 $name, 4, $msg;
        return $msg;
    }

    $hash->{TYPE} = "GUEST";

    my $parents = ( defined( $a[2] ) ? $a[2] : "" );

    # unregister at parent objects if we get modified
    my @registeredResidentgroups;
    my $modified = 0;
    if ( defined( $hash->{RESIDENTGROUPS} ) && $hash->{RESIDENTGROUPS} ne "" ) {
        $modified = 1;
        @registeredResidentgroups =
          split( /,/, $hash->{RESIDENTGROUPS} );

        # unregister at parent objects
        foreach my $parent (@registeredResidentgroups) {
            if ( defined( $defs{$parent} )
                && $defs{$parent}{TYPE} eq "RESIDENTS" )
            {
                fhem("set $parent unregister $name");
                Log3 $name, 4,
                  "GUEST $name: Unregistered at RESIDENTS device $parent";
            }
        }
    }

    # register at parent objects
    $hash->{RESIDENTGROUPS} = "";
    if ( $parents ne "" ) {
        @registeredResidentgroups = split( /,/, $parents );
        foreach my $parent (@registeredResidentgroups) {
            if ( !defined( $defs{$parent} ) ) {
                Log3 $name, 3,
"GUEST $name: Unable to register at RESIDENTS device $parent (not existing)";
                next;
            }

            if ( $defs{$parent}{TYPE} ne "RESIDENTS" ) {
                Log3 $name, 3,
"GUEST $name: Device $parent is not a RESIDENTS device (wrong type)";
                next;
            }

            fhem("set $parent register $name");
            $hash->{RESIDENTGROUPS} .= $parent . ",";
            Log3 $name, 4,
              "GUEST $name: Registered at RESIDENTS device $parent";
        }
    }
    else {
        $modified = 0;
    }

    readingsBeginUpdate($hash);

    # attr alias
    $name_attr = "alias";
    unless ( exists( $attr{$name}{$name_attr} ) ) {
        my $aliasname = $name;
        $aliasname =~ s/^rg_//;
        Log3 $name, 4, "GUEST $name: created new attribute '$name_attr'";

        $attr{$name}{$name_attr} = $aliasname;
    }

    # attr devStateIcon
    $name_attr = "devStateIcon";
    unless ( exists( $attr{$name}{$name_attr} ) ) {
        Log3 $name, 4, "GUEST $name: created new attribute '$name_attr'";

        $attr{$name}{$name_attr} =
".*home:user_available:absent .*absent:user_away:home .*none:control_building_empty:home .*gotosleep:scene_toilet:asleep .*asleep:scene_sleeping:awoken .*awoken:scene_sleeping_alternat:home .*:user_unknown";
    }

    # attr group
    $name_attr = "group";
    unless ( exists( $attr{$name}{$name_attr} ) ) {
        Log3 $name, 4, "GUEST $name: created new attribute '$name_attr'";

        $attr{$name}{$name_attr} = "Guests";
    }

    # attr icon
    $name_attr = "icon";
    unless ( exists( $attr{$name}{$name_attr} ) ) {
        Log3 $name, 4, "GUEST $name: created new attribute '$name_attr'";

        $attr{$name}{$name_attr} = "scene_visit_guests";
    }

    # attr icon
    $name_attr = "rg_realname";
    unless ( exists( $attr{$name}{$name_attr} ) ) {
        Log3 $name, 4, "GUEST $name: created new attribute '$name_attr'";

        $attr{$name}{$name_attr} = "alias";
    }

    # attr room
    $name_attr = "room";
    if (   @registeredResidentgroups
        && exists( $attr{ $registeredResidentgroups[0] }{$name_attr} )
        && !exists( $attr{$name}{$name_attr} ) )
    {
        Log3 $name, 4, "GUEST $name: created new attribute '$name_attr'";

        $attr{$name}{$name_attr} =
          $attr{ $registeredResidentgroups[0] }{$name_attr};
    }

    # attr sortby
    $name_attr = "sortby";
    unless ( exists( $attr{$name}{$name_attr} ) ) {
        Log3 $name, 4, "GUEST $name: created new attribute '$name_attr'";

        $attr{$name}{$name_attr} = "1";
    }

    # attr webCmd
    $name_attr = "webCmd";
    unless ( exists( $attr{$name}{$name_attr} ) ) {
        Log3 $name, 4, "GUEST $name: created new attribute '$name_attr'";

        $attr{$name}{$name_attr} = "state:mood";
    }

    # trigger for modified objects
    unless ( $modified == 0 ) {
        readingsBulkUpdate( $hash, "state", $hash->{READINGS}{state}{VAL} );
    }

    readingsEndUpdate( $hash, 1 );

    # run timers
    InternalTimer( gettimeofday() + 15, "GUEST_StartInternalTimers", $hash, 0 );

    return undef;
}

###################################
sub GUEST_Undefine($$) {
    my ( $hash, $name ) = @_;

    GUEST_RemoveInternalTimer( "AutoGone",      $hash );
    GUEST_RemoveInternalTimer( "DurationTimer", $hash );

    if ( defined( $hash->{RESIDENTGROUPS} ) ) {
        my @registeredResidentgroups =
          split( /,/, $hash->{RESIDENTGROUPS} );

        # unregister at parent objects
        foreach my $parent (@registeredResidentgroups) {
            if ( defined( $defs{$parent} )
                && $defs{$parent}{TYPE} eq "RESIDENTS" )
            {
                fhem("set $parent unregister $name");
                Log3 $name, 4,
                  "GUEST $name: Unregistered at RESIDENTS device $parent";
            }
        }
    }

    return undef;
}

###################################
sub GUEST_Set($@) {
    my ( $hash, @a ) = @_;
    my $name = $hash->{NAME};
    my $state =
      ( defined( $hash->{READINGS}{state}{VAL} ) )
      ? $hash->{READINGS}{state}{VAL}
      : "initialized";
    my $presence =
      ( defined( $hash->{READINGS}{presence}{VAL} ) )
      ? $hash->{READINGS}{presence}{VAL}
      : "undefined";
    my $mood =
      ( defined( $hash->{READINGS}{mood}{VAL} ) )
      ? $hash->{READINGS}{mood}{VAL}
      : "-";
    my $location =
      ( defined( $hash->{READINGS}{location}{VAL} ) )
      ? $hash->{READINGS}{location}{VAL}
      : "undefined";
    my $silent = 0;

    Log3 $name, 5, "GUEST $name: called function GUEST_Set()";

    return "No Argument given" if ( !defined( $a[1] ) );

    # states
    my $states = (
        defined( $attr{$name}{rg_states} ) ? $attr{$name}{rg_states}
        : (
            defined( $attr{$name}{rg_showAllStates} )
              && $attr{$name}{rg_showAllStates} == 1
            ? "home,gotosleep,asleep,awoken,absent,none"
            : "home,gotosleep,absent,none"
        )
    );
    $states = $state . "," . $states if ( $states !~ /$state/ );
    $states =~ s/ /,/g;

    # moods
    my $moods = (
        defined( $attr{$name}{rg_moods} )
        ? $attr{$name}{rg_moods} . ",toggle"
        : "calm,relaxed,happy,excited,lonely,sad,bored,stressed,uncomfortable,sleepy,angry,toggle"
    );
    $moods = $mood . "," . $moods if ( $moods !~ /$mood/ );
    $moods =~ s/ /,/g;

    # locations
    my $locations = (
        defined( $attr{$name}{rg_locations} )
        ? $attr{$name}{rg_locations}
        : ""
    );
    if (   $locations !~ /$location/
        && $locations ne "" )
    {
        $locations = ":" . $location . "," . $locations;
    }
    elsif ( $locations ne "" ) {
        $locations = ":" . $locations;
    }
    $locations =~ s/ /,/g;

    my $usage = "Unknown argument " . $a[1] . ", choose one of";
    $usage .= " state:$states";
    $usage .= " mood:$moods";
    $usage .= " location$locations";

#    $usage .=
#" create:wuTimerWd,wuTimerWe,wuTimerMon,wuTimerTue,wuTimerWed,wuTimerThu,wuTimerFri,wuTimerSat,wuTimerSun";
#    $usage .= " compactMode:noArg largeMode:noArg";

    # silentSet
    if ( $a[1] eq "silentSet" ) {
        $silent = 1;
        my $first = shift @a;
        $a[0] = $first;
    }

    # states
    if (   $a[1] eq "state"
        || $a[1] eq "home"
        || $a[1] eq "gotosleep"
        || $a[1] eq "asleep"
        || $a[1] eq "awoken"
        || $a[1] eq "absent"
        || $a[1] eq "none"
        || $a[1] eq "gone" )
    {
        my $newstate;

        # if not direct
        if (
               $a[1] eq "state"
            && defined( $a[2] )
            && (   $a[2] eq "home"
                || $a[2] eq "gotosleep"
                || $a[2] eq "asleep"
                || $a[2] eq "awoken"
                || $a[2] eq "absent"
                || $a[2] eq "none"
                || $a[2] eq "gone" )
          )
        {
            $newstate = $a[2];
        }
        elsif ( defined( $a[2] ) ) {
            return
"Invalid 2nd argument, choose one of home gotosleep asleep awoken absent gone ";
        }
        else {
            $newstate = $a[1];
        }

        $newstate = "none" if ( $newstate eq "gone" );

        Log3 $name, 2, "GUEST set $name " . $newstate if ( !$silent );

        if ( $state ne $newstate ) {
            readingsBeginUpdate($hash);

            readingsBulkUpdate( $hash, "lastState", $state );
            readingsBulkUpdate( $hash, "state",     $newstate );

            my $datetime = TimeNow();

            # reset mood
            my $mood_default =
              ( defined( $attr{$name}{"rg_moodDefault"} ) )
              ? $attr{$name}{"rg_moodDefault"}
              : "calm";
            my $mood_sleepy =
              ( defined( $attr{$name}{"rg_moodSleepy"} ) )
              ? $attr{$name}{"rg_moodSleepy"}
              : "sleepy";

            if (
                $mood ne "-"
                && (   $newstate eq "gone"
                    || $newstate eq "none"
                    || $newstate eq "absent"
                    || $newstate eq "asleep" )
              )
            {
                Log3 $name, 4,
                  "GUEST $name: implicit mood change caused by state "
                  . $newstate;
                GUEST_Set( $hash, $name, "silentSet", "mood", "-" );
            }

            elsif ( $mood ne $mood_sleepy
                && ( $newstate eq "gotosleep" || $newstate eq "awoken" ) )
            {
                Log3 $name, 4,
                  "GUEST $name: implicit mood change caused by state "
                  . $newstate;
                GUEST_Set( $hash, $name, "silentSet", "mood", $mood_sleepy );
            }

            elsif ( ( $mood eq "-" || $mood eq $mood_sleepy )
                && $newstate eq "home" )
            {
                Log3 $name, 4,
                  "GUEST $name: implicit mood change caused by state "
                  . $newstate;
                GUEST_Set( $hash, $name, "silentSet", "mood", $mood_default );
            }

            # calculate presence state
            my $newpresence =
              (      $newstate ne "none"
                  && $newstate ne "gone"
                  && $newstate ne "absent" )
              ? "present"
              : "absent";

            # if presence changed
            if ( $newpresence ne $presence ) {
                readingsBulkUpdate( $hash, "presence", $newpresence );

                # update location
                my @location_home =
                  ( defined( $attr{$name}{"rg_locationHome"} ) )
                  ? split( ' ', $attr{$name}{"rg_locationHome"} )
                  : ("home");
                my @location_underway =
                  ( defined( $attr{$name}{"rg_locationUnderway"} ) )
                  ? split( ' ', $attr{$name}{"rg_locationUnderway"} )
                  : ("underway");
                my $searchstring = quotemeta($location);

                if ( $newpresence eq "present" ) {
                    if ( !grep( m/^$searchstring$/, @location_home )
                        && $location ne $location_home[0] )
                    {
                        Log3 $name, 4,
"GUEST $name: implicit location change caused by state "
                          . $newstate;
                        GUEST_Set( $hash, $name, "silentSet", "location",
                            $location_home[0] );
                    }
                }
                else {
                    if ( !grep( m/^$searchstring$/, @location_underway )
                        && $location ne $location_underway[0] )
                    {
                        Log3 $name, 4,
"GUEST $name: implicit location change caused by state "
                          . $newstate;
                        GUEST_Set( $hash, $name, "silentSet", "location",
                            $location_underway[0] );
                    }
                }

                # reset wayhome
                if ( !defined( $hash->{READINGS}{wayhome}{VAL} )
                    || $hash->{READINGS}{wayhome}{VAL} ne "0" )
                {
                    readingsBulkUpdate( $hash, "wayhome", "0" );
                }

                # update statistics
                if ( $newpresence eq "present" ) {
                    readingsBulkUpdate( $hash, "lastArrival", $datetime );

                    # absence duration
                    if ( defined( $hash->{READINGS}{lastDeparture}{VAL} )
                        && $hash->{READINGS}{lastDeparture}{VAL} ne "-" )
                    {
                        readingsBulkUpdate(
                            $hash,
                            "lastDurAbsence",
                            GUEST_TimeDiff(
                                $datetime, $hash->{READINGS}{lastDeparture}{VAL}
                            )
                        );
                    }
                }
                else {
                    readingsBulkUpdate( $hash, "lastDeparture", $datetime );

                    # presence duration
                    if ( defined( $hash->{READINGS}{lastArrival}{VAL} )
                        && $hash->{READINGS}{lastArrival}{VAL} ne "-" )
                    {
                        readingsBulkUpdate(
                            $hash,
                            "lastDurPresence",
                            GUEST_TimeDiff(
                                $datetime, $hash->{READINGS}{lastArrival}{VAL}
                            )
                        );
                    }
                }

                # adjust linked objects
                if ( defined( $attr{$name}{"rg_passPresenceTo"} )
                    && $attr{$name}{"rg_passPresenceTo"} ne "" )
                {
                    my @linkedObjects =
                      split( ' ', $attr{$name}{"rg_passPresenceTo"} );

                    foreach my $object (@linkedObjects) {
                        if (
                               defined( $defs{$object} )
                            && $defs{$object} ne $name
                            && defined( $defs{$object}{TYPE} )
                            && (   $defs{$object}{TYPE} eq "ROOMMATE"
                                || $defs{$object}{TYPE} eq "GUEST" )
                            && defined( $defs{$object}{READINGS}{state}{VAL} )
                            && $defs{$object}{READINGS}{state}{VAL} ne "gone"
                            && $defs{$object}{READINGS}{state}{VAL} ne "none"
                          )
                        {
                            fhem("set $object $newstate");
                        }
                    }
                }
            }

            # clear readings if guest is gone
            if ( $newstate eq "none" ) {
                readingsBulkUpdate( $hash, "lastArrival", "-" )
                  if ( defined( $hash->{READINGS}{lastArrival}{VAL} ) );
                readingsBulkUpdate( $hash, "lastAwake", "-" )
                  if ( defined( $hash->{READINGS}{lastAwake}{VAL} ) );
                readingsBulkUpdate( $hash, "lastDurAbsence", "-" )
                  if ( defined( $hash->{READINGS}{lastDurAbsence}{VAL} ) );
                readingsBulkUpdate( $hash, "lastDurSleep", "-" )
                  if ( defined( $hash->{READINGS}{lastDurSleep}{VAL} ) );
                readingsBulkUpdate( $hash, "lastLocation", "-" )
                  if ( defined( $hash->{READINGS}{lastLocation}{VAL} ) );
                readingsBulkUpdate( $hash, "lastSleep", "-" )
                  if ( defined( $hash->{READINGS}{lastSleep}{VAL} ) );
                readingsBulkUpdate( $hash, "lastMood", "-" )
                  if ( defined( $hash->{READINGS}{lastMood}{VAL} ) );
                readingsBulkUpdate( $hash, "location", "-" )
                  if ( defined( $hash->{READINGS}{location}{VAL} ) );
                readingsBulkUpdate( $hash, "mood", "-" )
                  if ( defined( $hash->{READINGS}{mood}{VAL} ) );
            }

            # calculate duration timers
            GUEST_DurationTimer( $hash, $silent );

            readingsEndUpdate( $hash, 1 );

            # enable or disable AutoGone timer
            if ( $newstate eq "absent" ) {
                GUEST_AutoGone($hash);
            }
            elsif ( $state eq "absent" ) {
                GUEST_RemoveInternalTimer( "AutoGone", $hash );
            }
        }
    }

    # mood
    elsif ( $a[1] eq "mood" ) {
        if ( defined( $a[2] ) && $a[2] ne "" ) {
            Log3 $name, 2, "GUEST set $name mood " . $a[2] if ( !$silent );
            readingsBeginUpdate($hash) if ( !$silent );

            if ( $a[2] eq "toggle" ) {
                if ( defined( $hash->{READINGS}{lastMood}{VAL} ) ) {
                    readingsBulkUpdate( $hash, "mood",
                        $hash->{READINGS}{lastMood}{VAL} );
                    readingsBulkUpdate( $hash, "lastMood", $mood );
                }
            }
            elsif ( $mood ne $a[2] ) {
                readingsBulkUpdate( $hash, "lastMood", $mood )
                  if ( $mood ne "-" );
                readingsBulkUpdate( $hash, "mood", $a[2] );
            }

            readingsEndUpdate( $hash, 1 ) if ( !$silent );
        }
        else {
            return "Invalid 2nd argument, choose one of mood toggle";
        }
    }

    # location
    elsif ( $a[1] eq "location" ) {
        if ( defined( $a[2] ) && $a[2] ne "" ) {
            Log3 $name, 2, "GUEST set $name location " . $a[2] if ( !$silent );

            if ( $location ne $a[2] ) {
                my $searchstring;

                readingsBeginUpdate($hash) if ( !$silent );

                # read attributes
                my @location_home =
                  ( defined( $attr{$name}{"rg_locationHome"} ) )
                  ? split( ' ', $attr{$name}{"rg_locationHome"} )
                  : ("home");

                my @location_underway =
                  ( defined( $attr{$name}{"rg_locationUnderway"} ) )
                  ? split( ' ', $attr{$name}{"rg_locationUnderway"} )
                  : ("underway");

                my @location_wayhome =
                  ( defined( $attr{$name}{"rg_locationWayhome"} ) )
                  ? split( ' ', $attr{$name}{"rg_locationWayhome"} )
                  : ("wayhome");

                $searchstring = quotemeta($location);
                readingsBulkUpdate( $hash, "lastLocation", $location )
                  if ( $location ne "wayhome"
                    && !grep( m/^$searchstring$/, @location_underway ) );
                readingsBulkUpdate( $hash, "location", $a[2] )
                  if ( $a[2] ne "wayhome" );

                # wayhome detection
                $searchstring = quotemeta($location);
                if (
                    (
                        $a[2] eq "wayhome"
                        || grep( m/^$searchstring$/, @location_wayhome )
                    )
                    && ( $presence eq "absent" )
                  )
                {
                    Log3 $name, 3,
                      "GUEST $name: on way back home from $location";
                    readingsBulkUpdate( $hash, "wayhome", "1" )
                      if ( !defined( $hash->{READINGS}{wayhome}{VAL} )
                        || $hash->{READINGS}{wayhome}{VAL} ne "1" );
                }

                readingsEndUpdate( $hash, 1 ) if ( !$silent );

                # auto-updates
                $searchstring = quotemeta( $a[2] );
                if (
                    (
                        $a[2] eq "home"
                        || grep( m/^$searchstring$/, @location_home )
                    )
                    && $state ne "home"
                    && $state ne "gotosleep"
                    && $state ne "asleep"
                    && $state ne "awoken"
                    && $state ne "initialized"
                  )
                {
                    Log3 $name, 4,
                      "GUEST $name: implicit state change caused by location "
                      . $a[2];
                    GUEST_Set( $hash, $name, "silentSet", "state", "home" );
                }
                elsif (
                    (
                        $a[2] eq "underway"
                        || grep( m/^$searchstring$/, @location_underway )
                    )
                    && $state ne "gone"
                    && $state ne "none"
                    && $state ne "absent"
                    && $state ne "initialized"
                  )
                {
                    Log3 $name, 4,
                      "GUEST $name: implicit state change caused by location "
                      . $a[2];
                    GUEST_Set( $hash, $name, "silentSet", "state", "absent" );
                }
            }
        }
        else {
            return "Invalid 2nd argument, choose one of location ";
        }
    }

    # return usage hint
    else {
        return $usage;
    }

    return undef;
}

############################################################################################################
#
#   Begin of helper functions
#
############################################################################################################

###################################
sub GUEST_AutoGone($;$) {
    my ( $mHash, @a ) = @_;
    my $hash = ( $mHash->{HASH} ) ? $mHash->{HASH} : $mHash;
    my $name = $hash->{NAME};

    GUEST_RemoveInternalTimer( "AutoGone", $hash );

    if ( defined( $hash->{READINGS}{state}{VAL} )
        && $hash->{READINGS}{state}{VAL} eq "absent" )
    {
        my ( $date, $time, $y, $m, $d, $hour, $min, $sec, $timestamp,
            $timeDiff );
        my $timestampNow = gettimeofday();
        my $timeout      = (
            defined( $attr{$name}{rg_autoGoneAfter} )
            ? $attr{$name}{rg_autoGoneAfter}
            : "16"
        );

        ( $date, $time ) = split( ' ', $hash->{READINGS}{state}{TIME} );
        ( $y,    $m,   $d )   = split( '-', $date );
        ( $hour, $min, $sec ) = split( ':', $time );
        $m -= 01;
        $timestamp = timelocal( $sec, $min, $hour, $d, $m, $y );
        $timeDiff = $timestampNow - $timestamp;

        if ( $timeDiff >= $timeout * 3600 ) {
            Log3 $name, 3,
              "GUEST $name: AutoGone timer changed state to 'gone'";
            GUEST_Set( $hash, $name, "silentSet", "state", "gone" );
        }
        else {
            my $runtime = $timestamp + $timeout * 3600;
            Log3 $name, 4, "GUEST $name: AutoGone timer scheduled: $runtime";
            GUEST_InternalTimer( "AutoGone", $runtime, "GUEST_AutoGone", $hash,
                1 );
        }
    }

    return undef;
}

###################################
sub GUEST_DurationTimer($;$) {
    my ( $mHash, @a ) = @_;
    my $hash         = ( $mHash->{HASH} ) ? $mHash->{HASH} : $mHash;
    my $name         = $hash->{NAME};
    my $state        = ( $hash->{READINGS}{state}{VAL} ) ? $hash->{READINGS}{state}{VAL} : "initialized";
    my $silent       = ( defined( $a[0] ) && $a[0] eq "1" ) ? 1 : 0;
    my $timestampNow = gettimeofday();
    my $diff;
    my $durPresence = "0";
    my $durAbsence  = "0";
    my $durSleep    = "0";

    GUEST_RemoveInternalTimer( "DurationTimer", $hash );

    # presence timer
    if ( defined( $hash->{READINGS}{presence}{VAL} )
        && $hash->{READINGS}{presence}{VAL} eq "present" )
    {
        if ( defined( $hash->{READINGS}{lastArrival}{VAL} )
            && $hash->{READINGS}{lastArrival}{VAL} ne "-" )
        {
            $diff =
              $timestampNow -
              GUEST_Datetime2Timestamp( $hash->{READINGS}{lastArrival}{VAL} );
            $durPresence = int( $diff / 60 );
        }
    }

    # absence timer
    if (   defined( $hash->{READINGS}{presence}{VAL} )
        && $hash->{READINGS}{presence}{VAL} eq "absent"
        && defined( $hash->{READINGS}{state}{VAL} )
        && $hash->{READINGS}{state}{VAL} eq "absent" )
    {
        if ( defined( $hash->{READINGS}{lastDeparture}{VAL} )
            && $hash->{READINGS}{lastDeparture}{VAL} ne "-" )
        {
            $diff =
              $timestampNow -
              GUEST_Datetime2Timestamp( $hash->{READINGS}{lastDeparture}{VAL} );
            $durAbsence = int( $diff / 60 );
        }
    }

    # sleep timer
    if ( defined( $hash->{READINGS}{state}{VAL} )
        && $hash->{READINGS}{state}{VAL} eq "asleep" )
    {
        if ( defined( $hash->{READINGS}{lastSleep}{VAL} )
            && $hash->{READINGS}{lastSleep}{VAL} ne "-" )
        {
            $diff =
              $timestampNow -
              GUEST_Datetime2Timestamp( $hash->{READINGS}{lastSleep}{VAL} );
            $durSleep = int( $diff / 60 );
        }
    }

    readingsBeginUpdate($hash) if ( !$silent );
    readingsBulkUpdate( $hash, "durTimerPresence", $durPresence )
      if ( !defined( $hash->{READINGS}{durTimerPresence}{VAL} )
        || $hash->{READINGS}{durTimerPresence}{VAL} ne $durPresence );
    readingsBulkUpdate( $hash, "durTimerAbsence", $durAbsence )
      if ( !defined( $hash->{READINGS}{durTimerAbsence}{VAL} )
        || $hash->{READINGS}{durTimerAbsence}{VAL} ne $durAbsence );
    readingsBulkUpdate( $hash, "durTimerSleep", $durSleep )
      if ( !defined( $hash->{READINGS}{durTimerSleep}{VAL} )
        || $hash->{READINGS}{durTimerSleep}{VAL} ne $durSleep );
    readingsEndUpdate( $hash, 1 ) if ( !$silent );

    GUEST_InternalTimer( "DurationTimer", $timestampNow + 60,
        "GUEST_DurationTimer", $hash, 1 )
      if ( $state ne "none" );

    return undef;
}

###################################
sub GUEST_TimeDiff($$) {
    my ( $datetimeNow, $datetimeOld ) = @_;

    my $timestampNow = GUEST_Datetime2Timestamp($datetimeNow);
    my $timestampOld = GUEST_Datetime2Timestamp($datetimeOld);
    my $timeDiff     = $timestampNow - $timestampOld;
    my $hours        = ( $timeDiff < 3600 ? 0 : int( $timeDiff / 3600 ) );
    $timeDiff -= ( $hours == 0 ? 0 : ( $hours * 3600 ) );
    my $minutes = ( $timeDiff < 60 ? 0 : int( $timeDiff / 60 ) );
    my $seconds = $timeDiff % 60;

    $hours   = "0" . $hours   if ( $hours < 10 );
    $minutes = "0" . $minutes if ( $minutes < 10 );
    $seconds = "0" . $seconds if ( $seconds < 10 );

    return "$hours:$minutes:$seconds";
}

###################################
sub GUEST_Datetime2Timestamp($) {
    my ($datetime) = @_;

    my ( $date, $time, $y, $m, $d, $hour, $min, $sec, $timestamp );

    ( $date, $time ) = split( ' ', $datetime );
    ( $y,    $m,   $d )   = split( '-', $date );
    ( $hour, $min, $sec ) = split( ':', $time );
    $m -= 01;
    $timestamp = timelocal( $sec, $min, $hour, $d, $m, $y );

    return $timestamp;
}

###################################
sub GUEST_InternalTimer($$$$$) {
    my ( $modifier, $tim, $callback, $hash, $waitIfInitNotDone ) = @_;

    my $mHash;
    if ( $modifier eq "" ) {
        $mHash = $hash;
    }
    else {
        my $timerName = $hash->{NAME} . "_" . $modifier;
        if ( exists( $hash->{TIMER}{$timerName} ) ) {
            $mHash = $hash->{TIMER}{$timerName};
        }
        else {
            $mHash = {
                HASH     => $hash,
                NAME     => $hash->{NAME} . "_" . $modifier,
                MODIFIER => $modifier
            };
            $hash->{TIMER}{$timerName} = $mHash;
        }
    }
    InternalTimer( $tim, $callback, $mHash, $waitIfInitNotDone );
}

###################################
sub GUEST_RemoveInternalTimer($$) {
    my ( $modifier, $hash ) = @_;

    my $timerName = $hash->{NAME} . "_" . $modifier;
    if ( $modifier eq "" ) {
        RemoveInternalTimer($hash);
    }
    else {
        my $mHash = $hash->{TIMER}{$timerName};
        if ( defined($mHash) ) {
            delete $hash->{TIMER}{$timerName};
            RemoveInternalTimer($mHash);
        }
    }
}

###################################
sub GUEST_StartInternalTimers($$) {
    my ($hash) = @_;

    GUEST_AutoGone($hash);
    GUEST_DurationTimer($hash);
}

1;

=pod
=begin html

<a name="GUEST"></a>
<h3>GUEST</h3>
<ul>

  <a name="GUESTdefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;rg_GuestName&gt; GUEST [&lt;device name of resident group&gt;]</code>
    <br><br>

  Provides a special dummy device to represent a guest of your home.<br>
  Based on the current state and other readings, you may trigger other actions within FHEM.<br><br>
  Used by superior module <a href="#RESIDENTS">RESIDENTS</a> but may also be used stand-alone.<br><br>

    Example:<br>
    <ul><code>
       # Standalone<br>
       define rg_Guest GUEST
       <br><br>
       # Typical group member<br>
       define rg_Guest GUEST rgr_Residents                  # to be member of resident group rgr_Residents
       <br><br>
       # Member of multiple groups<br>
       define rg_Guest GUEST rgr_Residents,rgr_Guests       # to be member of resident group rgr_Residents and rgr_Guests
    </code></ul>
  </ul><br>

  <ul>Please note the RESIDENTS group device needs to be existing before a GUEST device can become a member of it.</ul><br>
  <br>
  <br>

  <a name="GUESTset"></a>
  <b>Set</b>
  <ul>
    <code>set &lt;rg_GuestName&gt; &lt;command&gt; [&lt;parameter&gt;]</code>
    <br><br>
    Currently, the following commands are defined.<br>
    <ul>
      <li><b>location</b> &nbsp;&nbsp;-&nbsp;&nbsp; sets reading 'location'; see attribute rg_locations to adjust list shown in FHEMWEB</li>
      <li><b>mood</b> &nbsp;&nbsp;-&nbsp;&nbsp; sets reading 'mood'; see attribute rg_moods to adjust list shown in FHEMWEB</li>
      <li><b>state</b> &nbsp;&nbsp;home,gotosleep,asleep,awoken,absent,none&nbsp;&nbsp; switch between states; see attribute rg_states to adjust list shown in FHEMWEB</li>
    </ul>
  </ul>

<br><br>
  <ul>
    <u>Possible states and their meaning</u><br><br>
    <ul>
      This module differs between 6 states:<br><br>

      <ul>
      <li><b>home</b> - individual is present at home and awake</li>
      <li><b>gotosleep</b> - individual is on it's way to bed</li>
      <li><b>asleep</b> - individual is currently sleeping</li>
      <li><b>awoken</b> - individual just woke up from sleep</li>
      <li><b>absent</b> - individual is not present at home but will be back shortly</li>
      <li><b>none</b> - guest device is disabled</li>
      </ul>

    </ul>
  </ul>
  <br>
  <br>

  <ul>
    <u>Presence correlation to location</u><br><br>
    <ul>
      Under specific circumstances, changing state will automatically change reading 'location' as well.<br>
      <br>
      Whenever presence state changes from 'absent' to 'present', the location is set to 'home'. If attribute rg_locationHome was defined, first location from it will be used as home location.<br>
      <br>
      Whenever presence state changes from 'present' to 'absent', the location is set to 'underway'. If attribute rg_locationUnderway was defined, first location from it will be used as underway location.
    </ul>
  </ul>
  <br>
  <br>

  <ul>
    <u>Auto Gone</u><br><br>
    <ul>
      Whenever an individual is set to 'absent', a trigger is started to automatically change state to 'gone' after a specific timeframe.<br>
      Default value is 16 hours.<br>
      <br>
      This behaviour can be customized by attribute rg_autoGoneAfter.
    </ul>
  </ul>
  <br>
  <br>

  <ul>
    <u>Synchronizing presence with other ROOMMATE or GUEST devices</u><br><br>
    <ul>
      If you always leave or arrive at your house together with other roommates or guests, you may enable a synchronization of your presence state for certain individuals.<br>
      By setting attribute rg_passPresenceTo, those individuals will follow your presence state changes to 'home', 'absent' or 'gone' as you do them with your own device.<br>
      <br>
      Please note that individuals with current state 'none' or 'gone' (in case of roommates) will not be touched.
    </ul>
  </ul>
  <br>
  <br>

  <ul>
    <u>Location correlation to state</u><br><br>
    <ul>
      Under specific circumstances, changing location will have an effect on the actual state as well.<br>
      <br>
      Whenever location is set to 'home', the state is set to 'home' if prior presence state was 'absent'. If attribute rg_locationHome was defined, all of those locations will trigger state change to 'home' as well.<br>
      <br>
      Whenever location is set to 'underway', the state is set to 'absent' if prior presence state was 'present'. If attribute rg_locationUnderway was defined, all of those locations will trigger state change to 'absent' as well. Those locations won't appear in reading 'lastLocation'.<br>
      <br>
      Whenever location is set to 'wayhome', the reading 'wayhome' is set to '1' if current presence state is 'absent'. If attribute rg_locationWayhome was defined, LEAVING one of those locations will set reading 'wayhome' to '1' as well. So you actually have implicit and explicit options to trigger wayhome.<br>
      Arriving at home will reset the value of 'wayhome' to '0'.<br>
      <br>
      If you are using the <a href="#GEOFANCY">GEOFANCY</a> module, you can easily have your location updated with GEOFANCY events by defining a simple NOTIFY-trigger like this:<br>
      <br>
      <code>
      define n_rg_Guest.location notify geofancy:currLoc_Guest.* set rg_Guest location $EVTPART1
      </code><br>
      <br>
      By defining geofencing zones called 'home' and 'wayhome' in the iOS app, you automatically get all the features of automatic state changes described above.
    </ul>
  </ul>
  <br>
  <br>

  <a name="GUESTattr"></a>
  <b>Attributes</b><br>
  <ul><ul>
    <li><b>rg_autoGoneAfter</b> - hours after which state should be auto-set to 'gone' when current state is 'absent'; defaults to 16 hours</li>
    <li><b>rg_locationHome</b> - locations matching these will be treated as being at home; first entry reflects default value to be used with state correlation; separate entries by space; defaults to 'home'</li>
    <li><b>rg_locationUnderway</b> - locations matching these will be treated as being underway; first entry reflects default value to be used with state correlation; separate entries by comma or space; defaults to "underway"</li>
    <li><b>rg_locationWayhome</b> - leaving a location matching these will set reading wayhome to 1; separate entries by space; defaults to "wayhome"</li>
    <li><b>rg_locations</b> - list of locations ot be shown in FHEMWEB; separate entries by comma only and do NOT use spaces</li>
    <li><b>rg_moodDefault</b> - the mood that should be set after arriving at home or changing state from awoken to home</li>
    <li><b>rg_moodSleepy</b> - the mood that should be set if state was changed to gotosleep or awoken</li>
    <li><b>rg_moods</b> - list of moods to be shown in FHEMWEB; separate entries by comma only and do NOT use spaces</li>
    <li><b>rg_passPresenceTo</b> - synchronize presence state with other GUEST or GUEST devices; separte devices by space</li>
    <li><b>rg_realname</b> - whenever GUEST wants to use the realname it uses the value of attribute alias or group; defaults to group</li>
    <li><b>rg_showAllStates</b> - states 'asleep' and 'awoken' are hidden by default to allow simple gotosleep process via devStateIcon; defaults to 0</li>
    <li><b>rg_states</b> - list of states ot be shown in FHEMWEB; separate entries by comma only and do NOT use spaces; unsupported states will lead to errors though</li>
  </ul></ul>
  <br>
  <br>

  <br>
  <b>Generated Readings/Events:</b><br>
  <ul><ul>
    <li><b>durTimerAbsence</b> - timer to show the duration of absence from home in minutes</li>
    <li><b>durTimerPresence</b> - timer to show the duration of presence at home in minutes</li>
    <li><b>durTimerSleep</b> - timer to show the duration of sleep in minutes</li>
    <li><b>lastArrival</b> - timestamp of last arrival at home</li>
    <li><b>lastAwake</b> - timestamp of last sleep cycle end</li>
    <li><b>lastDeparture</b> - timestamp of last departure from home</li>
    <li><b>lastDurAbsence</b> - duration of last absence from home in following format: hours:minutes:seconds</li>
    <li><b>lastDurPresence</b> - duration of last presence at home in following format: hours:minutes:seconds</li>
    <li><b>lastDurSleep</b> - duration of last sleep in following format: hours:minutes:seconds</li>
    <li><b>lastLocation</b> - the prior location</li>
    <li><b>lastMood</b> - the prior mood</li>
    <li><b>lastSleep</b> - timestamp of last sleep cycle begin</li>
    <li><b>lastState</b> - the prior state</li>
    <li><b>location</b> - the current location</li>
    <li><b>presence</b> - reflects the home presence state, depending on value of reading 'state' (can be 'present' or 'absent')</li>
    <li><b>mood</b> - the current mood</li>
    <li><b>state</b> - reflects the current state</li>
    <li><b>wayhome</b> - depending on current location, it can become '1' if individual is on his/her way back home</li><br>
    <br>
    The following readings will be set to '-' if state was changed to 'none':<br>
    lastArrival, lastDurAbsence, lastLocation, lastMood, location, mood
  </ul></ul>

</ul>

=end html

=begin html_DE

<a name="GUEST"></a>
<h3>GUEST</h3>
<ul>
Eine deutsche Version der Dokumentation ist derzeit nicht vorhanden.
Die englische Version ist hier zu finden: 
</ul>
<ul>
<a href='http://fhem.de/commandref.html#GUEST'>GUEST</a>
</ul>

=end html_DE

=cut
