##############################################
# $Id$
package main;

# TODO: test SSL

use strict;
use warnings;
use TcpServerUtils;
use MIME::Base64;

sub MQTT2_SERVER_Read($@);
sub MQTT2_SERVER_Write($$$);
sub MQTT2_SERVER_Undef($@);
sub MQTT2_SERVER_doPublish($$$$;$);


# See also:
# http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html

sub
MQTT2_SERVER_Initialize($)
{
  my ($hash) = @_;

  $hash->{Clients} = ":MQTT2_DEVICE:";
  $hash->{MatchList}= { "1:MQTT2_DEVICE"  => "^.*" },
  $hash->{ReadFn}  = "MQTT2_SERVER_Read";
  $hash->{DefFn}   = "MQTT2_SERVER_Define";
  $hash->{AttrFn}  = "MQTT2_SERVER_Attr";
  $hash->{SetFn}   = "MQTT2_SERVER_Set";
  $hash->{UndefFn} = "MQTT2_SERVER_Undef";
  $hash->{WriteFn} = "MQTT2_SERVER_Write";
  $hash->{StateFn} = "MQTT2_SERVER_State";
  $hash->{CanAuthenticate} = 1;

  no warnings 'qw';
  my @attrList = qw(
    disable:0,1
    disabledForIntervals
    autocreate
    rawEvents
    SSL:0,1
  );
  use warnings 'qw';
  $hash->{AttrList} = join(" ", @attrList);
}

#####################################
sub
MQTT2_SERVER_Define($$)
{
  my ($hash, $def) = @_;
  my ($name, $type, $port, $global) = split("[ \t]+", $def);
  return "Usage: define <name> MQTT2_SERVER [IPV6:]<tcp-portnr> [global]"
        if($port !~ m/^(IPV6:)?\d+$/);

  MQTT2_SERVER_Undef($hash, undef) if($hash->{OLDDEF}); # modify
  my $ret = TcpServer_Open($hash, $port, $global);

  # Make sure that fhem only runs once
  if($ret && !$init_done) {
    Log3 $hash, 1, "$ret. Exiting.";
    exit(1);
  }
  readingsSingleUpdate($hash, "nrclients", 0, 0);
  $hash->{clients} = {};
  $hash->{retain} = {};
  InternalTimer(1, "MQTT2_SERVER_keepaliveChecker", $hash, 0);
  return $ret;
}

sub
MQTT2_SERVER_keepaliveChecker($)
{
  my ($hash) = @_;
  my $now = gettimeofday();
  my $multiplier = AttrVal($hash, "keepaliveFactor", 1.5);
  if($multiplier) {
    foreach my $clName (keys %{$hash->{clients}}) {
      my $cHash = $defs{$clName};
      next if(!$cHash || !$cHash->{keepalive} ||
               $now < $cHash->{lastMsgTime}+$cHash->{keepalive}*$multiplier );
      Log3 $hash, 3, "$hash->{NAME}: $clName left us (keepalive check)";
      CommandDelete(undef, $clName);
    }
  }
  InternalTimer($now+10, "MQTT2_SERVER_keepaliveChecker", $hash, 0);
}

sub
MQTT2_SERVER_Undef($@)
{
  my ($hash, $arg) = @_;
  my $ret = TcpServer_Close($hash);
  my $sname = $hash->{SNAME};
  return undef if(!$sname);

  my $shash = $defs{$sname};
  delete($shash->{clients}{$hash->{NAME}});
  readingsSingleUpdate($shash, "nrclients",
                       ReadingsVal($sname, "nrclients", 1)-1, 1);

  if($hash->{lwt}) {    # Last will

    # skip lwt if there is another connection with the same ip+cid (tasmota??)
    for my $dev (keys %defs) {
      my $h = $defs{$dev};
      next if($h->{TYPE} ne $hash->{TYPE} ||
              $h->{NR} == $hash->{NR} ||
              !$h->{cid}  || $h->{cid}  ne $hash->{cid} ||
              !$h->{PEER} || $h->{PEER} ne $hash->{PEER});
      Log3 $shash, 4,
        "Closing second connection for $h->{cid}/$h->{PEER} without lwt";
      return $ret;
    }

    my ($tp, $val) = split(':', $hash->{lwt}, 2);
    MQTT2_SERVER_doPublish($hash, $shash, $tp, $val, $hash->{cflags} & 0x20);
  }
  return $ret;
}

sub
MQTT2_SERVER_Attr(@)
{
  my ($type, $devName, $attrName, @param) = @_;
  my $hash = $defs{$devName};
  if($type eq "set" && $attrName eq "SSL") {
    TcpServer_SetSSL($hash);
  }
  return undef;
} 

sub
MQTT2_SERVER_Set($@)
{
  my ($hash, @a) = @_;
  my %sets = ( publish=>1 );
  shift(@a);

  return "Unknown argument ?, choose one of ".join(" ", keys %sets)
        if(!$a[0] || !$sets{$a[0]});

  if($a[0] eq "publish") {
    shift(@a);
    my $retain;
    if(@a>2 && $a[0] eq "-r") {
      $retain = 1;
      shift(@a);
    }
    return "Usage: publish -r topic [value]" if(@a < 1);
    my $tp = shift(@a);
    my $val = join(" ", @a);
    MQTT2_SERVER_doPublish($hash->{CL}, $hash, $tp, $val, $retain);
  }
}

sub
MQTT2_SERVER_State()
{
  my ($hash, $ts, $name, $val) = @_;

  if($name eq "RETAIN") {
    my $now = gettimeofday;
    my $ret = json2nameValue($val);
    for my $k (keys %{$ret}) {
      my %h = ( ts=>$now, val=>$ret->{$k} );
      $hash->{retain}{$k} = \%h;
    }
  }
  return undef;
}

my %cptype = (
  0 => "RESERVED_0",
  1 => "CONNECT",
  2 => "CONNACK",
  3 => "PUBLISH",
  4 => "PUBACK",
  5 => "PUBREC",
  6 => "PUBREL",
  7 => "PUBCOMP",
  8 => "SUBSCRIBE",
  9 => "SUBACK",
 10 => "UNSUBSCRIBE",
 11 => "UNSUBACK",
 12 => "PINGREQ",
 13 => "PINGRESP",
 14 => "DISCONNECT",
 15 => "RESERVED_15",
);

#####################################
sub
MQTT2_SERVER_Read($@)
{
  my ($hash, $reread) = @_;

  if($hash->{SERVERSOCKET}) {   # Accept and create a child
    my $nhash = TcpServer_Accept($hash, "MQTT2_SERVER");
    return if(!$nhash);
    $nhash->{CD}->blocking(0);
    readingsSingleUpdate($hash, "nrclients",
                         ReadingsVal($hash->{NAME}, "nrclients", 0)+1, 1);
    return;
  }

  my $sname = $hash->{SNAME};
  my $cname = $hash->{NAME};
  my $c = $hash->{CD};

  if(!$reread) {
    my $buf;
    my $ret = sysread($c, $buf, 1024);

    if(!defined($ret) && $! == EWOULDBLOCK ){
      $hash->{wantWrite} = 1
        if(TcpServer_WantWrite($hash));
      return;

    } elsif(!$ret) {
      CommandDelete(undef, $cname);
      Log3 $sname, 4, "Connection closed for $cname: ".
        (defined($ret) ? 'EOF' : $!);
      return;
    }

    $hash->{BUF} .= $buf;
    if($hash->{SSL} && $c->can('pending')) {
      while($c->pending()) {
        sysread($c, $buf, 1024);
        $hash->{BUF} .= $buf;
      }
    }
  }

  my ($tlen, $off) = MQTT2_SERVER_getRemainingLength($hash);
  if($tlen < 0) {
    Log3 $sname, 1, "Bogus data from $cname, closing connection";
    CommandDelete(undef, $cname);
  }
  return if(length($hash->{BUF}) < $tlen+$off);

  my $fb = substr($hash->{BUF}, 0, 1);
  my $pl = substr($hash->{BUF}, $off, $tlen); # payload
  $hash->{BUF} = substr($hash->{BUF}, $tlen+$off);

  my $cp = ord(substr($fb,0,1)) >> 4;
  my $cpt = $cptype{$cp};
  $hash->{lastMsgTime} = gettimeofday();

  # Lowlevel debugging
  # my $pltxt = $pl;
  # $pltxt =~ s/([^ -~])/"(".ord($1).")"/ge;
  # Log3 $sname, 5, "$pltxt";

  if(!defined($hash->{cid}) && $cpt ne "CONNECT") {
    Log3 $sname, 2, "$cname $cpt before CONNECT, disconnecting";
    CommandDelete(undef, $cname);
    return MQTT2_SERVER_Read($hash, 1);
  }

  ####################################
  if($cpt eq "CONNECT") {
    ($hash->{protoTxt}, $off) = MQTT2_SERVER_getStr($pl, 0); # V3:MQIsdb V4:MQTT
    $hash->{protoNum}  = unpack('C*', substr($pl,$off++,1)); # 3 or 4
    $hash->{cflags}    = unpack('C*', substr($pl,$off++,1));
    $hash->{keepalive} = unpack('n', substr($pl, $off, 2)); $off += 2;
    ($hash->{cid}, $off) = MQTT2_SERVER_getStr($pl, $off);

    if(!($hash->{cflags} & 0x02)) {
      Log3 $sname, 2, "$cname wants unclean session, disconnecting";
      return MQTT2_SERVER_terminate($hash, pack("C*", 0x20, 2, 0, 1));
    }

    my $desc = "keepAlive:$hash->{keepalive}";
    if($hash->{cflags} & 0x04) { # Last Will & Testament
      my ($wt, $wm);
      ($wt, $off) = MQTT2_SERVER_getStr($pl, $off);
      ($wm, $off) = MQTT2_SERVER_getStr($pl, $off);
      $hash->{lwt} = "$wt:$wm";
      $desc .= " LWT:$wt:$wm";
    }

    my ($pwd, $usr) = ("","");
    if($hash->{cflags} & 0x80) {
      ($usr,$off) = MQTT2_SERVER_getStr($pl,$off);
      $hash->{usr} = $usr;
      $desc .= " usr:$hash->{usr}";
    }

    if($hash->{cflags} & 0x40) {
      ($pwd, $off) = MQTT2_SERVER_getStr($pl,$off);
    }

    my $ret = Authenticate($hash, "basicAuth:".encode_base64("$usr:$pwd"));
    return MQTT2_SERVER_terminate($hash, pack("C*", 0x20, 2, 0, 4)) if($ret==2);

    $hash->{subscriptions} = {};
    $defs{$sname}{clients}{$cname} = 1;

    Log3 $sname, 4, "$cname $hash->{cid} $cpt V:$hash->{protoNum} $desc";
    addToWritebuffer($hash, pack("C*", 0x20, 2, 0, 0)); # CONNACK, no error

  ####################################
  } elsif($cpt eq "PUBLISH") {
    my $cf = ord(substr($fb,0,1)) & 0xf;
    my $qos = ($cf & 0x06) >> 1;
    my ($tp, $val, $pid);
    ($tp, $off) = MQTT2_SERVER_getStr($pl, 0);
    if($qos) {
      $pid = unpack('n', substr($pl, $off, 2));
      $off += 2;
    }
    $val = substr($pl, $off);
    Log3 $sname, 4, "$cname $hash->{cid} $cpt $tp:$val";
    addToWritebuffer($hash, pack("CCnC*", 0x40, 2, $pid)) if($qos); # PUBACK
    MQTT2_SERVER_doPublish($hash, $defs{$sname}, $tp, $val, $cf & 0x01);

  ####################################
  } elsif($cpt eq "PUBACK") { # ignore it

  ####################################
  } elsif($cpt eq "SUBSCRIBE") {
    Log3 $sname, 4, "$cname $hash->{cid} $cpt";
    my $pid = unpack('n', substr($pl, 0, 2));
    my ($subscr, @ret);
    $off = 2;
    while($off < $tlen) {
      ($subscr, $off) = MQTT2_SERVER_getStr($pl, $off);
      my $qos = unpack("C*", substr($pl, $off++, 1));
      $hash->{subscriptions}{$subscr} = $hash->{lastMsgTime};
      Log3 $sname, 4, "  topic:$subscr qos:$qos";
      push @ret, ($qos > 1 ? 1 : 0);    # max qos supported is 1
    }
    addToWritebuffer($hash, pack("CCnC*", 0x90, 3, $pid, @ret)); # SUBACK

    if(!$hash->{answerScheduled}) {
      $hash->{answerScheduled} = 1;
      InternalTimer($hash->{lastMsgTime}+1, sub(){
        delete($hash->{answerScheduled});
        my $r = $defs{$sname}{retain};
        foreach my $tp (sort { $r->{$a}{ts} <=> $r->{$b}{ts} } keys %{$r}) {
          MQTT2_SERVER_sendto($defs{$sname}, $hash, $tp, $r->{$tp}{val});
        }
      }, undef, 0);
    }

  ####################################
  } elsif($cpt eq "UNSUBSCRIBE") {
    Log3 $sname, 4, "$cname $hash->{cid} $cpt";
    my $pid = unpack('n', substr($pl, 0, 2));
    my ($subscr, @ret);
    $off = 2;
    while($off < $tlen) {
      ($subscr, $off) = MQTT2_SERVER_getStr($pl, $off);
      delete $hash->{subscriptions}{$subscr};
      Log3 $sname, 4, "  topic:$subscr";
    }
    addToWritebuffer($hash, pack("CCn", 0xb0, 2, $pid)); # UNSUBACK

  ####################################
  } elsif($cpt eq "PINGREQ") {
    Log3 $sname, 4, "$cname $hash->{cid} $cpt";
    addToWritebuffer($hash, pack("C*", 0xd0, 0)); # pingresp

  ####################################
  } elsif($cpt eq "DISCONNECT") {
    Log3 $sname, 4, "$cname $hash->{cid} $cpt";
    CommandDelete(undef, $cname);

  ####################################
  } else {
    Log 1, "M2: Unhandled packet $cpt, disconneting $cname";
    CommandDelete(undef, $cname);

  }
  return MQTT2_SERVER_Read($hash, 1);
}

######################################
# Call sendto for all clients + Dispatch + dotrigger if rawEvents is set
# tgt is the "accept" server, src is the connection generating the data
sub
MQTT2_SERVER_doPublish($$$$;$)
{
  my ($src, $tgt, $tp, $val, $retain) = @_;
  $val = "" if(!defined($val));
  $src = $tgt if(!defined($src));

  if($retain) {
    my $now = gettimeofday();
    my %h = ( ts=>$now, val=>$val );
    $tgt->{retain}{$tp} = \%h;

    # Save it
    my %nots = map { $_ => $tgt->{retain}{$_}{val} } keys %{$tgt->{retain}};
    setReadingsVal($tgt, "RETAIN", toJSON(\%nots), FmtDateTime(gettimeofday()));
  }

  foreach my $clName (keys %{$tgt->{clients}}) {
    MQTT2_SERVER_sendto($tgt, $defs{$clName}, $tp, $val)
        if($src->{NAME} ne $clName);
  }

  if(defined($src->{cid})) { # "real" MQTT client
    my $cid = $src->{cid};
    $cid =~ s,[^a-z0-9._],_,gi;
    my $ac = AttrVal($tgt->{NAME}, "autocreate", undef) ? "autocreate:":"";
    Dispatch($tgt, "$ac$cid:$tp:$val", undef, !$ac);
    my $re = AttrVal($tgt->{NAME}, "rawEvents", undef);
    DoTrigger($tgt->{NAME}, "$tp:$val") if($re && $tp =~ m/$re/);
  }
}

######################################
# send topic to client if its subscription matches the topic
sub
MQTT2_SERVER_sendto($$$$)
{
  my ($shash, $hash, $topic, $val) = @_;
  return if(IsDisabled($hash->{NAME}));
  $val = "" if(!defined($val));
  foreach my $s (keys %{$hash->{subscriptions}}) {
    my $re = $s;
    $re =~ s,/?#,\\b.*,g;
    $re =~ s,\+,\\b[^/]+\\b,g;
    if($topic =~ m/^$re$/) {
      Log3 $shash, 5, "$hash->{NAME} $hash->{cid} => $topic:$val";
      addToWritebuffer($hash,
        pack("C",0x30).
        MQTT2_SERVER_calcRemainingLength(2+length($topic)+length($val)).
        pack("n", length($topic)).
        $topic.$val);
    }
  }
}

sub
MQTT2_SERVER_terminate($$)
{
  my ($hash,$msg) = @_;
  addToWritebuffer( $hash, $msg, sub{ CommandDelete(undef, $hash->{NAME}); });
}

sub
MQTT2_SERVER_Write($$$)
{
  my ($hash,$topic,$msg) = @_;
  my $retain;
  if($topic =~ m/^(.*):r$/) {
    $topic = $1;
    $retain = 1;
  }
  MQTT2_SERVER_doPublish($hash, $hash, $topic, $msg, $retain);
}

sub
MQTT2_SERVER_calcRemainingLength($)
{
  my ($l) = @_;
  my @r;
  while($l > 0) {
    my $eb = $l % 128;
    $l = int($l/128);
    $eb += 128 if($l);
    push(@r, $eb);
  }
  return pack("C*", @r);
}

sub
MQTT2_SERVER_getRemainingLength($)
{
  my ($hash) = @_;
  return (2,2) if(length($hash->{BUF}) < 2);

  my $ret = 0;
  my $mul = 1;
  for(my $off = 1; $off <= 4; $off++) {
    my $b = ord(substr($hash->{BUF},$off,1));
    $ret += ($b & 0x7f)*$mul;
    return ($ret, $off+1) if(($b & 0x80) == 0);
    $mul *= 128;
  }
  return -1;
}

sub
MQTT2_SERVER_getStr($$)
{
  my ($in, $off) = @_;
  my $l = unpack("n", substr($in, $off, 2));
  return (substr($in, $off+2, $l), $off+2+$l);
}

1;

=pod
=item helper
=item summary    Standalone MQTT message broker
=item summary_DE Standalone MQTT message broker
=begin html

<a name="MQTT2_SERVER"></a>
<h3>MQTT2_SERVER</h3>
<ul>
  MQTT2_SERVER is a builtin/cleanroom implementation of an MQTT server using no
  external libraries. It serves as an IODev to MQTT2_DEVICES, but may be used
  as a replacement for standalone servers like mosquitto (with less features
  and performance). It is intended to simplify connecting MQTT devices to FHEM.
  <br> <br>

  <a name="MQTT2_SERVERdefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; MQTT2_SERVER &lt;tcp-portnr&gt; [global|IP]</code>
    <br><br>
    Enable the server on port &lt;tcp-portnr&gt;. If global is specified,
    then requests from all interfaces (not only localhost / 127.0.0.1) are
    serviced. If IP is specified, then MQTT2_SERVER will only listen on this
    IP.<br>
    To enable listening on IPV6 see the comments <a href="#telnet">here</a>.
    <br>
    Notes:<br>
    <ul>
    <li>to set user/password use an allowed instance and its basicAuth
      feature (set/attr)</li>
    <li>retained messages are lost after a FHEM restart</li>
    <li>the retain flag is not propagated by publish</li>
    <li>only QOS 0 and 1 is implemented</li>
    </ul>
  </ul>
  <br>

  <a name="MQTT2_SERVERset"></a>
  <b>Set</b>
  <ul>
    <li>publish -r topic value<br>
      publish a message, -r denotes setting the retain flag.
      </li>
  </ul>
  <br>

  <a name="MQTT2_SERVERget"></a>
  <b>Get</b>
  <ul>N/A</ul><br>

  <a name="MQTT2_SERVERattr"></a>
  <b>Attributes</b>
  <ul>

    <li><a href="#disable">disable</a><br>
        <a href="#disabledForIntervals">disabledForIntervals</a><br>
      disable distribution of messages. The server itself will accept and store
      messages, but not forward them.
      </li><br>

    <a name="rawEvents"></a>
    <li>rawEvents &lt;topic-regexp&gt;<br>
      Send all messages as events attributed to this MQTT2_SERVER instance.
      Should only be used, if there is no MQTT2_DEVICE to process the topic.
      </li><br>

    <a name="keepaliveFactor"></a>
    <li>keepaliveFactor<br>
      the oasis spec requires a disconnect, if after 1.5 times the client
      supplied keepalive no data or PINGREQ is sent. With this attribute you
      can modify this factor, 0 disables the check. 
      Notes:
      <ul>
        <li>dont complain if you set this attribute to less or equal to 1.</li>
        <li>MQTT2_SERVER checks the keepalive only every 10 second.</li>
      </ul>
      </li>
    
    <a name="SSL"></a>
    <li>SSL<br>
      Enable SSL (i.e. TLS)
      </li><br>

    <a name="autocreate"></a>
    <li>autocreate<br>
      If set, MQTT2_DEVICES will be automatically created upon receiving an
      unknown message.
      </li><br>

  </ul>
</ul>
=end html

=cut
