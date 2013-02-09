#!/usr/bin/perl

# File:    $Id: show.cgi,v 1.22 2006/04/12 09:42:16 sauber Exp $
# Author:  (c) Soren Dossing, 2005
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license.php

use strict;
use RRDs;
use CGI qw/:standard/;

# Configuration
my $configfile = '/home/nagios/ng/etc/nagiosgraph.conf';

# Main program - change nothing below

my %Config;

# Read in configuration data
#
sub readconfig {
  die "config file not found" unless -r $configfile;

  # Read configuration data
  open FH, $configfile;
    while (<FH>) {
      s/\s*#.*//;    # Strip comments
      /^(\w+)\s*=\s*(.*?)\s*$/ and do {
        $Config{$1} = $2;
        debug(5, "CGI Config $1:$2");
      };
    }
  close FH;

  # Make sure log file can be written to
  unless ( -w $Config{logfile} ) {
    my $msg = "Log file $Config{logfile} not writable";
    print header(-type => "text/html", -expires => 0);
    print p($msg);
    debug (2, "CGI Config $msg");
    return undef;
  }

  # Make sure rrddir is readable
  unless ( -r $Config{rrddir} ) {
    my $msg = "rrd dir $Config{rrddir} not readable";
    print header(-type => "text/html", -expires => 0);
    print p($msg);
    debug (2, "CGI Config $msg");
    return undef;
  }

  return 1;
}

# Write debug information to log file
#
sub debug {
  my($l, $text) = @_;
  if ( $l <= $Config{debug} ) {
    $l = qw(none critical error warn info debug)[$l];
    $text =~ s/(\w+)/$1 $l:/;
    open LOG, ">>$Config{logfile}";
      print LOG scalar localtime;
      print LOG " $text\n";
    close LOG;
  }
}

# URL encode a string
#
sub urlencode {
  $_[0] =~ s/([\W])/"%" . uc(sprintf("%2.2x",ord($1)))/eg;
  return $_[0];
}

# Get list of matching rrd files
#
sub dbfilelist {
  my($host,$service) = @_;
  my $hs = urlencode "${host}_${service}";
  my @rrd;
  opendir DH, $Config{rrddir};
    @rrd = grep s/^${hs}_(.+)\.rrd$/$1/, readdir DH;
  closedir DH;
  return @rrd;
}

# Find graphs and values
#
sub graphinfo {
  my($host,$service,@db) = @_;
  my(@rrd,$ds,$f,$dsout,@values,$hs,%H,%R);

  $hs = urlencode "${host}_${service}";

  debug(5, 'CGI @db=' . join '&', @db);

  # Determine which files to read lines from
  if ( @db ) {
    my $n = 0;
    for my $d ( @db ) {
      my($db,@lines) = split ',', $d;
      $rrd[$n]{file} = $hs . urlencode("_$db") . '.rrd';
      for my $l ( @lines ) {
        my($line,$unit) = split '~', $l;
        if ( $unit ) {
          $rrd[$n]{line}{$line}{unit} = $unit if $unit;
        } else {
          $rrd[$n]{line}{$line} = 1;
        }
      }
      $n++;
    }
    debug(4, "CGI Specified $hs db files in $Config{rrddir}: "
           . join ', ', map { $_->{file} } @rrd);
  } else {
    @rrd = map {{ file=>$_ }}
           map { "${hs}_${_}.rrd" }
           dbfilelist($host,$service);
    debug(4, "CGI Listing $hs db files in $Config{rrddir}: "
           . join ', ', map { $_->{file} } @rrd);
  }

  for $f ( @rrd ) {
    unless ( $f->{line} ) {
      $ds = RRDs::info "$Config{rrddir}/$f->{file}";
      debug(2, "CGI RRDs::info ERR " . RRDs::error) if RRDs::error;
      map { $f->{line}{$_} = 1}
      grep {!$H{$_}++}
      map { /ds\[(.*)\]/; $1 }
      grep /ds\[(.*)\]/,
      keys %$ds;
    }
    debug(5, "CGI DS $f->{file} lines: "
           . join ', ', keys %{ $f->{line} } );
  }
  return \@rrd;
}

# Choose a color for service
#
sub hashcolor {
  my$c=$Config{colorscheme};
  map{
    $c=(51*$c+ord)%(216)
  } split//,"$_[0]x";
  my($i,$n,$m,@h);
  @h=(51*int$c/36,
      51*int$c/6%6,
      51*($c%6));
#debug(2, "hashcolor $_[0], $c, $h[0]");
  for$i(0..2){
	$m=$i if$h[$i]<$h[$m];
	$n=$i if$h[$i]>$h[$n]
  }
  $h[$m]=102 if$h[$m]>102;
  $h[$n]=153 if$h[$n]<153;
#debug(2, "hashcolor $_[0]\t$c\t$h[0]\t$h[1]\t$h[2]");
  #$c=sprintf"%06X",$h[2]+$h[1]*256+$h[0]*16**4;
  $n = $h[2]+$h[1]*256+$h[0]*16**4;
  $c=sprintf"%06X",$n;
#debug(2, "hashcolor $_[0]\t$n\t$c");
  return $c;
}

# Generate all the parameters for rrd to produce a graph
#
sub rrdline {
  my($host,$service,$geom,$rrdopts,$G,$time) = @_;
  my($g,$f,$v,$c,@ds);

  @ds = ('-', '-a', 'PNG', '--start', "-$time");
  # Identify where to pull data from and what to call it
  for $g ( @$G ) {
    $f = $g->{file};
    debug(5, "CGI file=$f");
    for $v ( sort keys %{ $g->{line} } ) {
      $c = hashcolor($v);
      debug(5, "CGI file=$f line=$v color=$c");
      my $sv = "$v";
      push @ds , "DEF:$sv=$Config{rrddir}/$f:$v:AVERAGE"
               , "LINE2:${sv}#$c:$sv"
               , "GPRINT:$sv:MAX:Max\\: %6.2lf%s"
               , "GPRINT:$sv:AVERAGE:Avg\\: %6.2lf%s"
               , "GPRINT:$sv:MIN:Min\\: %6.2lf%s"
               , "GPRINT:$sv:LAST:Cur\\: %6.2lf%s\\n";
    }
  }

  # Dimensions of graph if geom is specified
  if ( $geom ) {
    my($w,$h) = split 'x', $geom;
    push @ds, '-w', $w, '-h', $h;
  }
  # Additional parameters to rrd graph, if specified
  if ( $rrdopts ) {
    push @ds, split /\s+/, $rrdopts;
  }
  return @ds;
}

# Write a pretty page with various graphs
#
sub page {
  my($h,$s,$d,$o,@db) = @_;

  # Reencode rrdopts
  $o = urlencode $o;

  # Detect available db files
  @db = dbfilelist($h,$s) unless @db;
  debug(5, "CGI dbfilelist @db");

  # Define graph sizes
  #   Daily   =  33h =   118800s
  #   Weekly  =   9d =   777600s
  #   Monthly =   5w =  3024000s
  #   Yearly  = 400d = 34560000s
  my @T=(['dai',118800], ['week',777600], ['month',3024000], ['year',34560000]);
  print h1("Nagiosgraph");
  print p("Performance data for ".strong("Host: ").tt($h).' &#183; '.strong("Service: ").tt($s));
  for my $l ( @T ) {
    my($p,$t) = ($l->[0],$l->[1]);
    print h2(ucfirst $p . "ly");
    if ( @db ) {
      for my $g ( @db ) {
        my $arg = join '&', "host=$h", "service=$s", "db=$g", "graph=$t",
                            "geom=$d", "rrdopts=$o";
        my @gl = split ',', $g;
        my $ds = shift @gl;
        print div({-class => "graphs"}, img( {-src => "?$arg", -alt => "Graph"} ) );
        print div({-class => "graph_description"}, cite(strong($ds).br().small(join(", ", @gl))));
      }
    } else {
      my $arg = join '&', "host=$h", "service=$s", "graph=$t",
                          "geom=$d", "rrdopts=$o";
      print div({-class => "graphs"}, img( {-src => "?$arg", -alt => "Graph"} ) );
    }
  }
}

exit unless readconfig();

# Expect host, service and db input
my $host = param('host') if param('host');
my $service = param('service') if param('service');
my @db = param('db') if param('db');
my $graph = param('graph') if param('graph');
my $geom = param('geom') if param('geom');
my $rrdopts = param('rrdopts') if param('rrdopts');

# Draw a graph or a page
if ( $graph ) {
  $| = 1; # Make sure headers arrive before image data
  print header(-type => "image/png");
  # Figure out db files and line labels
  my $G = graphinfo($host,$service,@db);
  my @ds = rrdline($host,$service,$geom,$rrdopts,$G,$graph);
  debug(4, "CGI RRDs::graph ". join ' ', @ds);
  RRDs::graph(@ds);
  debug(2, "CGI RRDs::graph ERR " . RRDs::error) if RRDs::error;
  exit;
} else {
  my @style;
  if ($Config{stylesheet}) {
    @style = ( -style => {-src => "$Config{stylesheet}"} );
  }
  print header, start_html(-id=>"nagiosgraph", -title => "nagiosgraph: $host-$service",
    -meta => { -http_equiv => "Refresh", -content => "300" },
    @style
    );
  page($host,$service,$geom,$rrdopts,@db);
  print div({-id => "footer"}, hr(), small( "Created by ". a( {-href=>"http://nagiosgraph.sf.net/"}, "nagiosgraph"). "." ));
  print end_html();
}