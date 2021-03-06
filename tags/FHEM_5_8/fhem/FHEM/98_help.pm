# $Id$
#
package main;
use strict;
use warnings;
use Data::Dumper;

my $ret;

sub CommandHelp;
sub cref_search;
sub cref_search_cmd;

sub help_Initialize($$) {
  my %hash = (  Fn => "CommandHelp",
		   Hlp => "[<moduleName>],get help (this screen or module dependent docu)",
		   InternalCmds => "attributes,command,commands,devspec,global,perl" );
  $cmds{help} = \%hash;
}

sub CommandHelp {
  my ($cl, $arg) = @_;

  my ($mod,$lang) = split(" ",$arg);
  
  $lang //= AttrVal('global','language','en');
  $lang = (lc($lang) eq 'de') ? '_DE' : '';

  if($mod) {

    $mod = "help" if($mod eq "?");
    $mod = $defs{$mod}->{TYPE} if( defined($defs{$mod}) && $defs{$mod}->{TYPE} );
  
    my $internals = "attributes,command,commands,devspec,global,perl";
    $mod = lc($mod);
    my $modPath = AttrVal('global','modpath','.');
	my $output = '';

	if($cmds{help}{InternalCmds} !~ m/$mod\,/) {
      my %mods;
	  my @modDir = ("$modPath/FHEM");

      $mod = $cmds{$mod}{ModuleName} if defined($cmds{$mod}{ModuleName});

	  foreach my $modDir (@modDir) {
	    eval { opendir(DH, $modDir); }; # || die "Cant open $modDir: $!\n";
	    while(my $l = readdir DH) {
	      next if($l !~ m/^\d\d_.*\.pm$/);
	      my $of = $l;
	      $l =~ s/.pm$//;
	      $l =~ s/^[0-9][0-9]_//;
	      $mods{lc($l)} = "$modDir/$of";
	    }
	  }

      return "Module $mod not found" unless defined($mods{$mod});

      # read commandref docu from file
      $output = cref_search($mods{$mod},$lang);

      unless($output) {
         $output = cref_search($mods{$mod},"");
         $output = "Keine deutsche Hilfe gefunden!<br/>$output" if $output;
      }
      
      $output = "No help found for module: $mod" unless $output;

    } else {

      $output = '';
	  my $i;
	  my $f = "$modPath/docs/commandref_frame$lang.html";
      my $skip = 1;
	  my ($err,@text) = FileRead({FileName => $f, ForceType => 'file'});
	  return $err if $err;

	  foreach my $l (@text) {
        if($l =~ m/^<a name=\"$mod\"/) { 
           $skip = 0;
        } elsif($l =~ m/^<!-- $mod.end/) {
           $skip = 1;
        } elsif (!$skip) {
           $output .= $l;
        }
	  }   

	}

    if( $cl  && $cl->{TYPE} eq 'telnet' ) { # telnet output      
    $output =~ s/<br\s*\?>/\n/ig;
    $output =~ s/\s*<li>\s*/\n- /ig;
    $output =~ s/<\/?ul>/\n/ig;
    $output =~ s/<\/?[^>]+>//g;
    $output =~ s/&lt;/</g;
    $output =~ s/&gt;/>/g;
    $output =~ tr/ / /s;
    $output =~ s/\n\n\ /\n/g;
    $output =~ s/&nbsp;/ /g;
    $output =~ s/&auml;/ä/g;
    $output =~ s/&Auml;/Ä/g;
    $output =~ s/&ouml;/ö/g;
    $output =~ s/&Ouml;/Ö/g;
    $output =~ s/&uuml;/ü/g;
    $output =~ s/&Uuml;/Ü/g;
    $output =~ s/&szlig;/ß/g;
    $output =~ s/\n\s*\n\s*\n/\n\n\n/g; 
    $output =~ s/^\s+//;
    $output =~ s/\s+$//;
    
    } else  { # html output
      my $url_prefix;

      if(AttrVal('global','exclude_from_update','') =~ m/commandref/) {
        $url_prefix = "http://fhem.de/commandref$lang.html";
      } else {
        $url_prefix = "$FW_ME/docs/commandref$lang.html";
      }

      # replace <a href="#..."> tags with a
      # working real link to commandref
      $output =~ s,<a\s+href="#,<a target="_blank" href="$url_prefix#,g;
      $output = "<html>$output</html>";
    }
    
    return $output;

  } else {   # mod

    cref_search_cmd(undef);

    my $str = "Possible commands:\n\n" .
		"Command        Parameter\n" .
		"               Description\n" .
	    "----------------------------------------------------------------------\n";

    for my $cmd (sort keys %cmds) {
      next if($cmd =~ m/header:command/);
      next if(!$cmds{$cmd}{Hlp});
      next if($cl && $cmds{$cmd}{ClientFilter} &&
           $cl->{TYPE} !~ m/$cmds{$cmd}{ClientFilter}/);
      my @a = split(",", $cmds{$cmd}{Hlp}, 2);
 #     $a[0] =~ s/</&lt;/g;
 #     $a[0] =~ s/>/&gt;/g;
      $a[1] //= "";
      $a[1]  = "               $a[1]";
#      $a[1] =~ s/</&lt;/g;
#      $a[1] =~ s/>/&gt;/g;
      $str .= sprintf("%-15s%-50s\n%s\n", $cmd, $a[0], $a[1]);
    }

    return $str;

  }
}

sub cref_search {
   my ($mod,$lang) = @_;
   my $output = "";
   my $skip = 1;
   my ($err,@text) = FileRead({FileName => $mod, ForceType => 'file'});
   return $err if $err;
   foreach my $l (@text) {
     if($l =~ m/^=begin html$lang$/) {
	    $skip = 0;
     } elsif($l =~ m/^=end html$lang$/) {
        $skip = 1;
     } elsif(!$skip) {
        $output .= "$l\n";
     }
   }
   return $output;
}

sub cref_search_cmd {
   my $skip = 1;
   my $mod = "./docs/commandref_frame.html";
   my ($err,@text) = FileRead({FileName => $mod, ForceType => 'file'});
   return $err if $err;
   foreach my $l (@text) {
     if($l =~ m/<b>Fhem commands<\/b>/) {
	    $skip = 0;
     } elsif($l =~ m/<\/ul>/) {
        $skip = 1;
     } elsif(!$skip && $l !~ m/<ul>/) {
        $l =~ s/\?\,help//;
        $l =~ s/<a.*">//;
        $l =~ s/<\/a>.*//;
        $l =~ s/ //g;
        unless (defined($cmds{$l}{Hlp}) && $cmds{$l}{Hlp}) {
           my %hash = ( Hlp => "use \"help $l\" for more help");
           $cmds{$l} = \%hash if $l;
        }
     }
   }
   foreach my $i (split(",",$cmds{help}{InternalCmds})) {
      my %hash = ( Hlp => "use \"help $i\" for more help");
      $cmds{$i} = \%hash if $i;
   }  
   return;
}


1;

=pod
=item command
=item summary    show help for module or device
=item summary_DE Hilfe f&uuml;r Module und Ger&auml;te
=begin html

<a name="help"></a>
<h3>?, help</h3>
  <ul>
    <code>? [&lt;moduleName|deviceName&gt;] [<language>]</code><br/>
    <code>help [&lt;moduleName|deviceName&gt;] [<language>]</code><br/>
    <br/>
    <ul>
      <li>Returns a list of available commands, when called without a
        moduleName/deviceName.</li>
      <li>Returns a module dependent helptext, same as in commandref.</li>
      <li>language will be determined in following order: 
         <ul>
         <li>valid parameter &lt;language&gt; given</li>
         <li>global attribute language</li>
         <li>nothing founde: return english</li>
         </ul>
      </li>
    </ul>
  </ul>

=end html

=begin html_DE

<a name="help"></a>
<h3>?, help</h3>
  <ul>
    <code>? [&lt;moduleName|deviceName&gt;] [<language>]</code><br/>
    <code>help [&lt;moduleName|deviceName&gt;] [<language>]</code><br/>
    <br>
    <ul>
      <li>Liefert eine Liste aller Befehle mit einer Kurzbeschreibung zur&uuml;ck.</li>
      <li>Falls moduleName oder deviceName spezifiziert ist, wird die modul-spezifische Hilfe
          aus commandref zur&uuml;ckgeliefert.</li>
      <li>Die anzuzeigende Sprache wird in folgender Reihenfolge bestimmt: 
         <ul>
         <li>g&uuml;ltiger Parameter &lt;language&gt; beim Aufruf &uuml;bergeben</li>
         <li>globales Attribut language</li>
         <li>falls alles fehlt: englisch</li>
         </ul>
      </li>
    </ul>
  </ul>
=end html_DE

=cut
