#!/usr/bin/perl

# Simple script taking a passwd file and storing the things with
# sufficiently high UID in the right place

use strict;
my $file = $ARGV[0];
my $file2 = $ARGV[1];
open(FIN, "<$file");
open(FOUT, ">$file2");

while(<FIN>)
{
    my @passwd_line = split(':', $_);
    if ($passwd_line[2] > 500000000) {
	# Then it's a volume ID, thus a real user
	print FOUT "$passwd_line[0]\n";
    }
}

close(FIN);
close(FOUT);
