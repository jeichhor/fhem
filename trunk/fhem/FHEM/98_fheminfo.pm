=for comment

# $Id$

This script free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
any later version.

The GNU General Public License can be found at
http://www.gnu.org/copyleft/gpl.html.
A copy is found in the textfile GPL.txt and important notices to the license
from the author is found in LICENSE.txt distributed with these scripts.

This script is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

=cut

package main;
use strict;
use warnings;
use Config;
use HttpUtils;

my $c_system  = 'system';
my $c_noModel = 'noModel';

my %fhemInfo =();

my @ignoreList = qw(Global);

sub fheminfo_Initialize($$) {
  my %hash = (
    Fn  => "CommandFheminfo",
    uri => "https://fhem.de/stats/statistics2.cgi",
    Hlp => "[send],show or send Fhem statistics",
  );
  $cmds{fheminfo} = \%hash;
}

sub CommandFheminfo($$) {
  my ($cl,$param) = @_;
  my @args = split("[ \t]+", $param);
  $args[0] = defined($args[0]) ? lc($args[0]) : "";
  my $doSend = ($args[0] eq 'send') ? 1 : 0;

  return "Unknown argument $args[0], usage: fheminfo [send]"
    if($args[0] ne "send" && $args[0] ne "");

  return "Won't send, as sendStatistics is set to 'never'."
    if($doSend &&  lc(AttrVal("global","sendStatistics","")) eq "never");

  _fi2_Count();

  return toJSON(\%fhemInfo) if (defined($args[1]) && $args[1] eq 'debug');

  _fi2_Send() if $args[0] eq 'send';

# do not return statistics data if called from update
  return "Statistics data sent to server. See Logfile (level 4) for details." unless defined($cl);

  return _fi2_TelnetTable($doSend) if ($cl && $cl->{TYPE} eq 'telnet');
  return _fi2_HtmlTable($doSend);
}

################################################################
# tools
#
sub _fi2_Count() {
   my $uniqueID = getUniqueId();
   my $release  = "5.8";
   my $feature  = $featurelevel ? $featurelevel : $release;
   my $os       = $^O;
   my $arch     = $Config{"archname"};
   my $perl     = sprintf("%vd", $^V);

   %fhemInfo = ();

   $fhemInfo{$c_system}{'uniqueID'}   = $uniqueID;
   $fhemInfo{$c_system}{'release'}    = $release;
   $fhemInfo{$c_system}{'feature'}    = $feature;
   $fhemInfo{$c_system}{'os'}         = $os;
   $fhemInfo{$c_system}{'arch'}       = $arch;
   $fhemInfo{$c_system}{'perl'}       = $perl;
   $fhemInfo{$c_system}{'revision'}   = _fi2_findRev();
   $fhemInfo{$c_system}{'configType'} = configDBUsed() ? 'configDB' : 'configFile';

   foreach my $key ( keys %defs )
   {
      next if (defined($defs{$key}{'TEMPORARY'}) || defined($defs{$key}{'VOLATILE'})); 
      my $name  = $defs{$key}{NAME};
      my $type  = $defs{$key}{TYPE};
      my $model = $c_noModel;
         $model = defined($defs{$key}{model}) ? $defs{$key}{model} : $model;
         $model = defined($defs{$key}{MODEL}) ? $defs{$key}{MODEL} : $model;
         # special for DbLog
         $model = defined($defs{$key}{DBMODEL}) ? $defs{$key}{DBMODEL} : $model
                  if ($type eq 'DbLog');
         $model = AttrVal($name,'model',$model);
         $model = ReadingsVal($name,'model',$model);
         # special for ZWave
         $model = ReadingsVal($name,'modelId',$model) 
                  if ($type eq 'ZWave');
         $model = $c_noModel if (ref $model);
      next if ( ($model =~ /^unkno.*/i) || ($model =~ /virtual.*/i) || ($model eq '?') || ($model eq '1') || 
                (defined($defs{$key}{'chanNo'})) || ($name =~ m/^unknown_/) );
      $fhemInfo{$type}{$model}++ ;
   }

# now do some special handlings

# add model info for configDB if used
   eval { $fhemInfo{'configDB'}{_cfgDB_type()}++ if configDBUsed(); };

# delete all modules listed in ignoreList
   foreach my $i (@ignoreList) { delete $fhemInfo{$i}; }

   return;
}

sub _fi2_Send() {
   my $json = toJSON(\%fhemInfo);

   Log3("fheminfo",4,"fheminfo: $json");

   my %hu_hash = ();
   $hu_hash{url}      = $cmds{fheminfo}{uri};
   $hu_hash{data}     = "uniqueID=".$fhemInfo{$c_system}{'uniqueID'}."&json=$json";
   $hu_hash{header}   = "User-Agent: FHEM/".$fhemInfo{$c_system}{'release'};
   $hu_hash{callback} = sub($$$) {
        my ($hash, $err, $data) = @_;
        if($err) {
          Log 1, "fheminfo send: Server ERROR: $err";
        } else {
          Log3("fheminfo",4,"fheminfo send: Server RESPONSE: $data");
        }
      };
   HttpUtils_NonblockingGet(\%hu_hash);
   return;
}

sub _fi2_TelnetTable($) {
  my ($doSend) = shift;
  my $upTime = _fi2_Uptime();
  my $str;
  $str .= "Following statistics data will be sent to server:\n(see Logfile level 4 for server response)\n\n" if($doSend == 1);
  $str .= "System Info\n";
  $str .= sprintf("  Release%*s: %s\n",6," ",$fhemInfo{$c_system}{'release'});
  $str .= sprintf("  FeatureLevel%*s: %s\n",0," ",$fhemInfo{$c_system}{'feature'});
  $str .= sprintf("  SVN revision%*s: %s\n",0," ",$fhemInfo{$c_system}{'revision'});
  $str .= sprintf("  OS%*s: %s\n",11," ",$fhemInfo{$c_system}{'os'});
  $str .= sprintf("  Arch%*s: %s\n",9," ",$fhemInfo{$c_system}{'arch'});
  $str .= sprintf("  Perl%*s: %s\n",9," ",$fhemInfo{$c_system}{'perl'});
  $str .= sprintf("  uniqueID%*s: %s\n",5," ",$fhemInfo{$c_system}{'uniqueID'});
  $str .= sprintf("  upTime%*s: %s\n",7,"  ",$upTime); 

   my @keys = keys %fhemInfo;
   foreach my $type (sort @keys)
   {
      next if $type eq $c_system;
      $str .= "\nType: $type ";
      $str .= "Count: ".$fhemInfo{$type}{$c_noModel} if defined $fhemInfo{$type}{$c_noModel};
      $str .= "\n";
      while ( my ($model, $count) = each(%{$fhemInfo{$type}}) )
      { $str .= "     $model = $fhemInfo{$type}{$model}\n" unless $model eq $c_noModel; }
   }

  return $str;
}

sub _fi2_HtmlTable($) {
   my ($doSend) = shift;
   my $upTime = _fi2_Uptime();
   my $result  = "<html><table>";
      $result .= "<tr><td colspan='3'>Following statistics data will be sent to server:</br>(see Logfile level 4 for server response)</td></tr>" if($doSend == 1);
      $result .= "<tr><td>System Info</td></tr>";
      $result .= "<tr><td> </td><td>Release:</td><td>$fhemInfo{$c_system}{'release'}</td></tr>";
      $result .= "<tr><td> </td><td>FeatureLevel:</td><td>$fhemInfo{$c_system}{'feature'}</td></tr>";
      $result .= "<tr><td> </td><td>ConfigType:</td><td>$fhemInfo{$c_system}{'configType'}</td></tr>";
            $result .= "<tr><td> </td><td>SVN rev:</td><td>$fhemInfo{$c_system}{'revision'}</td></tr>" 
                  if (defined($fhemInfo{$c_system}{'revision'}));
      $result .= "<tr><td> </td><td>OS:</td><td>$fhemInfo{$c_system}{'os'}</td></tr>";
      $result .= "<tr><td> </td><td>Arch:</td><td>$fhemInfo{$c_system}{'arch'}</td></tr>";
      $result .= "<tr><td> </td><td>Perl:</td><td>$fhemInfo{$c_system}{'perl'}</td></tr>";
      $result .= "<tr><td> </td><td>uniqueId:</td><td>$fhemInfo{$c_system}{'uniqueID'}</td></tr>";
      $result .= "<tr><td> </td><td>upTime:</td><td>$upTime</td></tr>";
      $result .= "<tr><td>Modules</td><td>Model</td><td>Count</td></tr>";

   my @keys = keys %fhemInfo;
   foreach my $type (sort @keys)
   {
      next if ($type eq $c_system);
      $fhemInfo{$type}{$c_noModel} //= '';
      $result .= "<tr><td>$type</td><td> </td><td>$fhemInfo{$type}{$c_noModel}</td></tr>";
      while ( my ($model, $count) = each(%{$fhemInfo{$type}}) )
      { $result .= "<tr><td> </td><td>$model</td><td>$fhemInfo{$type}{$model}</td></tr>" unless $model eq $c_noModel; }
   }  

   $result .= "</table></html>";
   return $result;
}

sub _fi2_Uptime() {
  my $diff = time - $fhem_started;
  my ($d,$h,$m,$ret);
  
  ($d,$diff) = _fi2_Div($diff,86400);
  ($h,$diff) = _fi2_Div($diff,3600);
  ($m,$diff) = _fi2_Div($diff,60);

  $ret  = "";
  $ret .= "$d days, " if($d >  1);
  $ret .= "1 day, "   if($d == 1);
  $ret .= sprintf("%02s:%02s:%02s", $h, $m, $diff);

  return $ret;
}

sub _fi2_Div($$) {
  my ($p1,$p2) = @_;
  return (int($p1/$p2), $p1 % $p2);
}

sub _fi2_findRev {
   my $cf = 'controls_fhem.txt';
   my $filename = (-e "./$cf") ? "./$cf" : AttrVal("global","modpath",".")."/FHEM/$cf";
   my ($err, @content) = FileRead({FileName => $filename, ForceType => "file"});
   return if $err;
   my (undef,$rev) = split (/ /,$content[0]);
   return $rev;
}

1;

=pod
=item command
=item summary    display information about the system and FHEM definitions
=item summary_DE zeigt Systeminformationen an
=begin html

<a name="fheminfo"></a>
<h3>fheminfo</h3>
<ul>
  <code>fheminfo [send]</code>
  <br>
  <br>
    fheminfo displays information about the system and FHEM definitions.
  <br>
  <br>
    The optional parameter <code>send</code> transmitts the collected data
    to a central server in order to support the development of FHEM. The
    transmitted data is processed graphically. The results can be viewed
    on <a href="http://fhem.de/stats/statistics.html">http://fhem.de/stats/statistics.html</a>.
    Based on the IP address, the approximate location is determined with
    an accuracy of about 40-80 km. The IP address is not saved.
  <br>
  <br>
    Features:<br>
    <ul>
      <li>Operating System Information</li>
      <li>Hardware architecture</li>
      <li>Installed Perl version</li>
      <li>Installed FHEM release</li>
      <li>Defined modules (only official FHEM Modules are counted)</li>
      <li>Defined models per module</li>
    </ul>
  <br>

  <a name="fheminfoattr"></a>
  <b>Attributes</b>
  <br>
  <br>
    The following attributes are used only in conjunction with the
    <code>send</code> parameter. They are set on <code>attr global</code>.
  <br>
  <br>
  <ul>
    <li>sendStatistics<br>
      This attribute is used in conjunction with the <code>update</code> command.
      <br>
      <code>onUpdate</code>: transfer of data on every update (recommended setting).
      <br>
      <code>manually</code>: manually transfer of data via the <code>fheminfo send</code> command.
      <br>
      <code>never</code>: prevents transmission of data at anytime.
    </li>
    <br>
  </ul>
</ul>

=end html
=cut
