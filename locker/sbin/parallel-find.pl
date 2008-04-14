#!/usr/bin/perl

# Script to help generate find the .scripts-version files

use lib '/mit/scripts/sec-tools/perl';

open(FILE, "</mit/scripts/sec-tools/store/scriptslist");
my $dump = "/mit/scripts/sec-tools/store/versions";

(! -e $dump) || die "Output directory exists: $dump";
system("mkdir", $dump) && die;

use Proc::Queue size => 40, debug => 0, trace => 0;
use POSIX ":sys_wait_h"; # imports WNOHANG

# this loop creates new childs, but Proc::Queue makes it wait every
# time the limit (50) is reached until enough childs exit

# Note that we miss things where one volume is inside another if we
# use -xdev.  May miss libraries stuff.

sub find ($$) {
    my $user = shift;
    my $homedir = shift;

    open my $files, "find $homedir/web_scripts -xdev -name .scripts-version 2>/dev/null |";
    open my $out, ">$dump/$user";
    while (my $f = <$files>) {
        print $out $f;
    }
    return 0;
}

while (<FILE>) {
    my ($user, $homedir) = /^([^ ]*) (.*)$/;
    my $f=fork;
    if(defined ($f) and $f==0) {
        if ($homedir !~ m|^/afs/athena|) {
            print "ignoring non-athena-cell $user $homedir\n";
            exit(0);
        }
	print "$user\n";
        $ret = find($user, $homedir);
	sleep rand 1;
	exit($ret);
    }
    1 while waitpid(-1, WNOHANG)>0; # avoids memory leaks in Proc::Queue
}
