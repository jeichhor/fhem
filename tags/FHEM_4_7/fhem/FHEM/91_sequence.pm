##############################################
package main;

use strict;
use warnings;
use Time::HiRes qw(gettimeofday);

#####################################
sub
sequence_Initialize($)
{
  my ($hash) = @_;

  $hash->{DefFn} = "sequence_Define";
  $hash->{UndefFn} = "sequence_Undef";
  $hash->{NotifyFn} = "sequence_Notify";
  $hash->{AttrList} = "disable:0,1 loglevel:0,1,2,3,4,5,6";
}


#####################################
# define sq1 sequence reg1 [timeout reg2]
sub
sequence_Define($$)
{
  my ($hash, $def) = @_;
  my @def = split("[ \t]+", $def);

  my $name = shift(@def);
  my $type = shift(@def);
  
  return "Usage: define <name> sequence <re1> <timeout1> <re2> ".
                                            "[<timeout2> <re3> ...]"
    if(int(@def) % 2 == 0 || int(@def) < 3);

  # "Syntax" checking
  for(my $i = 0; $i < int(@def); $i += 2) {
    my $re = $def[$i];
    my $to = $def[$i+1];
    eval { "Hallo" =~ m/^$re$/ };
    return "Bad regexp 1: $@" if($@);
    return "Bad timeout spec $to"
        if(defined($to) && $to !~ m/^\d*.?\d$/);
  }

  $hash->{RE} = $def[0];
  $hash->{IDX} = 0;
  $hash->{MAX} = int(@def);
  $hash->{STATE} = "initialized";
  return undef;
}

#####################################
sub
sequence_Notify($$)
{
  my ($hash, $dev) = @_;

  my $ln = $hash->{NAME};
  return "" if($attr{$ln} && $attr{$ln}{disable});

  my $n = $dev->{NAME};
  my $re = $hash->{RE};
  my $max = int(@{$dev->{CHANGED}});

  for (my $i = 0; $i < $max; $i++) {
    my $s = $dev->{CHANGED}[$i];
    $s = "" if(!defined($s));
    next if($n !~ m/^$re$/ && "$n:$s" !~ m/^$re$/);

    RemoveInternalTimer($ln);
    my $idx = $hash->{IDX} + 2;
    Log GetLogLevel($ln,5), "sequence $ln matched $idx";
    my @d = split("[ \t]+", $hash->{DEF});


    if($idx > $hash->{MAX}) {   # Last element reached

      Log GetLogLevel($ln,5), "sequence $ln triggered";
      DoTrigger($ln, "trigger");
      $idx  = 0;

    } else {

      $hash->{RE} = $d[$idx];
      my $nt = gettimeofday() + $d[$idx-1];
      InternalTimer($nt, "sequence_Trigger", $ln, 0);

    }

    $hash->{IDX} = $idx;
    $hash->{RE} = $d[$idx];
    last;
  }
  return "";
}

sub
sequence_Trigger($)
{
  my ($ln) = @_;
  my $hash = $defs{$ln};
  my @d = split("[ \t]+", $hash->{DEF});
  $hash->{RE} = $d[0];
  $hash->{IDX} = 0;
  Log GetLogLevel($ln,5), "sequence $ln timeout";
}

sub
sequence_Undef($$)
{
  my ($hash, $name) = @_;
  RemoveInternalTimer($name);
  return undef;
}

1;
