# $Id$
##############################################################################
#
#     99_msg.pm
#     Dynamic message and notification routing for FHEM
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
# Version: 1.0.0
#
# Major Version History:
#
# - 1.0.0 - 2015-09-23
# -- First release
#
##############################################################################

package main;
use strict;
use warnings;
use Time::HiRes qw(time);
use Data::Dumper;

no if $] >= 5.017011, warnings => 'experimental::smartmatch';

sub CommandMsg($$;$$);

########################################
sub msg_Initialize($$) {
    my %hash = (
        Fn => "CommandMsg",
        Hlp =>
"[<type>] [<\@device>|<e-mail address>] [<priority>] [|<title>|] <message>",
    );
    $cmds{msg} = \%hash;

    # add attributes for configuration
    no warnings 'qw';
    my @attrList = qw(
      msgCmdAudio
      msgCmdAudioShort
      msgCmdAudioShortPrio
      msgCmdLight
      msgCmdLightHigh
      msgCmdLightLow
      msgCmdMail
      msgCmdMailHigh
      msgCmdMailLow
      msgCmdPush
      msgCmdPushHigh
      msgCmdPushLow
      msgCmdScreen
      msgCmdScreenHigh
      msgCmdScreenLow
      msgFwPrioAbsentAudio
      msgFwPrioAbsentLight
      msgFwPrioAbsentScreen
      msgFwPrioEmergencyAudio
      msgFwPrioEmergencyLight
      msgFwPrioEmergencyPush
      msgFwPrioEmergencyScreen
      msgFwPrioGoneAudio
      msgFwPrioGoneLight
      msgFwPrioGoneScreen
      msgLocationDevs
      msgPriorityAudio:-2,-1,0,1,2
      msgPriorityLight:-2,-1,0,1,2
      msgPriorityMail:-2,-1,0,1,2
      msgPriorityPush:-2,-1,0,1,2
      msgPriorityScreen:-2,-1,0,1,2
      msgPriorityText:-2,-1,0,1,2
      msgResidentsDev
      msgSwitcherDev
      msgThPrioHigh:-2,-1,0,1,2
      msgThPrioNormal:-2,-1,0,1,2
      msgThPrioAudioEmergency:-2,-1,0,1,2
      msgThPrioAudioHigh:-2,-1,0,1,2
      msgThPrioTextEmergency:-2,-1,0,1,2
      msgThPrioTextNormal:-2,-1,0,1,2
      msgThPrioGwEmergency:-2,-1,0,1,2
      msgTitleAudio
      msgTitleAudioShort
      msgTitleAudioShortPrio
      msgTitleLight
      msgTitleLightHigh
      msgTitleLightLow
      msgTitleMail
      msgTitleMailHigh
      msgTitleMailLow
      msgTitlePush
      msgTitlePushHigh
      msgTitlePushLow
      msgTitleScreen
      msgTitleScreenHigh
      msgTitleScreenLow
      msgTitleText
      msgTitleTextHigh
      msgTitleTextLow

    );
    use warnings 'qw';
    $modules{Global}{AttrList} .= " " . join( " ", @attrList );

    # add global attributes
    foreach (
        "msgContactAudio",    "msgContactMail",   "msgContactPush",
        "msgContactScreen",   "msgContactLight",  "msgRecipient",
        "msgRecipientAudio",  "msgRecipientMail", "msgRecipientPush",
        "msgRecipientScreen", "msgRecipientText", "msgRecipientLight",
      )
    {
        addToAttrList($_);
    }
}

########################################
sub CommandMsg($$;$$) {
    my ( $cl, $msg, $testMode ) = @_;
    my $return = "";

    if ( $msg eq "" || $msg =~ /^\?[\s\t]*$/ || $msg eq "help" ) {
        return
"Usage: msg [<type>] [<\@device>|<e-mail address>] [<priority>] [|<title>|] <message>";
    }

    # FHEM module command schema definitions
    my $cmdSchema = {
      'audio' => {

        'AMAD' => {
          'Normal'    => 'set %DEVICE% ttsMsg %MSG%',
          'ShortPrio' => 'set %DEVICE% ttsMsg %MSGSH%',
          'Short'     => 'set %DEVICE% notifySndFile %FILENAME%',
          'defaultValues' => {
            'ShortPrio' => {
              'MSGSH' => 'Achtung!',
            },
          },
        },

        'SONOSPLAYER' => {
          'Normal'    => 'set %DEVICE% Speak %VOLUME% %LANG% |%TITLE%| %MSG%',
          'ShortPrio' => 'set %DEVICE% Speak %VOLUME% %LANG% |%TITLE%| %MSGSH%',
          'Short'     => 'set %DEVICE% Speak %VOLUME% %LANG% |%TITLE%| %MSGSH%',
          'defaultValues' => {
            'Normal' => {
              'VOLUME' => 38,
              'LANG' => 'de',
            },
            'ShortPrio' => {
              'VOLUME' => 33,
              'LANG' => 'de',
              'MSGSH' => 'Achtung!',
            },
            'Short' => {
              'VOLUME' => 28,
              'LANG' => 'de',
              'MSGSH' => '',
            },
          },
        },

      },

      'light' => {

        'HUEDevice' => {
          'Normal'  => '{my \$state=ReadingsVal("%DEVICE%","state","off"); fhem "set %DEVICE% blink 2 1"; fhem "sleep 4;set %DEVICE%:FILTER=state!=$state $state"}',
          'High'    => '{my \$state=ReadingsVal("%DEVICE%","state","off"); fhem "set %DEVICE% blink 10 1"; fhem "sleep 20;set %DEVICE%:FILTER=state!=$state $state"}',
          'Low'     => 'set %DEVICE% alert select',
        },
        
      },

      'mail' => {

        'fhemMsgMail' => {
          'Normal'  => '{system("echo \'%MSG%\' | /usr/bin/mail -s \'%TITLE%\' -t \'%DEVICE%\' -a \'MIME-Version: 1.0\' -a \'Content-Type: text/html; charset=UTF-8\'")}',
          'High'    => '{system("echo \'%MSG%\' | /usr/bin/mail -s \'%TITLE%\' -t \'%DEVICE%\' -a \'MIME-Version: 1.0\' -a \'Content-Type: text/html; charset=UTF-8\' -a \'X-Priority: 1 (Highest)\' -a \'X-MSMail-Priority: High\' -a \'Importance: high\'")}',
          'Low'     => '{system("echo \'%MSG%\' | /usr/bin/mail -s \'%TITLE%\' -t \'%DEVICE%\' -a \'MIME-Version: 1.0\' -a \'Content-Type: text/html; charset=UTF-8\' -a \'X-Priority: 5 (Lowest)\' -a \'X-MSMail-Priority: Low\' -a \'Importance: low\'")}',
        },
        
      },

      'push' => {

        'Fhemapppush' => {
          'Normal'  => 'set %DEVICE% message \'%TITLE%: %MSG%\' %ACTION%',
          'High'    => 'set %DEVICE% message \'%TITLE%: %MSG%\' %ACTION%',
          'Low'     => 'set %DEVICE% message \'%TITLE%: %MSG%\' %ACTION%',
          'defaultValues' => {
            'Normal' => {
              'ACTION'    => '',
            },
            'High' => {
              'ACTION'    => '',
            },
            'Low' => {
              'ACTION'    => '',
            },
          },
        },

        'Pushover' => {
          'Normal'  => 'set %DEVICE% msg \'%TITLE%\' \'%MSG%\' \'%PORECIPIENT%\' %PRIORITY% \'\' %RETRY% %EXPIRE% %URLTITLE% %ACTION%',
          'High'    => 'set %DEVICE% msg \'%TITLE%\' \'%MSG%\' \'%PORECIPIENT%\' %PRIORITY% \'\' %RETRY% %EXPIRE% %URLTITLE% %ACTION%',
          'Low'     => 'set %DEVICE% msg \'%TITLE%\' \'%MSG%\' \'%PORECIPIENT%\' %PRIORITY% \'\' %RETRY% %EXPIRE% %URLTITLE% %ACTION%',
          'defaultValues' => {
            'Normal' => {
              'PORECIPIENT' => '',
              'RETRY'     => '',
              'EXPIRE'    => '',
              'URLTITLE'  => '',
              'ACTION'    => '',
            },
            'High' => {
              'PORECIPIENT' => '',
              'RETRY'     => '120',
              'EXPIRE'    => '600',
              'URLTITLE'  => '',
              'ACTION'    => '',
            },
            'Low' => {
              'PORECIPIENT' => '',
              'RETRY'     => '',
              'EXPIRE'    => '',
              'URLTITLE'  => '',
              'ACTION'    => '',
            },
          },
        },

        'TelegramBot' => {
          'Normal'  => 'set %DEVICE% message %RECIPIENT% %TITLE%: %MSG%',
          'High'    => 'set %DEVICE% message %RECIPIENT% %TITLE%: %MSG%',
          'Low'     => 'set %DEVICE% message %RECIPIENT% %TITLE%: %MSG%',
          'defaultValues' => {
            'Normal' => {
              'TGRECIPIENT' => '',
            },
            'High' => {
              'TGRECIPIENT' => '',
            },
            'Low' => {
              'TGRECIPIENT' => '',
            },
          },
        },

      },

      'screen' => {

        'AMAD' => {
          'Normal'  => 'set %DEVICE% screenMsg %TITLE%: %MSG%',
          'High'    => 'set %DEVICE% screenMsg %TITLE%: %MSG%',
          'Low'     => 'set %DEVICE% screenMsg %TITLE%: %MSG%',
        },

        'ENIGMA2' => {
          'Normal'  => 'set %DEVICE% msg %TYPE% %TIMEOUT% %MSG%',
          'High'    => 'set %DEVICE% msg %TYPE% %TIMEOUT% %MSG%',
          'Low'     => 'set %DEVICE% msg %TYPE% %TIMEOUT% %MSG%',
          'defaultValues' => {
            'Normal' => {
              'TYPE' => 'info',
              'TIMEOUT'     => 8,
            },
            'High' => {
              'TYPE'     => 'attention',
              'TIMEOUT'     => 12,
            },
            'Low' => {
              'TYPE'     => 'message',
              'TIMEOUT'     => 8,
            },
          },
        },

      },
    };

    # default settings
    my $settings = {
      'audio' => {
          'typeEscalation' => {
            'gwUnavailable' => 'text',
            'emergency' => 'text',
            'residentGone' => 'text',
            'residentAbsent' => 'text',
          },
          'title' => 'Announcement',
      },

      'light' => {
          'typeEscalation' => {
            'gwUnavailable' => 'audio',
            'emergency' => 'audio',
            'residentGone' => 'audio',
            'residentAbsent' => 'audio',
          },        
          'title' => 'Announcement',
      },

      'mail' => {
          'title' => 'System Message',
      },

      'push' => {
          'typeEscalation' => {
            'gwUnavailable' => 'mail',
            'emergency' => 'mail',
          },
          'title' => 'System Message',
      },

      'screen' => {
          'typeEscalation' => {
            'gwUnavailable' => 'light',
            'emergency' => 'light',
            'residentGone' => 'light',
            'residentAbsent' => 'light',
          },
          'title' => 'Info',
      },
    };

    ################################################################
    ### extract message details
    ###

    my $types      = "";
    my $recipients = "";
    my $priority   = "";
    my $title      = "-";
    my $advanced   = "";

    my $priorityCat = "";

    # check for message types
    if ( $msg =~
s/^[\s\t]*([a-z,]*!?(screen|light|audio|text|push|mail)[a-z,!|]*)[\s\t]+//
      )
    {
        $types = $1;
    }

    # check for given recipients
    if ( $msg =~
s/^[\s\t]*([!]?(([A-Za-z0-9%+._-])*@([%+a-z0-9A-Z.-]+))[\w,@.!|]*)[\s\t]+//
      )
    {
        $recipients = $1;
    }

    # check for given priority
    if ( $msg =~ s/^[\s\t]*([-+]{0,1}\d+[.\d]*)[\s\t]*// ) {
        $priority = $1;
    }

    # check for given message title
    if ( $msg =~
s/^[\s\t]*\|([\w\süöäß^°!"§$%&\/\\()<>=?´`"+\[\]#*@€]+)\|[\s\t]+//
      )
    {
        $title = $1;
    }

    # check for advanced options
    if ( $msg =~ s/[\s\t]*O(\[\{.*\}\])[\s\t]*$// )
    {
      # Use JSON module if possible
      eval 'use JSON qw( decode_json ); 1';
      if ( !$@ ) {
        $advanced = decode_json( Encode::encode_utf8($1) );
        Log3 "global", 5, "msg: Advanced options\n" . Dumper($advanced);
      } else {
        Log3 "global", 3, "msg: To use advanced options, please install Perl::JSON.";
      }
    }

    ################################################################
    ### command queue
    ###

    $types = "text"
      if ( $types eq "" );
    my $messageSent = 0;
    my $forwarded   = "";
    my %sentTypesPerDevice;
    my $sentCounter    = 0;
    my $messageID      = time();
    my $isTypeOr       = 1;
    my $isRecipientOr  = 1;
    my $hasTypeOr      = 0;
    my $hasRecipientOr = 0;
    $recipients = "\@global" if ( $recipients eq "" );

    my @typesOr = split( /\|/, $types );
    $hasTypeOr = 1 if ( scalar( grep { defined $_ } @typesOr ) > 1 );
    Log3 "global", 5,
      "msg: typeOr total is " . scalar( grep { defined $_ } @typesOr )
      if ( $testMode ne "1" );

    for (
        my $iTypesOr = 0 ;
        $iTypesOr < scalar( grep { defined $_ } @typesOr ) ;
        $iTypesOr++
      )
    {
        Log3 "global", 5,
          "msg: start typeOr loop for type(s) $typesOr[$iTypesOr]"
          if ( $testMode ne "1" );

        my @type = split( /,/, $typesOr[$iTypesOr] );
        for ( my $i = 0 ; $i < scalar( grep { defined $_ } @type ) ; $i++ ) {
            Log3 "global", 5, "msg: running loop for type $type[$i]"
              if ( $testMode ne "1" );
            last if ( !defined( $type[$i] ) );

            my $forceType = 0;
            if ( $type[$i] =~ s/^!(.*)// ) {
                $type[$i] = $1;
                $forceType = 1;
            }

            # check for correct type
            my @msgCmds =
              ( "screen", "light", "audio", "text", "push", "mail" );
            if ( !( $type[$i] ~~ @msgCmds ) ) {
                $return .= "Unknown message type $type[$i]\n";
                next;
            }

            ################################################################
            ### recipient loop
            ###

            my @recipientsOr = split( /\|/, $recipients );
            $hasRecipientOr = 1
              if ( scalar( grep { defined $_ } @recipientsOr ) > 1 );
            Log3 "global", 5,
              "msg: recipientOr total is "
              . scalar( grep { defined $_ } @recipientsOr )
              if ( $testMode ne "1" );

            for (
                my $iRecipOr = 0 ;
                $iRecipOr < scalar( grep { defined $_ } @recipientsOr ) ;
                $iRecipOr++
              )
            {
                Log3 "global", 5,
"msg: start recipientsOr loop for recipient(s) $recipientsOr[$iRecipOr]"
                  if ( $testMode ne "1" );

                my @recipient = split( /,/, $recipientsOr[$iRecipOr] );
                foreach my $device (@recipient) {

                    Log3 "global", 5, "msg: running loop for device $device"
                      if ( $testMode ne "1" );

                    my $messageSentDev = 0;
                    my $gatewayDevs    = "";
                    my $forceDevice    = 0;

                    # for device type
                    my $deviceType = "device";
                    if ( $device =~
                        /^(([A-Za-z0-9%+._-])+[@]+([%+a-z0-9A-Z.-]*))$/ )
                    {
                        $gatewayDevs = $1;
                        $deviceType  = "email";
                    }
                    elsif ( $device =~ s/^!@?(.*)// ) {
                        $device      = $1;
                        $forceDevice = 1;
                    }
                    elsif ( $device =~ s/^@(.*)// ) {
                        $device = $1;
                    }

                    # FATAL ERROR: device does not exist
                    if ( !defined( $defs{$device} )
                        && $deviceType eq "device" )
                    {
                        $return .= "Device $device does not exist\n";
                        Log3 "global", 5, "msg $device: Device does not exist"
                          if ( $testMode ne "1" );

                        my $regex1 =
                          "\\s*!?@?" . $device . "[,|]";    # at the beginning
                        my $regex2 = "[,|]!?@?" . $device . "\\s*";  # at the end
                        my $regex3 =
                          ",!?@?" . $device . ",";    # in the middle with comma
                        my $regex4 =
                            "[\|,]!?@?"
                          . $device
                          . "[\|,]";    # in the middle with pipe and/or comma

                        $recipients =~ s/^$regex1//gi;
                        $recipients =~ s/$regex2$/|/gi;
                        $recipients =~ s/$regex3/,/gi;
                        $recipients =~ s/$regex4/|/gi;

                        next;
                    }

                    my $typeUc      = ucfirst( $type[$i] );
                    my $catchall    = 0;
                    my $useLocation = 0;

                    my $logDevice;
                    $logDevice = "global";
                    $logDevice = $device
                      if (
                        # look for direct
                        AttrVal(
                            $device, "verbose",

                            #look for indirect
                            AttrVal(
                                AttrVal( $device, "msgRecipient$typeUc", "" ),
                                "verbose",

                                #look for indirect general
                                AttrVal(
                                    AttrVal( $device, "msgRecipient", "" ),
                                    "verbose",

                                    # no verbose found
                                    ""
                                )
                            )
                        ) ne ""
                      );

                    ################################################################
                    ### get target information from device location
                    ###

                    # search for location references
                    my @locationDevs;
                    @locationDevs = split(
                        /,/,

                        # look for direct
                        AttrVal(
                            $device, "msgLocationDevs",

                            #look for indirect
                            AttrVal(
                                AttrVal( $device, "msgRecipient$typeUc", "" ),
                                "msgLocationDevs",

                                # look for indirect general
                                AttrVal(
                                    AttrVal( $device, "msgRecipient", "" ),
                                    "msgLocationDevs",

                                    # look for global direct
                                    AttrVal(
                                        "global", "msgLocationDevs",

                                        #look for global indirect
                                        AttrVal(
                                            AttrVal(
                                                "global",
                                                "msgRecipient$typeUc", ""
                                            ),
                                            "msgLocationDevs",

                                            # look for global indirect general
                                            AttrVal(
                                                AttrVal(
                                                    "global", "msgRecipient",
                                                    ""
                                                ),
                                                "msgLocationDevs",

                                                # no locations defined
                                                ""
                                            )
                                        )
                                    )
                                )
                            )
                        )
                    );

                    if ( $deviceType eq "device" ) {

                        # get device location
                        my $deviceLocation =

                          # look for direct
                          ReadingsVal(
                            $device, "location",

                            # look for indirect
                            ReadingsVal(
                                AttrVal( $device, "msgRecipient$typeUc", "" ),
                                "location",

                                # look for indirect general
                                ReadingsVal(
                                    AttrVal( $device, "msgRecipient", "" ),
                                    "location",

                                    # no location found
                                    ""
                                )
                            )
                          );

                        my $locationDev = "";
                        if ( $deviceLocation ne "" ) {

                            # lookup matching location
                            foreach (@locationDevs) {
                                my $lName =
                                  AttrVal( $_, "msgLocationName", "" );
                                if ( $lName ne "" && $lName eq $deviceLocation )
                                {
                                    $locationDev = $_;
                                    last;
                                }
                            }

                            # look for gateway device
                            $gatewayDevs =

                              # look for direct
                              AttrVal(
                                $locationDev, "msgContact$typeUc",

                                # look for indirect
                                AttrVal(
                                    AttrVal(
                                        $locationDev, "msgRecipient$typeUc",
                                        ""
                                    ),
                                    "msgContact$typeUc",

                                    # look for indirect general
                                    AttrVal(
                                        AttrVal(
                                            $locationDev, "msgRecipient",
                                            ""
                                        ),
                                        "msgContact$typeUc",

                                        # no contact found
                                        ""
                                    )
                                )
                              );

                            # at least one of the location gateways needs to
                            # be available. Otherwise we fall back to
                            # non-location contacts
                            if ( $gatewayDevs ne "" ) {

                                foreach
                                  my $gatewayDevOr ( split /\|/, $gatewayDevs )
                                {

                                    foreach my $gatewayDev ( split /,/,
                                        $gatewayDevOr )
                                    {

                                        if (   $type[$i] ne "mail"
                                            && !defined( $defs{$gatewayDev} )
                                            && $deviceType eq "device" )
                                        {
                                            $useLocation = 2
                                              if ( $useLocation == 0 );
                                        }
                                        elsif (
                                            $type[$i] ne "mail"
                                            && AttrVal( $gatewayDev, "disable",
                                                "0" ) eq "1"
                                          )
                                        {
                                            $useLocation = 2
                                              if ( $useLocation == 0 );
                                        }
                                        elsif (
                                            $type[$i] ne "mail"
                                            && (
                                                AttrVal(
                                                    $gatewayDev, "disable",
                                                    "0"
                                                ) eq "1"
                                                || ReadingsVal(
                                                    $gatewayDev, "power",
                                                    "on"
                                                ) eq "off"
                                                || ReadingsVal(
                                                    $gatewayDev, "presence",
                                                    "present"
                                                ) eq "absent"
                                                || ReadingsVal(
                                                    $gatewayDev, "presence",
                                                    "appeared"
                                                ) eq "disappeared"
                                                || ReadingsVal(
                                                    $gatewayDev, "state",
                                                    "present"
                                                ) eq "absent"
                                                || ReadingsVal(
                                                    $gatewayDev, "state",
                                                    "connected"
                                                ) eq "unauthorized"
                                                || ReadingsVal(
                                                    $gatewayDev, "state",
                                                    "connected"
                                                ) eq "disconnected"
                                                || ReadingsVal(
                                                    $gatewayDev, "state",
                                                    "reachable"
                                                ) eq "unreachable"
                                                || ReadingsVal(
                                                    $gatewayDev, "available",
                                                    "1"
                                                ) eq "0"
                                                || ReadingsVal(
                                                    $gatewayDev, "available",
                                                    "yes"
                                                ) eq "no"
                                                || ReadingsVal(
                                                    $gatewayDev, "reachable",
                                                    "1"
                                                ) eq "0"
                                                || ReadingsVal(
                                                    $gatewayDev, "reachable",
                                                    "yes"
                                                ) eq "no"
                                            )
                                          )
                                        {
                                            $useLocation = 2
                                              if ( $useLocation == 0 );
                                        }
                                        else {
                                            $useLocation = 1;
                                        }

                                    }

                                }

                                # use gatewayDevs from location only
                                # if it has been confirmed to be available
                                if ( $useLocation == 1 ) {
                                    Log3 $logDevice, 4,
"msg $device: Matching location definition found.";
                                }
                                else {
                                    $gatewayDevs = "";
                                }
                            }
                        }
                    }

                    ################################################################
                    ### given device name is already a gateway device itself
                    ###
                    
                    my $deviceType2 = defined($defs{$device}) ? $defs{$device}{TYPE} : "";

                    if (
                           $gatewayDevs eq ""
                        && $deviceType2 ne ""
                        && (
                          ( $type[$i] eq "audio"  && defined($cmdSchema->{ $type[$i] }{$deviceType2}) ) ||
                          ( $type[$i] eq "light"  && defined($cmdSchema->{ $type[$i] }{$deviceType2}) ) ||
                          ( $type[$i] eq "push"   && defined($cmdSchema->{ $type[$i] }{$deviceType2}) ) ||
                          ( $type[$i] eq "screen" && defined($cmdSchema->{ $type[$i] }{$deviceType2}) )
                        )
                      )
                    {
                        Log3 $logDevice, 4,
"msg $device: This recipient seems to be a gateway device itself. Still checking for any delegates ...";

                        $gatewayDevs =

                          # look for direct
                          AttrVal(
                            $device,
                            "msgContact$typeUc",

                            # look for indirect
                            AttrVal(
                                AttrVal( $device, "msgRecipient$typeUc", "" ),
                                "msgContact$typeUc",

                                # look for indirect general
                                AttrVal(
                                    AttrVal( $device, "msgRecipient", "" ),
                                    "msgContact$typeUc",

                                    # self
                                    $device
                                )
                            )
                          );

                    }

                    ################################################################
                    ### get target information from device
                    ###

                    elsif ( $deviceType eq "device" && $gatewayDevs eq "" ) {

                        # look for gateway device
                        $gatewayDevs =

                          # look for direct
                          AttrVal(
                            $device, "msgContact$typeUc",

                            #look for indirect
                            AttrVal(
                                AttrVal( $device, "msgRecipient$typeUc", "" ),
                                "msgContact$typeUc",

                                #look for indirect general
                                AttrVal(
                                    AttrVal( $device, "msgRecipient", "" ),
                                    "msgContact$typeUc",

                                    # no contact found
                                    ""
                                )
                            )
                          );

                        # fallback/catchall
                        if ( $gatewayDevs eq "" ) {
                            $catchall = 1
                              if ( $device ne "global" );

                            Log3 $logDevice, 5,
"msg $device:			(No $typeUc contact defined, trying global instead)"
                              if ( $catchall == 1 );

                            $gatewayDevs =

                              # look for direct
                              AttrVal(
                                "global", "msgContact$typeUc",

                                #look for indirect
                                AttrVal(
                                    AttrVal(
                                        "global", "msgRecipient$typeUc", ""
                                    ),
                                    "msgContact$typeUc",

                                    #look for indirect general
                                    AttrVal(
                                        AttrVal( "global", "msgRecipient", "" ),
                                        "msgContact$typeUc",

                                        # no contact found
                                        ""
                                    )
                                )
                              );
                        }
                    }

                    # Find priority if none was explicitly specified
                    my $loopPriority = $priority;
                    $loopPriority =

                      # look for direct
                      AttrVal(
                        $device, "msgPriority$typeUc",

                        #look for indirect
                        AttrVal(
                            AttrVal( $device, "msgRecipient$typeUc", "" ),
                            "msgPriority$typeUc",

                            #look for indirect general
                            AttrVal(
                                AttrVal( $device, "msgRecipient", "" ),
                                "msgPriority$typeUc",

                                # look for global direct
                                AttrVal(
                                    "global", "msgPriority$typeUc",

                                    #look for global indirect
                                    AttrVal(
                                        AttrVal(
                                            "global", "msgRecipient$typeUc",
                                            ""
                                        ),
                                        "msgPriority$typeUc",

                                        #look for global indirect general
                                        AttrVal(
                                            AttrVal(
                                                "global", "msgRecipient",
                                                ""
                                            ),
                                            "msgPriority$typeUc",

                                            # default
                                            0
                                        )
                                    )
                                )
                            )
                        )
                      ) if ( !$priority );

                    # check for available routes
                    #
                    my %routes;
                    $routes{screen} = 0;
                    $routes{light}  = 0;
                    $routes{audio}  = 0;
                    $routes{text}   = 0;
                    $routes{push}   = 0;
                    $routes{mail}   = 0;

                    if (
                        !defined($testMode)
                        || (   $testMode ne "1"
                            && $testMode ne "2" )
                      )
                    {
                        Log3 $logDevice, 5,
"msg $device: Checking for available routes (triggered by type $type[$i])";

                        $routes{screen} = 1
                          if (
                            $deviceType eq "device"
                            && CommandMsg( "screen",
                                "screen \@$device $priority Routing Test", 1 )
                            eq "ROUTE_AVAILABLE"
                          );

                        $routes{light} = 1
                          if (
                            $deviceType eq "device"
                            && CommandMsg( "light",
                                "light \@$device $priority Routing Test", 1 )
                            eq "ROUTE_AVAILABLE"
                          );

                        $routes{audio} = 1
                          if (
                            $deviceType eq "device"
                            && CommandMsg( "audio",
                                "audio \@$device $priority Routing Test", 1 )
                            eq "ROUTE_AVAILABLE"
                          );

                        if (
                            $deviceType eq "device"
                            && CommandMsg( "push",
                                "push \@$device $priority Routing Test", 1 ) eq
                            "ROUTE_AVAILABLE"
                          )
                        {
                            $routes{push} = 1;
                            $routes{text} = 1;
                        }

                        if (
                            CommandMsg( "mail",
                                "mail \@$device $priority Routing Test", 1 ) eq
                            "ROUTE_AVAILABLE"
                          )
                        {
                            $routes{mail} = 1;
                            $routes{text} = 1;
                        }

                        Log3 $logDevice, 4,
                            "msg $device: Available routes: screen="
                          . $routes{screen}
                          . " light="
                          . $routes{light}
                          . " audio="
                          . $routes{audio}
                          . " text="
                          . $routes{text}
                          . " push="
                          . $routes{push}
                          . " mail="
                          . $routes{mail};
                    }

                    ##################################################
                    ### dynamic routing for text (->push, ->mail)
                    ###
                    if ( $type[$i] eq "text" ) {

                      # user selected emergency priority text threshold
                      my $prioThresTextEmg = 
                          # look for direct
                          AttrVal(
                              $device, "msgThPrioTextEmergency",

                              #look for indirect audio
                              AttrVal(
                                  AttrVal( $device, "msgRecipient$typeUc", "" ),
                                  "msgThPrioTextEmergency",

                                  #look for indirect general
                                  AttrVal(
                                      AttrVal( $device, "msgRecipient", "" ),
                                      "msgThPrioTextEmergency",

                                      # look for global direct
                                      AttrVal(
                                          "global", "msgThPrioTextEmergency",

                                          #look for global indirect type
                                          AttrVal(
                                              AttrVal(
                                                  "global",
                                                  "msgRecipient$typeUc", ""
                                              ),
                                              "msgThPrioTextEmergency",

                                              #look for global indirect general
                                              AttrVal(
                                                  AttrVal(
                                                      "global", "msgRecipient",
                                                      ""
                                                  ),
                                                  "msgThPrioTextEmergency",

                                                  # default
                                                  "2"
                                              )
                                          )
                                      )
                                  )
                              )
                          )
                      ;

                      # user selected low priority text threshold
                      my $prioThresTextNormal = 
                          # look for direct
                          AttrVal(
                              $device, "msgThPrioTextNormal",

                              #look for indirect audio
                              AttrVal(
                                  AttrVal( $device, "msgRecipient$typeUc", "" ),
                                  "msgThPrioTextNormal",

                                  #look for indirect general
                                  AttrVal(
                                      AttrVal( $device, "msgRecipient", "" ),
                                      "msgThPrioTextNormal",

                                      # look for global direct
                                      AttrVal(
                                          "global", "msgThPrioTextNormal",

                                          #look for global indirect type
                                          AttrVal(
                                              AttrVal(
                                                  "global",
                                                  "msgRecipient$typeUc", ""
                                              ),
                                              "msgThPrioTextNormal",

                                              #look for global indirect general
                                              AttrVal(
                                                  AttrVal(
                                                      "global", "msgRecipient",
                                                      ""
                                                  ),
                                                  "msgThPrioTextNormal",

                                                  # default
                                                  "-2"
                                              )
                                          )
                                      )
                                  )
                              )
                          )
                      ;

                     # Decide push and/or e-mail destination based on priorities
                        if (   $loopPriority >= $prioThresTextEmg
                            && $routes{push} == 1
                            && $routes{mail} == 1 )
                        {
                            Log3 $logDevice, 4,
"msg $device: Text routing decision: push+mail(1)";
                            $forwarded .= ","
                              if ( $forwarded ne "" );
                            $forwarded .= "text>push+mail";
                            push @type, "push" if !( "push" ~~ @type );
                            push @type, "mail" if !( "mail" ~~ @type );
                        }
                        elsif ($loopPriority >= $prioThresTextEmg
                            && $routes{push} == 1
                            && $routes{mail} == 0 )
                        {
                            Log3 $logDevice, 4,
                              "msg $device: Text routing decision: push(2)";
                            $forwarded .= ","
                              if ( $forwarded ne "" );
                            $forwarded .= "text>push";
                            push @type, "push" if !( "push" ~~ @type );
                        }
                        elsif ($loopPriority >= $prioThresTextEmg
                            && $routes{push} == 0
                            && $routes{mail} == 1 )
                        {
                            Log3 $logDevice, 4,
                              "msg $device: Text routing decision: mail(3)";
                            $forwarded .= ","
                              if ( $forwarded ne "" );
                            $forwarded .= "text>mail";
                            push @type, "mail" if !( "mail" ~~ @type );
                        }
                        elsif ( $loopPriority >= $prioThresTextNormal && $routes{push} == 1 ) {
                            Log3 $logDevice, 4,
                              "msg $device: Text routing decision: push(4)";
                            $forwarded .= ","
                              if ( $forwarded ne "" );
                            $forwarded .= "text>push";
                            push @type, "push" if !( "push" ~~ @type );
                        }
                        elsif ( $loopPriority >= $prioThresTextNormal && $routes{mail} == 1 ) {
                            Log3 $logDevice, 4,
                              "msg $device: Text routing decision: mail(5)";
                            $forwarded .= ","
                              if ( $forwarded ne "" );
                            $forwarded .= "text>mail";
                            push @type, "mail" if !( "mail" ~~ @type );
                        }
                        elsif ( $routes{mail} == 1 ) {
                            Log3 $logDevice, 4,
                              "msg $device: Text routing decision: mail(6)";
                            $forwarded .= ","
                              if ( $forwarded ne "" );
                            $forwarded .= "text>mail";
                            push @type, "mail" if !( "mail" ~~ @type );
                        }
                        elsif ( $routes{push} == 1 ) {
                            Log3 $logDevice, 4,
                              "msg $device: Text routing decision: push(7)";
                            $forwarded .= ","
                              if ( $forwarded ne "" );
                            $forwarded .= "text>push";
                            push @type, "push" if !( "push" ~~ @type );
                        }

                        # FATAL ERROR: routing decision failed
                        else {
                            Log3 $logDevice, 4,
"msg $device: Text routing FAILED - priority=$loopPriority push="
                              . $routes{push}
                              . " mail="
                              . $routes{mail};

                            $return .=
"ERROR: Could not find any Push or Mail contact for device $device - set attributes: msgContactPush | msgContactMail | msgContactText | msgRecipientPush | msgRecipientMail | msgRecipientText | msgRecipient\n";
                        }

                        next;
                    }

                    # FATAL ERROR: we could not find any targets for
                    # user specified device...
                    if (   $gatewayDevs eq ""
                        && $device ne "global" )
                    {
                        $return .=
"ERROR: Could not find any $typeUc contact for device $device - set attributes: msgContact$typeUc | msgRecipient$typeUc | msgRecipient\n";
                    }

                    # FATAL ERROR: we could not find any targets at all
                    elsif ( $gatewayDevs eq "" ) {
                        $return .=
"ERROR: No global $typeUc contact defined. Please specify a destination device or set global attributes: msgContact$typeUc | msgRecipient$typeUc | msgRecipient\n";
                    }

                    #####################
                    # return if we are in routing target test mode
                    #
                    if ( defined($testMode) && $testMode eq "1" ) {
                        Log3 $logDevice, 5,
"msg $device:		$type[$i] route check result: ROUTE_AVAILABLE"
                          if ( $return eq "" );
                        Log3 $logDevice, 5,
"msg $device:		$type[$i] route check result: ROUTE_UNAVAILABLE"
                          if ( $return ne "" );
                        return "ROUTE_AVAILABLE"   if ( $return eq "" );
                        return "ROUTE_UNAVAILABLE" if ( $return ne "" );
                    }

                    # user selected audio-visual announcement state
                    my $annState = ReadingsVal(

                        # look for direct
                        AttrVal(
                            $device, "msgSwitcherDev",

                            #look for indirect audio
                            AttrVal(
                                AttrVal( $device, "msgRecipient$typeUc", "" ),
                                "msgSwitcherDev",

                                #look for indirect general
                                AttrVal(
                                    AttrVal( $device, "msgRecipient", "" ),
                                    "msgSwitcherDev",

                                    # look for global direct
                                    AttrVal(
                                        "global", "msgSwitcherDev",

                                        #look for global indirect type
                                        AttrVal(
                                            AttrVal(
                                                "global",
                                                "msgRecipient$typeUc", ""
                                            ),
                                            "msgSwitcherDev",

                                            #look for global indirect general
                                            AttrVal(
                                                AttrVal(
                                                    "global", "msgRecipient",
                                                    ""
                                                ),
                                                "msgSwitcherDev",

                                                # default
                                                ""
                                            )
                                        )
                                    )
                                )
                            )
                        ),
                        "state",
                        "long"
                    );

                    # user selected emergency priority audio threshold
                    my $prioThresAudioEmg = 
                        # look for direct
                        AttrVal(
                            $device, "msgThPrioAudioEmergency",

                            #look for indirect audio
                            AttrVal(
                                AttrVal( $device, "msgRecipient$typeUc", "" ),
                                "msgThPrioAudioEmergency",

                                #look for indirect general
                                AttrVal(
                                    AttrVal( $device, "msgRecipient", "" ),
                                    "msgThPrioAudioEmergency",

                                    # look for global direct
                                    AttrVal(
                                        "global", "msgThPrioAudioEmergency",

                                        #look for global indirect type
                                        AttrVal(
                                            AttrVal(
                                                "global",
                                                "msgRecipient$typeUc", ""
                                            ),
                                            "msgThPrioAudioEmergency",

                                            #look for global indirect general
                                            AttrVal(
                                                AttrVal(
                                                    "global", "msgRecipient",
                                                    ""
                                                ),
                                                "msgThPrioAudioEmergency",

                                                # default
                                                "2"
                                            )
                                        )
                                    )
                                )
                            )
                        )
                    ;

                    # user selected high priority audio threshold
                    my $prioThresAudioHigh = 
                        # look for direct
                        AttrVal(
                            $device, "msgThPrioAudioHigh",

                            #look for indirect audio
                            AttrVal(
                                AttrVal( $device, "msgRecipient$typeUc", "" ),
                                "msgThPrioAudioHigh",

                                #look for indirect general
                                AttrVal(
                                    AttrVal( $device, "msgRecipient", "" ),
                                    "msgThPrioAudioHigh",

                                    # look for global direct
                                    AttrVal(
                                        "global", "msgThPrioAudioHigh",

                                        #look for global indirect type
                                        AttrVal(
                                            AttrVal(
                                                "global",
                                                "msgRecipient$typeUc", ""
                                            ),
                                            "msgThPrioAudioHigh",

                                            #look for global indirect general
                                            AttrVal(
                                                AttrVal(
                                                    "global", "msgRecipient",
                                                    ""
                                                ),
                                                "msgThPrioAudioHigh",

                                                # default
                                                "1"
                                            )
                                        )
                                    )
                                )
                            )
                        )
                    ;

                    # user selected high priority threshold
                    my $prioThresHigh = 
                        # look for direct
                        AttrVal(
                            $device, "msgThPrioHigh",

                            #look for indirect audio
                            AttrVal(
                                AttrVal( $device, "msgRecipient$typeUc", "" ),
                                "msgThPrioHigh",

                                #look for indirect general
                                AttrVal(
                                    AttrVal( $device, "msgRecipient", "" ),
                                    "msgThPrioHigh",

                                    # look for global direct
                                    AttrVal(
                                        "global", "msgThPrioHigh",

                                        #look for global indirect type
                                        AttrVal(
                                            AttrVal(
                                                "global",
                                                "msgRecipient$typeUc", ""
                                            ),
                                            "msgThPrioHigh",

                                            #look for global indirect general
                                            AttrVal(
                                                AttrVal(
                                                    "global", "msgRecipient",
                                                    ""
                                                ),
                                                "msgThPrioHigh",

                                                # default
                                                "2"
                                            )
                                        )
                                    )
                                )
                            )
                        )
                    ;

                    # user selected normal priority threshold
                    my $prioThresNormal = 
                        # look for direct
                        AttrVal(
                            $device, "msgThPrioNormal",

                            #look for indirect audio
                            AttrVal(
                                AttrVal( $device, "msgRecipient$typeUc", "" ),
                                "msgThPrioNormal",

                                #look for indirect general
                                AttrVal(
                                    AttrVal( $device, "msgRecipient", "" ),
                                    "msgThPrioNormal",

                                    # look for global direct
                                    AttrVal(
                                        "global", "msgThPrioNormal",

                                        #look for global indirect type
                                        AttrVal(
                                            AttrVal(
                                                "global",
                                                "msgRecipient$typeUc", ""
                                            ),
                                            "msgThPrioNormal",

                                            #look for global indirect general
                                            AttrVal(
                                                AttrVal(
                                                    "global", "msgRecipient",
                                                    ""
                                                ),
                                                "msgThPrioNormal",

                                                # default
                                                "0"
                                            )
                                        )
                                    )
                                )
                            )
                        )
                    ;

                    if ( $type[$i] eq "audio" ) {
                        if (   $annState eq "long"
                            || $forceType == 1
                            || $forceDevice == 1
                            || $loopPriority >= $prioThresAudioEmg )
                        {
                            $priorityCat = "";
                        }
                        elsif ( $loopPriority >= $prioThresAudioHigh ) {
                            $priorityCat = "ShortPrio";
                        }
                        else {
                            $priorityCat = "Short";
                        }
                    }
                    else {
                        if ( $loopPriority >= $prioThresHigh ) {
                            $priorityCat = "High";
                        }
                        elsif ( $loopPriority >= $prioThresNormal ) {
                            $priorityCat = "";
                        }
                        else {
                            $priorityCat = "Low";
                        }
                    }

                    # get resident presence information
                    #
                    my $residentDevState    = "";
                    my $residentDevPresence = "";

                    # device
                    if ( ReadingsVal( $device, "presence", "-" ) ne "-" ) {
                        $residentDevState = ReadingsVal( $device, "state", "" );
                        $residentDevPresence =
                          ReadingsVal( $device, "presence", "" );
                    }

                    # device indirect
                    if (
                        (
                               $residentDevState eq ""
                            || $residentDevPresence eq ""
                        )
                        && ReadingsVal(
                            AttrVal( $device, "msgRecipient$typeUc", "" ),
                            "presence", "-" ) ne "-"
                      )
                    {
                        $residentDevState =
                          ReadingsVal(
                            AttrVal( $device, "msgRecipient$typeUc", "" ),
                            "state", "" )
                          if ( $residentDevState eq "" );
                        $residentDevPresence =
                          ReadingsVal(
                            AttrVal( $device, "msgRecipient$typeUc", "" ),
                            "presence", "" )
                          if ( $residentDevPresence eq "" );
                    }

                    # device indirect general
                    if (
                        (
                               $residentDevState eq ""
                            || $residentDevPresence eq ""
                        )
                        && ReadingsVal( AttrVal( $device, "msgRecipient", "" ),
                            "presence", "-" ) ne "-"
                      )
                    {
                        $residentDevState =
                          ReadingsVal( AttrVal( $device, "msgRecipient", "" ),
                            "state", "" )
                          if ( $residentDevState eq "" );
                        $residentDevPresence =
                          ReadingsVal( AttrVal( $device, "msgRecipient", "" ),
                            "presence", "" )
                          if ( $residentDevPresence eq "" );
                    }

                    # device explicit
                    if (
                        (
                               $residentDevState eq ""
                            || $residentDevPresence eq ""
                        )
                        && ReadingsVal(
                            AttrVal( $device, "msgResidentsDev", "" ),
                            "presence", "-" ) ne "-"
                      )
                    {
                        $residentDevState =
                          ReadingsVal(
                            AttrVal( $device, "msgResidentsDev", "" ),
                            "state", "" )
                          if ( $residentDevState eq "" );
                        $residentDevPresence =
                          ReadingsVal(
                            AttrVal( $device, "msgResidentsDev", "" ),
                            "presence", "" )
                          if ( $residentDevPresence eq "" );
                    }

                    # global indirect
                    if (
                        (
                               $residentDevState eq ""
                            || $residentDevPresence eq ""
                        )
                        && ReadingsVal(
                            AttrVal( "global", "msgRecipient$typeUc", "" ),
                            "presence", "-" ) ne "-"
                      )
                    {
                        $residentDevState =
                          ReadingsVal(
                            AttrVal( "global", "msgRecipient$typeUc", "" ),
                            "state", "" )
                          if ( $residentDevState eq "" );
                        $residentDevPresence =
                          ReadingsVal(
                            AttrVal( "global", "msgRecipient$typeUc", "" ),
                            "presence", "" )
                          if ( $residentDevPresence eq "" );
                    }

                    # global indirect general
                    if (
                        (
                               $residentDevState eq ""
                            || $residentDevPresence eq ""
                        )
                        && ReadingsVal( AttrVal( "global", "msgRecipient", "" ),
                            "presence", "-" ) ne "-"
                      )
                    {
                        $residentDevState =
                          ReadingsVal( AttrVal( "global", "msgRecipient", "" ),
                            "state", "" )
                          if ( $residentDevState eq "" );
                        $residentDevPresence =
                          ReadingsVal( AttrVal( "global", "msgRecipient", "" ),
                            "presence", "" )
                          if ( $residentDevPresence eq "" );
                    }

                    # global explicit
                    if (
                        (
                               $residentDevState eq ""
                            || $residentDevPresence eq ""
                        )
                        && ReadingsVal(
                            AttrVal( "global", "msgResidentsDev", "" ),
                            "presence", "-" ) ne "-"
                      )
                    {
                        $residentDevState =
                          ReadingsVal(
                            AttrVal( "global", "msgResidentsDev", "" ),
                            "state", "" )
                          if ( $residentDevState eq "" );
                        $residentDevPresence =
                          ReadingsVal(
                            AttrVal( "global", "msgResidentsDev", "" ),
                            "presence", "" )
                          if ( $residentDevPresence eq "" );
                    }

                    ################################################################
                    ### Send message
                    ###

                    # user selected emergency priority text threshold
                    my $prioThresGwEmg = 
                        # look for direct
                        AttrVal(
                            $device, "msgThPrioGwEmergency",

                            #look for indirect type
                            AttrVal(
                                AttrVal( $device, "msgRecipient$typeUc", "" ),
                                "msgThPrioGwEmergency",

                                #look for indirect general
                                AttrVal(
                                    AttrVal( $device, "msgRecipient", "" ),
                                    "msgThPrioGwEmergency",

                                    # look for global direct
                                    AttrVal(
                                        "global", "msgThPrioGwEmergency",

                                        #look for global indirect type
                                        AttrVal(
                                            AttrVal(
                                                "global",
                                                "msgRecipient$typeUc", ""
                                            ),
                                            "msgThPrioGwEmergency",

                                            #look for global indirect general
                                            AttrVal(
                                                AttrVal(
                                                    "global", "msgRecipient",
                                                    ""
                                                ),
                                                "msgThPrioGwEmergency",

                                                # default
                                                "2"
                                            )
                                        )
                                    )
                                )
                            )
                        )
                    ;

                    my %gatewaysStatus;

                    foreach my $gatewayDevOr ( split /\|/, $gatewayDevs ) {
                        foreach my $gatewayDev ( split /,/, $gatewayDevOr ) {
                            Log3 $logDevice, 5,
"msg $device: Trying to send message via gateway $gatewayDev";

                            ##############
                           # check for gateway availability and set route status
                           #

                            my $routeStatus = "OK";
                            if (   $type[$i] ne "mail"
                                && !defined( $defs{$gatewayDev} )
                                && $deviceType eq "device" )
                            {
                                $routeStatus = "UNDEFINED";
                            }
                            elsif ( $type[$i] ne "mail"
                                && AttrVal( $gatewayDev, "disable", "0" ) eq
                                "1" )
                            {
                                $routeStatus = "DISABLED";
                            }
                            elsif (
                                $type[$i] ne "mail"
                                && (
                                ReadingsVal(
                                    $gatewayDev, "power",
                                    "on"
                                ) eq "off"
                                || ReadingsVal(
                                    $gatewayDev, "presence",
                                    "present"
                                ) eq "absent"
                                || ReadingsVal(
                                    $gatewayDev, "presence",
                                    "appeared"
                                ) eq "disappeared"
                                || ReadingsVal(
                                    $gatewayDev, "state",
                                    "present"
                                ) eq "absent"
                                || ReadingsVal(
                                    $gatewayDev, "state",
                                    "connected"
                                ) eq "unauthorized"
                                || ReadingsVal(
                                    $gatewayDev, "state",
                                    "connected"
                                ) eq "disconnected"
                                || ReadingsVal(
                                    $gatewayDev, "state",
                                    "reachable"
                                ) eq "unreachable"
                                || ReadingsVal(
                                    $gatewayDev, "available",
                                    "1"
                                ) eq "0"
                                || ReadingsVal(
                                    $gatewayDev, "available",
                                    "yes"
                                ) eq "no"
                                || ReadingsVal(
                                    $gatewayDev, "reachable",
                                    "1"
                                ) eq "0"
                                || ReadingsVal(
                                    $gatewayDev, "reachable",
                                    "yes"
                                ) eq "no"

                                )
                              )
                            {
                                $routeStatus = "UNAVAILABLE";
                            }
                            elsif ($type[$i] eq "audio"
                                && $annState ne "long"
                                && $annState ne "short" )
                            {
                                $routeStatus = "USER_DISABLED";
                            }
                            elsif ( $type[$i] eq "light" && $annState eq "off" )
                            {
                                $routeStatus = "USER_DISABLED";
                            }
                            elsif ($type[$i] ne "push"
                                && $type[$i] ne "mail"
                                && $residentDevPresence eq "absent" )
                            {
                                $routeStatus = "USER_ABSENT";
                            }
                            elsif ($type[$i] ne "push"
                                && $type[$i] ne "mail"
                                && $residentDevState eq "asleep" )
                            {
                                $routeStatus = "USER_ASLEEP";
                            }

                            # enforce by user request
                            if (
                                (
                                       $routeStatus eq "USER_DISABLED"
                                    || $routeStatus eq "USER_ABSENT"
                                    || $routeStatus eq "USER_ASLEEP"
                                )
                                && ( $forceType == 1 || $forceDevice == 1 )
                              )
                            {
                                $routeStatus = "OK_ENFORCED";
                            }

                            # enforce by priority
                            if (
                                (
                                       $routeStatus eq "USER_DISABLED"
                                    || $routeStatus eq "USER_ABSENT"
                                    || $routeStatus eq "USER_ASLEEP"
                                )
                                && $loopPriority >= $prioThresGwEmg
                              )
                            {
                                $routeStatus = "OK_EMERGENCY";
                            }

                            # add location status
                            if ( $useLocation == 2 ) {
                                $routeStatus .= "+LOCATION-UNAVAILABLE";
                            }
                            elsif ( $useLocation == 1 ) {
                                $routeStatus .= "+LOCATION";
                            }


                            my $gatewayType = $type[$i] eq "mail" ? "fhemMsgMail" : $defs{$gatewayDev}{TYPE};

                            my $defTitle = defined($settings->{ $type[$i] }{title}) ? $settings->{ $type[$i] }{title} : "System Message";
                            $defTitle = $cmdSchema->{ $type[$i] }{$gatewayType}{defaultValues}{$priorityCat}{TITLE}
                              if ( defined($cmdSchema->{ $type[$i] }{$gatewayType}{defaultValues}{$priorityCat}{TITLE}) && $priorityCat ne "" );
                            $defTitle = $cmdSchema->{ $type[$i] }{$gatewayType}{defaultValues}{Normal}{TITLE}
                              if ( defined($cmdSchema->{ $type[$i] }{$gatewayType}{defaultValues}{Normal}{TITLE}) && $priorityCat eq "" );

                            # use title from device, global or internal default
                            my $loopTitle;
                            $loopTitle = $title if ( $title ne "-" );
                            $loopTitle =

                              # look for direct high
                              AttrVal(
                                $device, "msgTitle$typeUc$priorityCat",

                                # look for indirect high
                                AttrVal(
                                    AttrVal( $device, "msgRecipient$typeUc", "" ),
                                    "msgTitle$typeUc$priorityCat",

                                    #look for indirect general high
                                    AttrVal(
                                        AttrVal( $device, "msgRecipient", "" ),
                                        "msgTitle$typeUc$priorityCat",

                                        # look for global direct high
                                        AttrVal(
                                            "global", "msgTitle$typeUc$priorityCat",

                                            # look for global indirect high
                                            AttrVal(
                                                AttrVal(
                                                    "global", "msgRecipient$typeUc",
                                                    ""
                                                ),
                                                "msgTitle$typeUc$priorityCat",

                                                #look for global indirect general high
                                                AttrVal(
                                                    AttrVal(
                                                        "global", "msgRecipient",
                                                        ""
                                                    ),
                                                    "msgTitle$typeUc$priorityCat",

                                                    # default
                                                    $defTitle
                                                )
                                            )
                                        )
                                    )
                                )
                              ) if ( $title eq "-" );

                            if ( $type[$i] eq "mail" && $priorityCat ne "" ) {
                              $loopTitle = "[$priorityCat] $loopTitle";
                            }

                            my $loopMsg = $msg;
                            if ( $catchall == 1 ) {
                                $loopTitle = "Fw: $loopTitle";
                                if ( $type[$i] eq "mail" ) {
                                    $loopMsg .=
        "\n\n-- \nMail catched from device $device";
                                }
                                else {
                                    $loopMsg .= " ### (Catched from device $device)";
                                }
                            }

                            # correct message format
                            #
                            $loopMsg =~ s/\n/<br \/>/gi;
                            $loopMsg =~ s/((|(\d+)| )\|\w+\|( |))/\n\n/gi
                              if ( $type[$i] ne "audio" ); # Remove Sonos Speak commands


                            # use command from device, global or internal default
                            my $defCmd = "";
                            $defCmd = $cmdSchema->{ $type[$i] }{$gatewayType}{$priorityCat}
                              if ( defined($cmdSchema->{ $type[$i] }{$gatewayType}{$priorityCat}) && $priorityCat ne "" );
                            $defCmd = $cmdSchema->{ $type[$i] }{$gatewayType}{Normal}
                              if ( defined($cmdSchema->{ $type[$i] }{$gatewayType}{Normal}) && $priorityCat eq "" );
                            my $cmd =

                              # gateway device
                              AttrVal(
                                $gatewayDev, "msgCmd$typeUc$priorityCat",

                                # look for direct
                                AttrVal(
                                    $device, "msgCmd$typeUc$priorityCat",

                                    # look for indirect
                                    AttrVal(
                                        AttrVal(
                                            $device, "msgRecipient$typeUc",
                                            ""
                                        ),
                                        "msgCmd$typeUc$priorityCat",

                                        #look for indirect general
                                        AttrVal(
                                            AttrVal(
                                                $device, "msgRecipient", ""
                                            ),
                                            "msgCmd$typeUc$priorityCat",

                                            # look for global direct
                                            AttrVal(
                                                "global",
                                                "msgCmd$typeUc$priorityCat",

                                                # look for global indirect
                                                AttrVal(
                                                    AttrVal(
                                                        "global",
                                                        "msgRecipient$typeUc",
                                                        ""
                                                    ),
                                                    "msgCmd$typeUc$priorityCat",

                                               #look for global indirect general
                                                    AttrVal(
                                                        AttrVal(
                                                            "global",
                                                            "msgRecipient",
                                                            ""
                                                        ),
"msgCmd$typeUc$priorityCat",

                                                        # internal
                                                        $defCmd
                                                    )
                                                )
                                            )
                                        )
                                    )
                                )
                              );

                            if ($cmd eq "") {
                              Log3 $logDevice, 4, "$gatewayDev: Unknown command schema for gateway device type $gatewayType. Use manual definition by userattr msgCmd*";
                              $return .= "$gatewayDev: Unknown command schema for gateway device type $gatewayType. Use manual definition by userattr msgCmd*\n";
                              next;
                            }

                            $cmd =~ s/%DEVICE%/$gatewayDev/gi;
                            $cmd =~ s/%PRIORITY%/$loopPriority/gi;
                            $cmd =~ s/%TITLE%/$loopTitle/gi;
                            $cmd =~ s/%MSG%/$loopMsg/gi;

                            # advanced options from message
                            if (ref($advanced) eq "ARRAY") {
                              for my $item (@$advanced) {
                                 for my $key (keys(%$item)) {
                                    my $val = $item->{$key};
                                    $cmd =~ s/%$key%/$val/gi;
                                 }
                              }
                            }

                            # advanced options from command schema hash
                            if ($priorityCat ne "" && defined( $cmdSchema->{ $type[$i] }{$gatewayType}{defaultValues}{$priorityCat} )) {

                              for my $item ($cmdSchema->{ $type[$i] }{$gatewayType}{defaultValues}{$priorityCat}) {
                                 for my $key (keys(%$item)) {
                                    my $val = $item->{$key};
                                    $cmd =~ s/%$key%/$val/gi;
                                 }
                              }

                            }
                            elsif ($priorityCat eq "" && defined( $cmdSchema->{ $type[$i] }{$gatewayType}{defaultValues}{Normal} )) {

                              for my $item ($cmdSchema->{ $type[$i] }{$gatewayType}{defaultValues}{Normal}) {
                                 for my $key (keys(%$item)) {
                                    my $val = $item->{$key};
                                    $cmd =~ s/%$key%/$val/gi;
                                 }
                              }

                            }

                            $sentCounter++;

                            if ( $routeStatus =~ /^OK\w*/ ) {
                                  
                                my $error = 0;

                                # run command
                                undef $@;
                                if ( $cmd =~ s/^[ \t]*\{|\}[ \t]*$//gi ) {
                                    $cmd =~ s/@\w+/\\$&/gi;
                                    Log3 $logDevice, 5,
"msg $device: $type[$i] route command (Perl): $cmd";
                                    eval $cmd;
                                    if ( $@ ) {
                                      $error = 1;
                                      $return .= "$gatewayDev: $@\n";
                                    }
                                }
                                else {
                                    Log3 $logDevice, 5,
"msg $device: $type[$i] route command (fhem): $cmd";
                                    fhem $cmd;
                                    if ( $@ ) {
                                      $error = 1;
                                      $return .= "$gatewayDev: $@\n";
                                    }
                                }

                                $routeStatus = "ERROR" if ($error == 1);

                                Log3 $logDevice, 3,
"msg $device: ID=$messageID.$sentCounter TYPE=$type[$i] ROUTE=$gatewayDev STATUS=$routeStatus PRIORITY=$loopPriority($priorityCat) TITLE='$loopTitle' MSG='$msg'"
                                  if ( $priorityCat ne "" );
                                Log3 $logDevice, 3,
"msg $device: ID=$messageID.$sentCounter TYPE=$type[$i] ROUTE=$gatewayDev STATUS=$routeStatus PRIORITY=$loopPriority TITLE='$loopTitle' MSG='$msg'"
                                  if ( $priorityCat eq "" );

                                  $messageSent                 = 1 if ($error == 0);
                                  $messageSentDev              = 1 if ($error == 0);
                                  $gatewaysStatus{$gatewayDev} = $routeStatus;
                            }
                            elsif ($routeStatus eq "UNAVAILABLE"
                                || $routeStatus eq "UNDEFINED" )
                            {
                                Log3 $logDevice, 3,
"msg $device: ID=$messageID.$sentCounter TYPE=$type[$i] ROUTE=$gatewayDev STATUS=$routeStatus PRIORITY=$loopPriority TITLE='$loopTitle' '$msg'";
                                $gatewaysStatus{$gatewayDev} = $routeStatus;
                            }
                            else {
                                Log3 $logDevice, 3,
"msg $device: ID=$messageID.$sentCounter TYPE=$type[$i] ROUTE=$gatewayDev STATUS=$routeStatus PRIORITY=$loopPriority TITLE='$loopTitle' '$msg'";
                                $messageSent    = 2 if ( $messageSent != 1 );
                                $messageSentDev = 2 if ( $messageSentDev != 1 );
                                $gatewaysStatus{$gatewayDev} = $routeStatus;
                            }

                        }

                        last if ( $messageSentDev == 1 );
                    }

                    if ( $catchall == 0 ) {
                        if ( !defined( $sentTypesPerDevice{$device} ) ) {
                            $sentTypesPerDevice{$device} = "";
                        }
                        else {
                            $sentTypesPerDevice{$device} .= " ";
                        }

                        $sentTypesPerDevice{$device} .=
                          $type[$i] . ":" . $messageSentDev;
                    }
                    else {
                        if ( !defined( $sentTypesPerDevice{$device} ) ) {
                            $sentTypesPerDevice{"global"} = "";
                        }
                        else {
                            $sentTypesPerDevice{"global"} .= " ";
                        }

                        $sentTypesPerDevice{"global"} .=
                          $type[$i] . ":" . $messageSentDev;
                    }

                    # update device readings
                    my $readingsDev = $defs{$device};
                    $readingsDev = $defs{"global"} if ( $catchall == 1 );
                    readingsBeginUpdate($readingsDev);

                    readingsBulkUpdate( $readingsDev, "fhemMsg" . $typeUc,
                        $msg );
                    readingsBulkUpdate( $readingsDev,
                        "fhemMsg" . $typeUc . "Title", $title );
                    readingsBulkUpdate( $readingsDev,
                        "fhemMsg" . $typeUc . "Prio",
                        $loopPriority );

                    my $gwStates = "";

                    while ( ( my $gwName, my $gwState ) = each %gatewaysStatus )
                    {
                        $gwStates .= " " if $gwStates ne "";
                        $gwStates .= "$gwName:$gwState";
                    }
                    readingsBulkUpdate( $readingsDev,
                        "fhemMsg" . $typeUc . "Gw", $gwStates );
                    readingsBulkUpdate( $readingsDev,
                        "fhemMsg" . $typeUc . "State",
                        $messageSentDev );

                    ################################################################
                    ### Implicit forwards based on priority or presence
                    ###

                    # no implicit escalations for type mail
                    next if ( $type[$i] eq "mail" );

                    # Skip if typeOr is defined
                    # and this is not the last type entry
                    # TODO: bei mehreren gleichzeitigen Typen (and-Definition)?
                    if (   $messageSentDev != 1
                        && $hasTypeOr == 1
                        && $isTypeOr < scalar( grep { defined $_ } @typesOr ) )
                    {
                        Log3 $logDevice, 4,
"msg $device: Skipping implicit forward due to typesOr definition";

                        # remove recipient from list to avoid
                        # other interaction when using recipientOr in parallel
                        if (   $hasRecipientOr == 1
                            && $isRecipientOr <
                            scalar( grep { defined $_ } @recipientsOr ) )
                        {
                            my $regex1 =
                              "\\s*!?@?" . $device . "[,|]";   # at the beginning
                            my $regex2 =
                              "[,|]!?@?" . $device . "\\s*";    # at the end
                            my $regex3 =
                                ",!?@?"
                              . $device
                              . ",";    # in the middle with comma
                            my $regex4 =
                                "[\|,]!?@?"
                              . $device
                              . "[\|,]";  # in the middle with pipe and/or comma

                            $recipients =~ s/^$regex1//;
                            $recipients =~ s/$regex2$/|/gi;
                            $recipients =~ s/$regex3/,/gi;
                            $recipients =~ s/$regex4/|/gi;
                        }

                        next;
                    }

                    # Skip if recipientOr is defined
                    # and this is not the last device entry
                    # TODO: bei mehreren gleichzeitigen Empfängern
                    #       (and-Definition)?
                    if (   $messageSentDev != 1
                        && $hasRecipientOr == 1
                        && $isRecipientOr <
                        scalar( grep { defined $_ } @recipientsOr ) )
                    {
                        Log3 $logDevice, 4,
"msg $device: Skipping implicit forward due to recipientOr definition";

                        next;
                    }

                    # priority forward thresholds
                    #

                    ### emergency
                    my $msgFwPrioEmergency =

                      # look for direct
                      AttrVal(
                        $device, "msgFwPrioEmergency$typeUc",

                        #look for indirect
                        AttrVal(
                            AttrVal( $device, "msgRecipient$typeUc", "" ),
                            "msgFwPrioEmergency$typeUc",

                            #look for indirect general
                            AttrVal(
                                AttrVal( $device, "msgRecipient", "" ),
                                "msgFwPrioEmergency$typeUc",

                                # default
                                2
                            )
                        )
                      );

                    ### absent
                    my $msgFwPrioAbsent =

                      # look for direct
                      AttrVal(
                        $device, "msgFwPrioAbsent$typeUc",

                        #look for indirect
                        AttrVal(
                            AttrVal( $device, "msgRecipient$typeUc", "" ),
                            "msgFwPrioAbsent$typeUc",

                            #look for indirect general
                            AttrVal(
                                AttrVal( $device, "msgRecipient", "" ),
                                "msgFwPrioAbsent$typeUc",

                                # default
                                0
                            )
                        )
                      );

                    ### gone
                    my $msgFwPrioGone =

                      # look for direct
                      AttrVal(
                        $device, "msgFwPrioGone$typeUc",

                        #look for indirect
                        AttrVal(
                            AttrVal( $device, "msgRecipient$typeUc", "" ),
                            "msgFwPrioGone$typeUc",

                            #look for indirect general
                            AttrVal(
                                AttrVal( $device, "msgRecipient", "" ),
                                "msgFwPrioGone$typeUc",

                                # default
                                1
                            )
                        )
                      );

                    Log3 $logDevice, 5,
"msg $device: Implicit forwards: recipient presence=$residentDevPresence state=$residentDevState"
                      if ( $residentDevPresence ne ""
                        || $residentDevState ne "" );

my $fw_gwUnavailable = defined($settings->{ $type[$i] }{typeEscalation}{gwUnavailable}) ? $settings->{ $type[$i] }{typeEscalation}{gwUnavailable} : "";
my $fw_emergency = defined($settings->{ $type[$i] }{typeEscalation}{emergency}) ? $settings->{ $type[$i] }{typeEscalation}{emergency} : "";
my $fw_residentAbsent = defined($settings->{ $type[$i] }{typeEscalation}{residentAbsent}) ? $settings->{ $type[$i] }{typeEscalation}{residentAbsent} : "";
my $fw_residentGone = defined($settings->{ $type[$i] }{typeEscalation}{residentGone}) ? $settings->{ $type[$i] }{typeEscalation}{residentGone} : "";

                    # Forward message
                    # if no gateway device for this type was available
                    if (   $messageSentDev == 0
                        && $fw_gwUnavailable ne ""
                        && !( $fw_gwUnavailable ~~ @type )
                        && $routes{$fw_gwUnavailable} == 1 )
                    {
                        Log3 $logDevice, 4,
"msg $device: Implicit forwards: No $type[$i] gateway device available for recipient $device ($gatewayDevs). Trying alternative message type "
                          . $fw_gwUnavailable;

                        push @type, $fw_gwUnavailable;
                        $forwarded .= "," . $type[$i] . ">" . $fw_gwUnavailable
                          if ( $forwarded ne "" );
                        $forwarded .= $type[$i] . ">" . $fw_gwUnavailable
                          if ( $forwarded eq "" );
                    }

                    # Forward message
                    # if emergency priority
                    if (   $loopPriority >= $msgFwPrioEmergency
                        && $fw_emergency ne ""
                        && !( $fw_emergency ~~ @type )
                        && $routes{$fw_emergency} == 1 )
                    {
                        Log3 $logDevice, 4,
"msg $device: Implicit forwards: Escalating high priority $type[$i] message via "
                          . $fw_emergency;

                        push @type, $fw_emergency;
                        $forwarded .= "," . $type[$i] . ">" . $fw_emergency
                          if ( $forwarded ne "" );
                        $forwarded .= $type[$i] . ">" . $fw_emergency
                          if ( $forwarded eq "" );
                    }

                    # Forward message
                    # if high priority and residents are constantly not at home
                    if (   $residentDevPresence eq "absent"
                        && $loopPriority >= $msgFwPrioGone
                        && $fw_residentGone ne ""
                        && !( $fw_residentGone ~~ @type )
                        && $routes{$fw_residentGone} == 1 )
                    {
                        Log3 $logDevice, 4,
"msg $device: Implicit forwards: Escalating high priority $type[$i] message via "
                          . $fw_residentGone;

                        push @type, $fw_residentGone;
                        $forwarded .= "," . $type[$i] . ">" . $fw_residentGone
                          if ( $forwarded ne "" );
                        $forwarded .= $type[$i] . ">" . $fw_residentGone
                          if ( $forwarded eq "" );
                    }

                    # Forward message
                    # if priority is normal or higher and residents
                    # are not at home but nearby
                    if (   $residentDevState eq "absent"
                        && $loopPriority >= $msgFwPrioAbsent
                        && $fw_residentAbsent ne ""
                        && !( $fw_residentAbsent ~~ @type )
                        && $routes{$fw_residentAbsent} == 1 )
                    {
                        Log3 $logDevice, 4,
"msg $device: Implicit forwards: Escalating $type[$i] message via "
                          . $fw_residentAbsent
                          . " due to absence";

                        push @type, $fw_residentAbsent;
                        $forwarded .= "," . $type[$i] . ">" . $fw_residentAbsent
                          if ( $forwarded ne "" );
                        $forwarded .= $type[$i] . ">" . $fw_residentAbsent
                          if ( $forwarded eq "" );
                    }

                }

                last if ( $messageSent == 1 );

                $isRecipientOr++;
            }
        }

        last if ( $messageSent == 1 );

        $isTypeOr++;
    }

    # finalize device readings
    while ( ( my $device, my $types ) = each %sentTypesPerDevice ) {
        readingsBulkUpdate( $defs{$device}, "fhemMsgStateTypes", $types )
          if ( $forwarded eq "" );
        readingsBulkUpdate( $defs{$device}, "fhemMsgStateTypes",
            $types . " forwards:" . $forwarded )
          if ( $forwarded ne "" );
        readingsBulkUpdate( $defs{$device}, "fhemMsgState", $messageSent );
        readingsEndUpdate( $defs{$device}, 1 );
    }

    if ( $messageSent == 1 && $return ne "" ) {
        $return .= "However, message was still sent to some recipients!";
    }

    if ( $messageSent == 2 ) {
        $return .=
          "FATAL ERROR: Message NOT sent. No gateway device was available.";
    }

    return $return;
}

1;

=pod
=begin html

<a name="msg"></a>
<h3>mail</h3>
<ul>
  <code>msg [&lt;type&gt;] [&lt;@device&gt;|&lt;e-mail address&gt;] [&lt;priority&gt;] [|&lt;title&gt;|] &lt;message&gt;</code>
  <br>
  <br>
  No documentation yet, sorry.<br>
  <a href="http://forum.fhem.de/index.php/topic,39983.0.html">FHEM Forum</a>
</ul>

=end html
=begin html_DE

<a name="mail"></a>
<h3>mail</h3>
<ul>
  <code>msg [&lt;type&gt;] [&lt;@device&gt;|&lt;e-mail address&gt;] [&lt;priority&gt;] [|&lt;title&gt;|] &lt;message&gt;</code>
  <br>
  <br>
  Bisher keine Dokumentation, sorry.<br>
  <a href="http://forum.fhem.de/index.php/topic,39983.0.html">FHEM Forum</a>
</ul>


=end html_DE
=cut
