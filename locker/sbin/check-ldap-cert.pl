#!/usr/bin/perl

use strict;
use File::Basename;
use Date::Parse;
use Sys::Hostname;

my @servers = qw(localhost);

my $hostname = hostname();

my $now = time();

my $dir = dirname($0);

our $verbose = 0;
$verbose = 1 if ($ARGV[0] eq "-v");

use constant WARNING => 60*60*24*14; # Warn if a cert is expiring within 14 days

foreach my $server (@servers) {
  open(X509, "-|", "$dir/ssl-get-endtime", "$server:636") or die "Couldn't invoke ssl-get-endtime: $!";
  chomp(my $exp = <X509>);
  close(X509);
  $exp =~ s/^notAfter=// or warn "Cert appears broken: $server";

  my $time = str2time($exp);

  if ($verbose || ($time - $now) <= WARNING) {
    printf "$hostname: Certificate expiring in %.2f days: %s\n", (($time - $now) / (60.0*60*24)), $server;
  }
}
