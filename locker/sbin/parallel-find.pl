#!/usr/bin/perl

# Script to help generate find the .scripts-version files

use lib '/mit/scripts/sec-tools/perl';

open(FILE, "</mit/scripts/sec-tools/store/scriptslist");
my $dump = "/mit/scripts/sec-tools/store/versions";

(! -e $dump) || die "Output directory exists: $dump";
system("mkdir", $dump) && die;

use Proc::Queue size => 40, debug => 0;
use POSIX ":sys_wait_h"; # imports WNOHANG

# this loop creates new childs, but Proc::Queue makes it wait every
# time the limit (50) is reached until enough childs exit

# Note that we miss things where one volume is inside another if we
# use -xdev.  May miss libraries stuff.

while (<FILE>) {
    my ($user, $homedir) = /^([^ ]*) (.*)$/;
    my $f=fork;
    if(defined ($f) and $f==0) {
	print "$user\n";
	my $ret = system("find $homedir/web_scripts -xdev -name .scripts-version -print > $dump/$user 2> /dev/null");
	sleep rand 1;
	exit($ret);
    }
    while (waitpid(-1, WNOHANG)>0) {
        $? && die "child exited with error: $?";
    }; # reaps childs
}
