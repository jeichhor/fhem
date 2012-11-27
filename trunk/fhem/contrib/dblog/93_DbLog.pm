
##############################################
#
# 93_DbLog.pm
# written by Dr. Boris Neubert 2007-12-30
# e-mail: omega at online dot de
#
# modified by Tobias Faust 2012-06-26
# e-mail: tobias dot faust at online dot de
#
##############################################

package main;
use strict;
use warnings;
use DBI;
use Data::Dumper;

sub DbLog($$$);

################################################################
sub
DbLog_Initialize($)
{
  my ($hash) = @_;

  $hash->{DefFn}    = "DbLog_Define";
  $hash->{UndefFn}  = "DbLog_Undef";
  $hash->{NotifyFn} = "DbLog_Log";
  $hash->{GetFn}    = "DbLog_Get";
  $hash->{AttrFn}   = "DbLog_Attr";
  $hash->{AttrList} = "disable:0,1 loglevel:0,5";

}

###############################################################
sub
DbLog_Define($@)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);

  return "wrong syntax: define <name> DbLog configuration regexp"
	if(int(@a) != 4);

  my $regexp    	= $a[3];

  eval { "Hallo" =~ m/^$regexp$/ };
  return "Bad regexp: $@" if($@);
  $hash->{REGEXP} = $regexp;

  $hash->{CONFIGURATION}= $a[2];

  return "Can't connect to database." if(!DbLog_Connect($hash));

  $hash->{STATE} = "active";

  return undef;
}

#####################################
sub
DbLog_Undef($$)
{
  my ($hash, $name) = @_;
  my $dbh= $hash->{DBH};
  $dbh->disconnect() if(defined($dbh));
  return undef;
}

################################################################
#
# Wird bei jeder Aenderung eines Attributes dieser
# DbLog-Instanz aufgerufen
#
################################################################
sub
DbLog_Attr(@)
{
  my @a = @_;
  my $do = 0;

  if($a[0] eq "set" && $a[2] eq "disable") {
    $do = (!defined($a[3]) || $a[3]) ? 1 : 2;
  }
  $do = 2 if($a[0] eq "del" && (!$a[2] || $a[2] eq "disable"));
  return if(!$do);

  $defs{$a[1]}{STATE} = ($do == 1 ? "disabled" : "active");

  return undef;
}

################################################################
#
# Parsefunktion, abhaengig vom Devicetyp
#
################################################################
sub
DbLog_ParseEvent($$)
{
	my ($type, $event)= @_;
	my @result;

	# split the event into reading and argument
	# "day-temp: 22.0 (Celsius)" -> "day-temp", "22.0 (Celsius)"
	my @parts   = split(/: /,$event);
	my $reading = shift @parts;
	my $value   = join(": ", @parts);
	my $unit    = "";

	#default
	if(!defined($reading)) { $reading = ""; }
	if(!defined($value))   { $value   = ""; }

	# the interpretation of the argument depends on the device type
	# EMEM, M232Counter, M232Voltage return plain numbers
	if(($type eq "M232Voltage") ||
	   ($type eq "M232Counter") ||
	   ($type eq "EMEM")) {
    }

	# Onewire

	elsif(($type eq "OWAD") ||
	      ($type eq "OWSWITCH") ||
		  ($type eq "OWMULTI")) {
		$reading = "data";
		$value = $event;
	}

	# FS20
	elsif(($type eq "FS20") ||
          ($type eq "X10")) {
		#@parts = split(/ /,$event);
		#$reading = shift @parts;
		#$value   = join(" ", shift @parts);

		if($reading =~ m/^dim(\d+).*/o) {
			$value = $1;
			$reading= "dim";
			$unit= "%";
		}
		if(!defined($value) || $value eq "") {$value=$reading; $reading="data";}
	}
  # FHT
  elsif($type eq "FHT") {
     if($reading =~ m(-from[12]\ ) || $reading =~ m(-to[12]\ )) {
	@parts= split(/ /,$event);
	$reading= $parts[0];
	$value= $parts[1];
	$unit= "";
     }
     if($reading =~ m(-temp)) { $value=~ s/ \(Celsius\)//; $unit= "°C"; }
     if($reading =~ m(temp-offset)) { $value=~ s/ \(Celsius\)//; $unit= "°C"; }
     if($reading =~ m(^actuator[0-9]*)) {
		if($value eq "lime-protection") {
			$reading= "actuator-lime-protection";
			undef $value;
		}
		elsif($value =~ m(^offset:)) {
			$reading= "actuator-offset";
     			@parts= split(/: /,$value);
			$value= $parts[1];
			if(defined $value) {
				$value=~ s/%//; $value= $value*1.; $unit= "%";
			}
		}
		elsif($value =~ m(^unknown_)) {
    			@parts= split(/: /,$value);
			$reading= "actuator-" . $parts[0];
			$value= $parts[1];
			if(defined $value) {
				$value=~ s/%//; $value= $value*1.; $unit= "%";
			}
		}
		elsif($value eq "synctime") {
			$reading= "actuator-synctime";
			undef $value;
		}
		elsif($value eq "test") {
			$reading= "actuator-test";
			undef $value;
		}
		elsif($value eq "pair") {
			$reading= "actuator-pair";
			undef $value;
		}
		else {
			$value=~ s/%//; $value= $value*1.; $unit= "%";
		}
     }
  }
  # KS300
  elsif($type eq "KS300") {
     if($event =~ m(T:.*)) { $reading= "data"; $value= $event; }
     if($event =~ m(avg_day)) { $reading= "data"; $value= $event; }
     if($event =~ m(avg_month)) { $reading= "data"; $value= $event; }
     if($reading eq "temperature") { $value=~ s/ \(Celsius\)//; $unit= "°C"; }
     if($reading eq "wind") { $value=~ s/ \(km\/h\)//; $unit= "km/h"; }
     if($reading eq "rain") { $value=~ s/ \(l\/m2\)//; $unit= "l/m2"; }
     if($reading eq "rain_raw") { $value=~ s/ \(counter\)//; $unit= ""; }
     if($reading eq "humidity") { $value=~ s/ \(\%\)//; $unit= "%"; }
     if($reading eq "israining") {
	$value=~ s/ \(yes\/no\)//;
        $value=~ s/no/0/;
        $value=~ s/yes/1/;
      }
  }
  # HMS
  elsif($type eq "HMS" ||
        $type eq "CUL_WS" ||
		$type eq "OWTHERM") {
     if($event =~ m(T:.*)) { $reading= "data"; $value= $event; }
     if($reading eq "temperature") { $value=~ s/ \(Celsius\)//; $unit= "°C"; }
	 if($reading eq "temperature") { $value=~ s/([-\.\d]+).*/$1/; $unit= "°C"; } #OWTHERM

     if($reading eq "humidity") { $value=~ s/ \(\%\)//; $unit= "%"; }
     if($reading eq "battery") {
        $value=~ s/ok/1/;
        $value=~ s/replaced/1/;
        $value=~ s/empty/0/;
     }
  }


  # BS
  elsif($type eq "BS") {
	  if($event =~ m(brightness:.*)) {
		  @parts= split(/ /,$event);
		  $reading= "lux";
		  $value= $parts[4]*1.;
		  $unit= "lux";
    }
  }

	@result= ($reading,$value,$unit);
	return @result;
}


################################################################
#
# Hauptroutine zum Loggen. Wird bei jedem Eventchange
# aufgerufen
#
################################################################
sub
DbLog_Log($$)
{
  # Log is my entry, Dev is the entry of the changed device
  my ($log, $dev) = @_;

  return undef if($log->{STATE} eq "disabled");

  # name and type required for parsing
  my $n= $dev->{NAME};
  my $t= uc($dev->{TYPE});

  # timestamp in SQL format YYYY-MM-DD hh:mm:ss
  #my ($sec,$min,$hr,$day,$mon,$yr,$wday,$yday,$isdst)= localtime(time);
  #my $ts= sprintf("%04d-%02d-%02d %02d:%02d:%02d", $yr+1900,$mon+1,$day,$hr,$min,$sec);

  my $re = $log->{REGEXP};
  my $max = int(@{$dev->{CHANGED}});
  for (my $i = 0; $i < $max; $i++) {
    my $s = $dev->{CHANGED}[$i];
    $s = "" if(!defined($s));
    if($n =~ m/^$re$/ || "$n:$s" =~ m/^$re$/) {
      my $ts = TimeNow();
      $ts = $dev->{CHANGETIME}[$i] if(defined($dev->{CHANGETIME}[$i]));
      # $ts is in SQL format YYYY-MM-DD hh:mm:ss

      my @r= DbLog_ParseEvent($t, $s);
      my $reading= $r[0];
      my $value= $r[1];
      my $unit= $r[2];
      if(!defined $reading) { $reading= ""; }
      if(!defined $value) { $value= ""; }
      if(!defined $unit || $unit eq "") {
         $unit = AttrVal("$n", "unit", "");
      }

      my $is= "(TIMESTAMP, DEVICE, TYPE, EVENT, READING, VALUE, UNIT) VALUES " .
         "('$ts', '$n', '$t', '$s', '$reading', '$value', '$unit')";
      DbLog_ExecSQL($log, "INSERT INTO history" . $is);
      DbLog_ExecSQL($log, "DELETE FROM current WHERE (DEVICE='$n') AND (READING='$reading')");
      DbLog_ExecSQL($log, "INSERT INTO current" . $is);



    }
  }

  return "";
}

################################################################
#
# zerlegt uebergebenes FHEM-Datum in die einzelnen Bestandteile
# und fuegt noch Defaultwerte ein
# uebergebenes SQL-Format: YYYY-MM-DD HH24:MI:SS
#
################################################################
sub
DbLog_explode_datetime($%) {
  my ($t, %def) = @_;
  my %retv;

  my (@datetime, @date, @time);
  @datetime = split(" ", $t); #Datum und Zeit auftrennen
  @date = split("-", $datetime[0]);
  @time = split(":", $datetime[1]) if ($datetime[1]);
  if ($date[0]) {$retv{year}  = $date[0];} else {$retv{year}  = $def{year};}
  if ($date[1]) {$retv{month} = $date[1];} else {$retv{month} = $def{month};}
  if ($date[2]) {$retv{day}   = $date[2];} else {$retv{day}   = $def{day};}
  if ($time[0]) {$retv{hour}  = $time[0];} else {$retv{hour}  = $def{hour};}
  if ($time[1]) {$retv{minute}= $time[1];} else {$retv{minute}= $def{minute};}
  if ($time[2]) {$retv{second}= $time[2];} else {$retv{second}= $def{second};}

  $retv{datetime}=DbLog_implode_datetime($retv{year}, $retv{month}, $retv{day}, $retv{hour}, $retv{minute}, $retv{second});

  #Log 1, Dumper(%retv);
  return %retv
}

sub
DbLog_implode_datetime($$$$$$) {
  my ($year, $month, $day, $hour, $minute, $second) = @_;
  my $retv = $year."-".$month."-".$day." ".$hour.":".$minute.":".$second;

  return $retv;
}
################################################################
#
# Verbindung zur DB aufbauen
#
################################################################
sub
DbLog_Connect($)
{
  my ($hash)= @_;

  my $configfilename= $hash->{CONFIGURATION};
  if(!open(CONFIG, $configfilename)) {
	Log 1, "Cannot open database configuration file $configfilename.";
	return 0; }
  my @config=<CONFIG>;
  close(CONFIG);

  my %dbconfig;
  eval join("", @config);

  my $dbconn= $dbconfig{connection};
  my $dbuser= $dbconfig{user};
  my $dbpassword= $dbconfig{password};

  #check the database model
  if($dbconn =~ m/pg:/i) {
    $hash->{DBMODEL}="POSTGRESQL";
  } elsif ($dbconn =~ m/mysql:/i) {
    $hash->{DBMODEL}="MYSQL";
  } elsif ($dbconn =~ m/oracle:/i) {
    $hash->{DBMODEL}="ORACLE";
  } elsif ($dbconn =~ m/sqlite:/i) {
    $hash->{DBMODEL}="SQLITE";
  } else {
    $hash->{DBMODEL}="unknown";
    Log 3, "Unknown dbmodel type in configuration file $configfilename.";
    Log 3, "Only Mysql, Postgresql, Oracle, SQLite are fully supported.";
    Log 3, "It may cause SQL-Erros during generating plots.";
  }

  Log 3, "Connecting to database $dbconn with user $dbuser";
  my $dbh = DBI->connect_cached("dbi:$dbconn", $dbuser, $dbpassword);
  if(!$dbh) {
    Log 2, "Can't connect to $dbconn: $DBI::errstr";
    return 0;
  }
  Log 3, "Connection to db $dbconn established";
  $hash->{DBH}= $dbh;

  return 1;
}

################################################################
#
# Prozeduren zum Ausfuehren des SQLs
#
################################################################
sub
DbLog_ExecSQL1($$)
{
  my ($dbh,$sql)= @_;

  my $sth = $dbh->do($sql);
  if(!$sth) {
    Log 2, "DBLog error: " . $DBI::errstr;
    return 0;
  }
  return $sth;
}

sub
DbLog_ExecSQL($$)
{
  my ($hash,$sql)= @_;
  Log GetLogLevel($hash->{NAME},5), "Executing $sql";
  my $dbh= $hash->{DBH};
  my $sth = DbLog_ExecSQL1($dbh,$sql);
  if(!$sth) {
    #retry
    $dbh->disconnect();
    if(!DbLog_Connect($hash)) {
      Log 2, "DBLog reconnect failed.";
      return 0;
    }
    $dbh= $hash->{DBH};
    $sth = DbLog_ExecSQL1($dbh,$sql);
    if(!$sth) {
      Log 2, "DBLog retry failed.";
      return 0;
    }
    Log 2, "DBLog retry ok.";
  }
  return $sth;
}

################################################################
#
# GET Funktion
# wird zb. zur Generierung der Plots implizit aufgerufen
#
################################################################
sub
DbLog_Get($@)
{
  my ($hash, @a) = @_;

  return "Usage: get $a[0] <in> <out> <from> <to> <column_spec>...\n".
     "  where column_spec is <device>:<reading>:<default>:<fn>\n" .
     "  see the #DbLog entries in the .gplot files\n" .
     "  <in> is not used, only for compatibility for FileLog, please use - \n" .
     "  <out> is a prefix, - means stdout\n"
    if(int(@a) < 5);
  shift @a;
  my $inf  = shift @a;
  my $outf = shift @a;
  my $from = shift @a;
  my $to   = shift @a; # Now @a contains the list of column_specs
  my ($internal, @fld);

  if($outf eq "INT") {
    $outf = "-";
    $internal = 1;
  }

  my @readings = ();
  my (%sqlspec, %from_datetime, %to_datetime);

  #uebergebenen Timestamp anpassen
  #moegliche Formate: YYYY | YYYY-MM | YYYY-MM-DD | YYYY-MM-DD_HH24
  $from =~ s/_/\ /g;
  $to   =~ s/_/\ /g;
  %from_datetime = DbLog_explode_datetime($from, DbLog_explode_datetime("2000-01-01 00:00:00", undef));
  %to_datetime   = DbLog_explode_datetime($to, DbLog_explode_datetime("2099-01-01 00:00:00", undef));
  $from = $from_datetime{datetime};
  $to = $to_datetime{datetime};


  my ($retval,$sql_timestamp,$sql_dev,$sql_reading,$sql_value, $type, $event, $unit) = "";
  my $writeout = 0;
  my (@min, @max, @sum, @cnt, @lastv, @lastd);
  my (%tstamp, %lasttstamp, $out_tstamp, $out_value, $minval, $maxval); #fuer delta-h/d Berechnung

  #extract the Device:Reading arguments into @readings array
  for(my $i = 0; $i < int(@a); $i++) {
    @fld = split(":", $a[$i], 4);
    $readings[$i][0] = $fld[0];
    $readings[$i][1] = $fld[1];
    $readings[$i][2] = $fld[2];
    $readings[$i][3] = $fld[3];
  }

  my $dbh= $hash->{DBH};

  #vorbereiten der DB-Abfrage, DB-Modell-abhaengig
  if ($hash->{DBMODEL} eq "POSTGRESQL") {
    $sqlspec{get_timestamp}  = "TO_CHAR(TIMESTAMP, 'YYYY-MM-DD HH24:MI:SS')";
    $sqlspec{from_timestamp} = "TO_TIMESTAMP('$from', 'YYYY-MM-DD HH24:MI:SS')";
    $sqlspec{to_timestamp}   = "TO_TIMESTAMP('$to', 'YYYY-MM-DD HH24:MI:SS')";
  } elsif ($hash->{DBMODEL} eq "ORACLE") {
    $sqlspec{get_timestamp}  = "TO_CHAR(TIMESTAMP, 'YYYY-MM-DD HH24:MI:SS')";
    $sqlspec{from_timestamp} = "TO_TIMESTAMP('$from', 'YYYY-MM-DD HH24:MI:SS')";
    $sqlspec{to_timestamp}   = "TO_TIMESTAMP('$to', 'YYYY-MM-DD HH24:MI:SS')";
  } elsif ($hash->{DBMODEL} eq "MYSQL") {
    $sqlspec{get_timestamp}  = "DATE_FORMAT(TIMESTAMP, '%Y-%m-%d %H:%i:%s')";
    $sqlspec{from_timestamp} = "STR_TO_DATE('$from', '%Y-%m-%d %H:%i:%s')";
    $sqlspec{to_timestamp}   = "STR_TO_DATE('$to', '%Y-%m-%d %H:%i:%s')";
  } elsif ($hash->{DBMODEL} eq "SQLITE") {
    $sqlspec{get_timestamp}  = "TIMESTAMP";
    $sqlspec{from_timestamp} = "'$from'";
    $sqlspec{to_timestamp}   = "'$to'";
  } else {
    $sqlspec{get_timestamp}  = "TIMESTAMP";
    $sqlspec{from_timestamp} = "'$from'";
    $sqlspec{to_timestamp}   = "'$to'";
  }

  if(uc($outf) eq "ALL") {
    $sqlspec{all}  = ",TYPE,EVENT,UNIT";
  }

   for(my $i=0; $i<int(@readings); $i++) {
   # ueber alle Readings
   # Variablen initialisieren
   $min[$i]   =  999999;
   $max[$i]   = -999999;
   $sum[$i]   = 0;
   $cnt[$i]   = 0;
   $lastv[$i] = 0;
   $lastd[$i] = "undef";
   $minval    =  999999;
   $maxval    = -999999;

  my $stm= "SELECT
        $sqlspec{get_timestamp},
        DEVICE,
        READING,
        VALUE
		".$sqlspec{all}."
       FROM history
       WHERE 1=1
        AND (DEVICE || '|' || READING) = ('".@readings[$i]->[0]."|".@readings[$i]->[1]."')
        AND TIMESTAMP > $sqlspec{from_timestamp}
        AND TIMESTAMP < $sqlspec{to_timestamp}
       ORDER BY TIMESTAMP";

  Log GetLogLevel($hash->{NAME},5), "Executing $stm";

  my $sth= $dbh->prepare($stm) ||
    return "Cannot prepare statement $stm: $DBI::errstr";
  my $rc= $sth->execute() ||
    return "Cannot execute statement $stm: $DBI::errstr";

  if(uc($outf) eq "ALL") {
	$retval .= "Timestamp: Device, Type, Event, Reading, Value, Unit\n";
	$retval .= "=====================================================\n";
  }
  while( ($sql_timestamp,$sql_dev,$sql_reading,$sql_value, $type, $event, $unit)= $sth->fetchrow_array) {
    $writeout   = 0;
    $out_value  = "";
    $out_tstamp = "";
    ############ Auswerten des 4. Parameters: function ###################
    if(@readings[$i]->[3] eq "int") {
      #nur den integerwert uebernehmen falls zb value=15°C
      $out_value = $1 if($sql_value =~ m/^(\d+).*/o);
      $out_tstamp = $sql_timestamp;
      $writeout=1;

    } elsif (@readings[$i]->[3] =~ m/^int(\d+).*/o) {
      #übernehme den Dezimalwert mit den angegebenen Stellen an Nachkommastellen
      $out_value = $1 if($sql_value =~ m/^([-\.\d]+).*/o);
      $out_tstamp = $sql_timestamp;
      $writeout=1;

    } elsif (@readings[$i]->[3] eq "delta-h") {
      #Berechnung eines Stundenwertes
      %tstamp = DbLog_explode_datetime($sql_timestamp, undef);
      if($lastd[$i] eq "undef") {
        %lasttstamp = DbLog_explode_datetime($sql_timestamp, undef);
      } else {
        %lasttstamp = DbLog_explode_datetime($lastd[$i], undef);
      }
      if("$tstamp{hour}" ne "$lasttstamp{hour}") {
        # Aenderung der stunde, Berechne Delta
        $out_value = sprintf("%0.1f", $maxval - $minval);
        $out_tstamp = DbLog_implode_datetime($lasttstamp{year}, $lasttstamp{month}, $lasttstamp{day}, $lasttstamp{hour}, "30", "00");
        $minval =  999999;
        $maxval = -999999;
        $writeout=1;
      }
    } elsif (@readings[$i]->[3] eq "delta-d") {
      #Berechnung eines Tageswertes
      %tstamp = DbLog_explode_datetime($sql_timestamp, undef);
      if($lastd[$i] eq "undef") {
        %lasttstamp = DbLog_explode_datetime($sql_timestamp, undef);
      } else {
        %lasttstamp = DbLog_explode_datetime($lastd[$i], undef);
      }
      if("$tstamp{day}" ne "$lasttstamp{day}") {
        # Aenderung des Tages, Berechne Delta
        $out_value = sprintf("%0.1f", $maxval - $minval);
        $out_tstamp = DbLog_implode_datetime($lasttstamp{year}, $lasttstamp{month}, $lasttstamp{day}, "00", "00", "00");
        $minval =  999999;
        $maxval = -999999;
        $writeout=1;
      }
    } elsif(@readings[$i]->[3]) {
      #evaluate
      my $val = $sql_value;
      eval("@readings[$i]->[3]");
	  $out_value = $val;

      if($@) {Log 3, "DbLog: Fehler in der übergebenen Funktion: <".@readings[$i]->[3].">, Fehler: $@";}
      $out_tstamp = $sql_timestamp;
      $writeout=1;
    } else {
      $out_value = $sql_value;
      $out_tstamp = $sql_timestamp;
      $writeout=1;
    }

    ###################### Ausgabe ###########################
    if($writeout) {
	  if(uc($outf) eq "ALL") {
	    $retval .= sprintf("%s: %s, %s, %s, %s, %s, %s\n", $out_tstamp, $sql_dev, $type, $event, $sql_reading, $out_value, $unit);
	  } else {
	    $out_tstamp =~ s/\ /_/g; #needed by generating plots
	    $retval .= "$out_tstamp $out_value\n";
	  }
	}

    if(defined($sql_value) || $sql_value =~ m/^[-\.\d]+$/o){
      #nur setzen wenn nummerisch
      $min[$i] = $sql_value if($sql_value < $min[$i]);
      $max[$i] = $sql_value if($sql_value > $max[$i]);;
      $sum[$i] += $sql_value;
      $minval = $sql_value if($sql_value < $minval);
      $maxval = $sql_value if($sql_value > $maxval);
    } else {
      $min[$i] = 0;
      $max[$i] = 0;
      $sum[$i] = 0;
      $minval  = 0;
      $maxval  = 0;
    }
    $cnt[$i]++;
    $lastv[$i] = $sql_value;
    $lastd[$i] = $sql_timestamp;

  } #while fetchrow

  ######## den letzten Abschlusssatz rausschreiben ##########
  if(@readings[$i]->[3] eq "delta-h" || @readings[$i]->[3] eq "delta-d") {
    $out_value = sprintf("%0.1f", $maxval - $minval);
    $out_tstamp = DbLog_implode_datetime($lasttstamp{year}, $lasttstamp{month}, $lasttstamp{day}, $lasttstamp{hour}, "30", "00") if(@readings[$i]->[3] eq "delta-h");
    $out_tstamp = DbLog_implode_datetime($lasttstamp{year}, $lasttstamp{month}, $lasttstamp{day}, "00", "00", "00") if(@readings[$i]->[3] eq "delta-d");
    if(uc($outf) eq "ALL") {
	  $retval .= sprintf("%s: %s %s %s %s %s %s\n", $out_tstamp, $sql_dev, $type, $event, $sql_reading, $out_value, $unit);
	} else {
	  $out_tstamp =~ s/\ /_/g; #needed by generating plots
	  $retval .= "$out_tstamp $out_value\n";
	}
  }
  # DatenTrenner setzen
  $retval .= "#@readings[$i]->[0]:@readings[$i]->[1]:@readings[$i]->[2]:@readings[$i]->[3]\n";
  } #for @readings

  #Ueberfuehren der gesammelten Werte in die globale Variable %data
  for(my $j=0; $j<int(@readings); $j++) {
   my $k = $j+1;
   $data{"min$k"} = $min[$j] == 999999 ? "undef" : $min[$j];
   $data{"max$k"} = $max[$j] == -999999 ? "undef" : $max[$j];
   $data{"avg$k"} = $cnt[$j] ? sprintf("%0.1f", $sum[$j]/$cnt[$j]) : "undef";
   $data{"sum$k"} = $sum[$j];
   $data{"cnt$k"} = $cnt[$j] ? $cnt[$j] : "undef";
   $data{"currval$k"} = $lastv[$j];
   $data{"currdate$k"} = $lastd[$j];
  }

  if($internal) {
  $internal_data = \$retval;
  return undef;
  }
  return $retval;
}
################################################################


# reload 93_DbLog.pm
# get DbLog_Bewaesserung - - 2012-06-22 2012-06-23 KS300:temperature:: KS300:humidity::
# get DbLog - - 2012-11-10_10 2012-11-10_20 KS300:rain:0:delta-h
# http://tulpemd.dyndns.org/fhem?cmd=showlog weblink_Bodenfeuchte_1 DbLog_Bodenfeuchte myDbLogtest null
#
# FileLog
# get FileLog_KS300 KS300-2012-11.log - 2012-11-10 2012-11-22 10:IR\x3a:0:delta-d

1;


=pod
=begin html
<a name="DbLog"></a>
<h3>DbLog</h3>
<ul>
  <br>

  <a name="DbLogdefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; DbLog &lt;configfilename&gt; &lt;regexp&gt;</code>
    <br><br>

    Log events to a database. The database connection is defined in
    <code>&lt;configfilename&gt;</code> (see sample configuration file
    <code>db.conf</code>). The configuration is stored in a separate file
    to avoid storing the password in the main configuration file and to have it
    visible in the output of the <a href="../docs/commandref.html#list">list</a> command.
    <br><br>

    You must have <code>93_DbLog.pm</code> in the <code>FHEM</code> subdirectory
    to make this work. Additionally, the modules <code>DBI</code> and
    <code>DBD::&lt;dbtype&gt;</code> need to be installed (use
    <code>cpan -i &lt;module&gt;</code> if your distribution does not have it).
    <br><br>

    <code>&lt;regexp&gt;</code> is the same as in <a href="../docs/commandref.html#FileLog">FileLog</a>.
    <br><br>
    Sample code to create a MySQL database is in <code>fhemdb_create.sql</code>.
    The database contains two tables: <code>current</code> and
    <code>history</code>. The latter contains all events whereas the former only
    contains the last event for any given reading and device.
    The columns have the following meaning:
    <ol>

    <li>TIMESTAMP: timestamp of event, e.g. <code>2007-12-30 21:45:22</code></li>
    <li>DEVICE: device name, e.g. <code>Wetterstation</code></li>
    <li>TYPE: device type, e.g. <code>KS300</code></li>
    <li>EVENT: event specification as full string,
                                        e.g. <code>humidity: 71 (%)</code></li>
    <li>READING: name of reading extracted from event,
                    e.g. <code>humidity</code></li>

    <li>VALUE: actual reading extracted from event,
                    e.g. <code>71</code></li>
    <li>UNIT: unit extracted from event, e.g. <code>%</code></li>
    </ol>
    The content of VALUE is optimized for automated post-processing, e.g.
    <code>yes</code> is translated to <code>1</code>
    <br><br>
    The current values can be retrieved by the following code like FileLog:<br>
    <ul>
      <code>get myDbLog - - 2012-11-10 2012-11-10 KS300:temperature::</code>
    </ul>
    <br><br>
    <b>Examples:</b>
    <ul>
        <code># log everything to database</code><br>

        <code>define myDbLog DbLog /etc/fhem/db.conf .*:.*</code>
    </ul>
  </ul>


  <a name="DbLogset"></a>
  <b>Set</b> <ul>N/A</ul><br>

  <a name="DbLogget"></a>
  <b>Get</b>
  <ul>
    <code>get &lt;name&gt; &lt;infile&gt; &lt;outfile&gt; &lt;from&gt;
          &lt;to&gt; &lt;column_spec&gt; </code>
    <br><br>
    Read data from the Database, used by frontends to plot data without direct
    access to the Database.<br>

    <ul>
      <li>&lt;in&gt;<br>
        A dummy parameter for FileLog compatibility. Always set to <code>-</code></li>
      <li>&lt;out&gt;<br>
        A dummy parameter for FileLog compatibility. Set it to <code>-</code>
		to check the output for plot-computing.<br>Set it to the special keyword
		<code>all</code> to get all columns from Database.</li>
      <li>&lt;from&gt; / &lt;to&gt;<br>
        Used to select the data. Please use the following timeformat or
        an initial substring of it:<br>
        <ul><code>YYYY-MM-DD_HH24:MI:SS</code></ul></li>
      <li>&lt;column_spec&gt;<br>
        For each column_spec return a set of data separated by
        a comment line on the current connection.<br>
        Syntax: &lt;device&gt;:&lt;reading&gt;:&lt;default&gt;:&lt;fn&gt;<br>
        <ul>
          <li>&lt;device&gt;<br>
            The name of the device. Case sensitive</li>
          <li>&lt;reading&gt;<br>
            The reading of the given device to select. Case sensitive.
            </li>
          <li>&lt;default&gt;<br>
            no implemented yet
            </li>
          <li>&lt;fn&gt;
            One of the following:
            <ul>
              <li>int<br>
                Extract the integer at the beginning of the string. Used e.g.
                for constructs like 10%</li>
              <li>int&lt;digit&gt;<br>
                Extract the decimal digits including negative character and
                decimal point at the beginning og the string. Used e.g.
                for constructs like 15.7&deg;C</li>
              <li>delta-h / delta-d<br>
                Return the delta of the values for a given hour or a given day.
                Used if the column contains a counter, as is the case for the
                KS300 rain column.</li>
              <li>everything else<br>
                The string is evaluated as a perl expression. $val is the
                current value returned from the Database.<br>Note: The string/perl
                expression cannot contain spaces, as the part after the space
                will be considered as the next column_spec.</li>
            </ul></li>
        </ul></li>
      </ul>
    <br><br>
    Examples:
      <ul>
        <li><code>get myDbLog - - 2012-11-10 2012-11-20 KS300:temperature::</code></li>
        <li><code>get myDbLog - - 2012-11-10_10 2012-11-10_20 KS300:temperature::int1</code><br>
           like from 10am until 20pm at 10.11.2012</li>
        <li><code>get myDbLog - all 2012-11-10 2012-11-20 KS300:temperature::</code></li>
        <li><code>get myDbLog - - 2012-11-10 2012-11-20 KS300:temperature:: KS300:rain::delta-h KS300:rain::delta-d</code></li>
        <li><code>get myDbLog - - 2012-11-10 2012-11-20 MyFS20:data::$val=~s/(on|off).*/$1eq"on"?1:0/eg</code><br>
		   return 1 for all occurance of on* (on|on-for-timer etc) and 0 for all off*</li>
		<li><code>get myDbLog - - 2012-11-10 2012-11-20 Bodenfeuchte:data::$val=~s/.*B:\s([-\.\d]+).*/$1/eg</code><br>
		   Example of OWAD: value like this: <code>"A: 49.527 % B: 66.647 % C: 9.797 % D: 0.097 V"</code><br>
		   and output for port B is like this: <code>2012-11-20_10:23:54 66.647</code></li>
      </ul>
    <br><br>
  </ul>
  <a name="DbLogattr"></a>
  <b>Attributes</b> <ul>N/A</ul><br>
</ul>
=end html

=begin html_DE

=end html_DE
=cut
