##############################################
# $Id$
package main;

use strict;
use warnings;

#####################################
sub
CUL_RFR_Initialize($)
{
  my ($hash) = @_;

  # Message is like
  # K41350270

  $hash->{Match}     = "^[0-9A-F]{4}U.";
  $hash->{DefFn}     = "CUL_RFR_Define";
  $hash->{UndefFn}   = "CUL_RFR_Undef";
  $hash->{ParseFn}   = "CUL_RFR_Parse";
  $hash->{AttrList}  = "IODev do_not_notify:0,1 model:CUL,CUN,CUR " .
                       "loglevel:0,1,2,3,4,5,6 ignore:0,1 addvaltrigger";

  $hash->{WriteFn}   = "CUL_RFR_Write";
  $hash->{GetFn}     = "CUL_Get";
  $hash->{SetFn}     = "CUL_Set";
  $hash->{noRawInform} = 1;     # Our message was already sent as raw.
}


#####################################
sub
CUL_RFR_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);

  return "wrong syntax: define <name> CUL_RFR <id> <routerid>"
            if(int(@a) != 4 ||
               $a[2] !~ m/[0-9A-F]{2}/i ||
               $a[3] !~ m/[0-9A-F]{2}/i);
  $hash->{ID} = $a[2];
  $hash->{ROUTERID} = $a[3];
  $modules{CUL_RFR}{defptr}{"$a[2]$a[3]"} = $hash;
  AssignIoPort($hash);
  return undef;
}

#####################################
sub
CUL_RFR_Write($$)
{
  my ($hash,$fn,$msg) = @_;

  ($fn, $msg) = CUL_WriteTranslate($hash, $fn, $msg);
  return if(!defined($fn));
  $msg = $hash->{ID} . $hash->{ROUTERID} . $fn . $msg;
  IOWrite($hash, "u", $msg);
}

#####################################
sub
CUL_RFR_Undef($$)
{
  my ($hash, $name) = @_;
  delete($modules{CUL_RFR}{defptr}{$hash->{ID} . $hash->{ROUTERID}});
  return undef;
}

#####################################
sub
CUL_RFR_Parse($$)
{
  my ($iohash,$msg) = @_;

  # 0123456789012345678
  # E01012471B80100B80B -> Type 01, Code 01, Cnt 10
  $msg =~ m/^([0-9AF]{2})([0-9AF]{2})U(.*)/;
  my ($rid, $id, $smsg) = ($1,$2,$3);
  my $cde = "${id}${rid}";

  if(!$modules{CUL_RFR}{defptr}{$cde}) {
    Log 1, "CUL_RFR detected, Id $id, Router $rid, MSG $smsg";
    return "UNDEFINED CUL_RFR_$id CUL_RFR $id $rid";
  }
  my $hash = $modules{CUL_RFR}{defptr}{$cde};
  my $name = $hash->{NAME};
  return "" if(IsIgnored($name));

  $hash->{Clients}   = $iohash->{Clients};
  $hash->{MatchList} = $iohash->{MatchList};

  my @m = split(";", $smsg, -1);  # process only messages terminated with ;
  for(my $i = 0; $i < $#m; $i++) {
    my $m = $m[$i];

    # Compressed FHT messages
    while($m =~ m/^T(....)(..)(..)(..)(..)(..)(.*)(..)$/) {
      my ($fhtid, $cmd, $source, $val, $cmd2, $val2, $rest, $rssi) =
         ($1, $2, $3, $4, $5, $6, $7, $8);
      my $firstmsg = "T$fhtid$cmd$source$val$rssi";
      $m = "T$fhtid$cmd2$source$val2$rest$rssi";
      CUL_Parse($hash, $iohash, $hash->{NAME}, $firstmsg, "X21");
    }

    CUL_Parse($hash, $iohash, $hash->{NAME}, $m, "X21");
       if($m =~ m/^T/) { $hash->{NR_TMSG}++ }
    elsif($m =~ m/^F/) { $hash->{NR_FMSG}++ }
    elsif($m =~ m/^E/) { $hash->{NR_EMSG}++ }
    elsif($m =~ m/^K/) { $hash->{NR_KMSG}++ }
    else               { $hash->{NR_RMSG}++ }
  }
  return "";
}

sub
CUL_RFR_DelPrefix($)
{
  my ($msg) = @_;
  while($msg =~ m/^\d{4}U/) {
    (undef, $msg) = split("U", $msg, 2);
  }
  $msg =~ s/;([\r\n]*)$/$1/;
  return $msg;
}

sub
CUL_RFR_AddPrefix($$)
{
  my ($hash, $msg) = @_;
  while($hash->{TYPE} eq "CUL_RFR") {
    # Prefix $msg with RRBBU and return the corresponding CUL hash
    $msg = "u" . $hash->{ID} . $hash->{ROUTERID} . $msg;
    $hash = $hash->{IODev};
  }
  return ($hash, $msg);
}

1;

