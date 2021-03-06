
package main;

use strict;
use warnings;
use POSIX;

sub holiday_refresh($$);

#####################################
sub
holiday_Initialize($)
{
  my ($hash) = @_;

  $hash->{DefFn}    = "holiday_Define";
  $hash->{GetFn}    = "holiday_Get";
  $hash->{UndefFn}  = "holiday_Undef";
}


#####################################
sub
holiday_Define($$)
{
  my ($hash, $def) = @_;

  return holiday_refresh($hash->{NAME}, undef) if($init_done);
  InternalTimer(gettimeofday()+1, "holiday_refresh", $hash->{NAME}, 0);
  return undef;
}

sub
holiday_Undef($$)
{
  my ($hash, $name) = @_;
  RemoveInternalTimer($name);
  return undef;
}

sub
holiday_refresh($$)
{
  my ($name, $fordate) = (@_);
  my $hash = $defs{$name};
  my $internal;

  return if(!$hash);           # Just deleted

  my $nt = gettimeofday();
  my @lt = localtime($nt);
  my @fd;
  if(!$fordate) {
    $internal = 1;
    $fordate = sprintf("%02d-%02d", $lt[4]+1, $lt[3]);
    @fd = @lt;
  } else {
    my ($m,$d) = split("-", $fordate);
    @fd = localtime(mktime(1,1,1,$d,$m-1,$lt[5],0,0,-1));
  }

  my $fname = $attr{global}{modpath} . "/FHEM/" . $hash->{NAME} . ".holiday";
  return "Can't open $fname: $!" if(!open(FH, $fname));
  my $found = "none";
  while(my $l = <FH>) {
    next if($l =~ m/^\s*#/);
    next if($l =~ m/^\s*$/);
    chomp($l);

    if($l =~ m/^1/) {               # Exact date: 1 MM-DD Holiday
      my @args = split(" +", $l, 3);
      if($args[1] eq $fordate) {
        $found = $args[2];
        last;
      }

    } elsif($l =~ m/^2/) {          # Easter date: 2 +1 Ostermontag

      eval { require DateTime::Event::Easter } ;
      if( $@) {
        Log 1, "$@";

      } else {
        my @a = split(" +", $l, 3);
        my $dt = DateTime::Event::Easter->new(day=>$a[1])
                          ->following(DateTime->new(year=>(1900+$lt[5])));
        next if($dt->day != $fd[3] || $dt->month != $fd[4]+1);
        $found = $a[2];
        last;
      }

    } elsif($l =~ m/^3/) {          # Relative date: 3 -1 Mon 03 Holiday
      my @a = split(" +", $l, 5);
      my %wd = ("Sun"=>0, "Mon"=>1, "Tue"=>2, "Wed"=>3,
                "Thu"=>4, "Fri"=>5, "Sat"=>6);
      my @md = (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
      $md[1]=29 if(schaltjahr($fd[5]+1900) && $fd[4] == 1);
      my $wd = $wd{$a[2]};
      if(!defined($wd)) {
        Log 1, "Wrong timespec: $l";
        next;
      }
      next if($wd != $fd[6]);       # Weekday
      next if($a[3] != ($fd[4]+1)); # Month
      if($a[1] > 0) {               # N'th day from the start
        my $d = $fd[3] - ($a[1]-1)*7;
        next if($d < 1 || $d > 7);
      } elsif($a[1] < 0) {          # N'th day from the end
        my $d = $fd[3] - ($a[1]+1)*7;
        my $md = $md[$fd[4]];
        next if($d > $md || $d < $md-6);
      }

      $found = $a[4];
      last;

    } elsif($l =~ m/^4/) {          # Interval: 4 MM-DD MM-DD Holiday
      my @args = split(" +", $l, 4);
      if($args[1] le $fordate && $args[2] ge $fordate) {
        $found = $args[3];
        last;
      }

    } elsif($l =~ m/^5/) { # nth weekday since MM-DD / before MM-DD
      my @a = split(" +", $l, 6);
      # arguments: 5 <distance> <weekday> <day> <month> <name>
      my %wd = ("Sun"=>0, "Mon"=>1, "Tue"=>2, "Wed"=>3,
                "Thu"=>4, "Fri"=>5, "Sat"=>6);
      my $wd = $wd{$a[2]};
      if(!defined($wd)) {
        Log 1, "Wrong weekday spec: $l";
        next;
      }
      next if $wd != $fd[6]; # check wether weekday matches today
      my $yday=$fd[7];
      # create time object of target date - mktime counts months and their
      # days from 0 instead of 1, so subtract 1 from each
      my $tgt=mktime(0,0,1,$a[3]-1,$a[4]-1,$fd[5],0,0,-1);
      my $tgtmin=$tgt;
      my $tgtmax=$tgt;
      my $weeksecs=7*24*60*60; # 7 days, 24 hours, 60 minutes, 60seconds each
      my $cd=mktime(0,0,1,$fd[3],$fd[4],$fd[5],0,0,-1);
      if ( $a[1] =~ /^-([0-9])*$/ ) {
        $tgtmin -= $1*$weeksecs; # Minimum: target date minus $1 weeks
        $tgtmax = $tgtmin+$weeksecs; # Maximum: one week after minimum
	# needs to be lower than max and greater than or equal to min
        if ( ($cd ge $tgtmin) && ( $cd lt $tgtmax) ) {
		$found=$a[5];
		last;
	}
      } elsif ( $a[1] =~ /^\+?([0-9])*$/ ) {
        $tgtmin += ($1-1)*$weeksecs; # Minimum: target date plus $1-1 weeks
        $tgtmax = $tgtmin+$weeksecs; # Maximum: one week after minimum
	# needs to be lower than or equal to max and greater min
        if ( ($cd gt $tgtmin) && ( $cd le $tgtmax) ) {
		$found=$a[5];
		last;
	}
      } else {
        Log 1, "Wrong distance spec: $l";
        next;
      }
    }

  }
  close(FH);

  RemoveInternalTimer($name);
  $nt -= ($lt[2]*3600+$lt[1]*60+$lt[0]);         # Midnight
  $nt += 86400 + 2;                              # Tomorrow
  $hash->{TRIGGERTIME} = $nt;
  InternalTimer($nt, "holiday_refresh", $name, 0);

  if($internal) {
    $hash->{STATE} = $found;
    return undef;
  } else {
    return $found;
  }

}

sub
holiday_Get($@)
{
  my ($hash, @a) = @_;

  return "argument is missing" if(int(@a) != 2);
  return "wrong argument: need MM-DD" if($a[1] !~ m/^[01]\d-[0-3]\d$/);
  return holiday_refresh($hash->{NAME}, $a[1]);
}

sub
schaltjahr($)
{
  my($jahr) = @_;
  return 0 if $jahr % 4;       # 2009
  return 1 unless $jahr % 400; # 2000
  return 0 unless $jahr % 100; # 2100
  return 1;                    # 2012
}

1;
