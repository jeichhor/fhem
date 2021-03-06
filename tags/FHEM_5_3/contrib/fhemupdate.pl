#!/usr/bin/perl

use IO::File;

# Server-Side script to check out the fhem SVN repository, and upload the
# changed files to the server

$ENV{CVS_RSH}="/usr/bin/ssh";

print "\n\n";
print localtime() . "\n";

#my $homedir="/Users/rudi/Projects/fhem/fhemupdate";
my $homedir="/home/rudi/fhemupdate";
#goto NEWSTYLE;

chdir("$homedir/culfw");
system("svn update .");
chdir("$homedir/fhem");
system("mkdir -p UPLOAD");
system("svn update .");
die "SVN failed, exiting\n" if($?);

my $ndiff = `diff fhem.pl fhem.pl.txt | wc -l`;
if($ndiff != 4) {       # more than the standard stuff is different
  print "Modifying fhem.pl: >$ndiff<\n";
  system('perl -p -e "s/=DATE=/"`date +"%Y-%m-%d"`"/;'.
                     's/=VERS=/"`grep ^VERS= Makefile | '.
         'sed -e s/VERS=//`"+SVN/" fhem.pl > fhem.pl.txt');
}


#################################
# Old style
my @filelist = (
 "./fhem.pl.txt",
 "FHEM/.*.pm",
 "FHEM/FhemUtils/.*.pm",
 "webfrontend/pgm2/.*",
 "docs/commandref.html",
 "docs/faq.html",
 "docs/HOWTO.html",
 "docs/fhem.*.png",
 "docs/.*.jpg",
 "../culfw/Devices/CUL/.*.hex",
 "./CHANGED",
);

# Read in the file timestamps
my %filetime;
my %filesize;
my %filedir;
foreach my $fspec (@filelist) {
  $fspec =~ m,^(.+)/([^/]+)$,;
  my ($dir,$pattern) = ($1, $2);

  opendir DH, $dir || die("Can't open $dir: $!\n");
  foreach my $file (grep { /$pattern/ && -f "$dir/$_" } readdir(DH)) {
    my @st = stat("$dir/$file");
    my @mt = localtime($st[9]);
    $filetime{$file} = sprintf "%04d-%02d-%02d_%02d:%02d:%02d",
                $mt[5]+1900, $mt[4]+1, $mt[3], $mt[2], $mt[1], $mt[0];
    $filesize{$file} = $st[7];
    $filedir{$file} = $dir;
  }
  closedir(DH);
}

my %oldtime;
if(open FH, "UPLOAD/filetimes.txt") {
  while(my $l = <FH>) {
    chomp($l);
    my ($ts, $fs, $file) = split(" ", $l, 3);
    $oldtime{"$file.txt"} = $ts if($file eq "fhem.pl");
    $oldtime{$file} = $ts;
  }
  close(FH);
}

chdir("$homedir/fhem/UPLOAD");
open FH, ">filetimes.txt" || die "Can't open filetimes.txt: $!\n";
open FTP, ">script.txt" || die "Can't open script.txt: $!\n";
print FTP "cd fhem/fhemupdate\n";
print FTP "put filetimes.txt\n";
print FTP "pas\n";      # Without passive only 28 files can be transferred
my $cnt;
foreach my $f (sort keys %filetime) {
  my $fn = $f;
  $fn =~ s/.txt$// if($fn =~ m/.pl.txt$/);
  print FH "$filetime{$f} $filesize{$f} $fn\n";

  my $newfname = $f;
  if(!$oldtime{$f} || $oldtime{$f} ne $filetime{$f}) {
    print FTP "put $f\n";
    system("cp ../$filedir{$f}/$f $f");
    $cnt++;
  }
}
close FH;
close FTP;

if($cnt) {
  print "FTP Upload needed for $cnt files\n";
  system("ftp -e fhem.de < script.txt");
}


NEWSTYLE:

#################################
# new Style
chdir("$homedir/fhem");
my $uploaddir2="UPLOAD2";
system("mkdir -p $uploaddir2");

my %filelist2 = (
 "./fhem.pl.txt"               => { type=>",fhem,pgm2,", dir=>"." },
 "./CHANGED"                   => { type=>",fhem,pgm2,", dir=>"." },
 "FHEM/.*.pm"                  => { type=>",fhem,pgm2,", dir=>"FHEM" },
 "FHEM/FhemUtils/.*.pm"        => { type=>",fhem,pgm2,", dir=>"FHEM/FhemUtils"},
 "../culfw/Devices/CUL/.*.hex" => { type=>",fhem,pgm2,", dir=>"FHEM"},
 "webfrontend/pgm2/.*.pm\$"    => { type=>",pgm2,",      dir=>"FHEM"},
 "webfrontend/pgm2/.*"         => { type=>",pgm2,",      dir=>"www/pgm2"},
 "docs/commandref.html"        => { type=>",pgm2,",      dir=>"www/pgm2"},
 "docs/faq.html"               => { type=>",pgm2,",      dir=>"www/pgm2"},
 "docs/HOWTO.html"             => { type=>",pgm2,",      dir=>"www/pgm2"},
 "docs/fhem.*.png"             => { type=>",pgm2,",      dir=>"www/pgm2"},
 "docs/.*.jpg"                 => { type=>",pgm2,",      dir=>"www/pgm2"},
);


# Can't make negative regexp to work, so do it with extra logic
my %skiplist2 = (
 "www/pgm2"  => ".pm\$",
);

# Read in the file timestamps
my %filetime2;
my %filesize2;
my %filedir2;
my %filetype2;
chdir("$homedir/fhem");
foreach my $fspec (keys %filelist2) {
  $fspec =~ m,^(.+)/([^/]+)$,;
  my ($dir,$pattern) = ($1, $2);
  my $tdir = $filelist2{$fspec}{dir};
  opendir DH, $dir || die("Can't open $dir: $!\n");
  foreach my $file (grep { /$pattern/ && -f "$dir/$_" } readdir(DH)) {
    next if($skiplist2{$tdir} && $file =~ m/$skiplist2{$tdir}/);
    my @st = stat("$dir/$file");
    my @mt = localtime($st[9]);
    $filetime2{"$tdir/$file"} = sprintf "%04d-%02d-%02d_%02d:%02d:%02d",
                $mt[5]+1900, $mt[4]+1, $mt[3], $mt[2], $mt[1], $mt[0];
    $filesize2{"$tdir/$file"} = $st[7];
    $filedir2{"$tdir/$file"} = $dir;
    $filetype2{"$tdir/$file"} = $filelist2{$fspec}{type};
  }
  closedir(DH);
}

chdir("$homedir/fhem/$uploaddir2");
my %oldtime;
if(open FH, "filetimes.txt") {
  while(my $l = <FH>) {
    chomp($l);
    my ($ts, $fs, $file) = split(" ", $l, 3);
    $oldtime{"$file.txt"} = $ts if($file =~ m/fhem.pl/);
    $oldtime{$file} = $ts;
  }
  close(FH);
}

open FTP, ">script.txt"   || die "Can't open script.txt: $!\n";
print FTP "cd fhem/fhemupdate2\n";
print FTP "pas\n";      # Without passive only 28 files can be transferred

open FH, ">filetimes.txt" || die "Can't open filetimes.txt: $!\n";
print FTP "put filetimes.txt\n";

my %controls = (fhem=>0, pgm2=>0);
foreach my $k (keys %controls) {
  my $fname = "controls_$k.txt";
  $controls{$k} = new IO::File ">$fname" || die "Can't open $fname: $!\n";
  print FTP "put $fname\n";
}

my $cnt;
foreach my $f (sort keys %filetime2) {
  my $fn = $f;
  $fn =~ s/.txt$// if($fn =~ m/.pl.txt$/);
  print FH "$filetime2{$f} $filesize2{$f} $fn\n";
  foreach my $k (keys %controls) {
    my $fh = $controls{$k};
    print $fh "UPD $filetime2{$f} $filesize2{$f} $fn\n"
        if(",$filetype2{$f}," =~ m/,$k,/);
  }
  my $newfname = $f;
  if(!$oldtime{$f} || $oldtime{$f} ne $filetime2{$f}) {
    $f =~ m,^(.*)/([^/]*)$,;
    my ($tdir, $file) = ($1, $2);
    system("mkdir -p $tdir") unless(-d $tdir);
    print FTP "put $tdir/$file $tdir/$file\n";
    system("cp ../$filedir2{$f}/$file $tdir/$file");
    $cnt++;
  }
}
close FH;
close FTP;

foreach my $k (keys %controls) {
  if(open(ADD, "../contrib/fhemupdate.control.$k")) {
    while(my $l = <ADD>) {
      my $fh = $controls{$k};
      print $fh $l;
    }
    close ADD;
  }
  close $controls{$k};
}

if($cnt) {
  print "FTP Upload needed for $cnt files\n";
  system("ftp -e fhem.de < script.txt");
}
