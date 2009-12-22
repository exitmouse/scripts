#!/usr/bin/perl

# Script to help generate find the .scripts-version files

use LockFile::Simple qw(trylock unlock);
use File::stat;

use lib '/mit/scripts/sec-tools/perl';

open(FILE, "</mit/scripts/sec-tools/store/scriptslist");
my $dump = "/mit/scripts/sec-tools/store/versions";
my $dumpbackup = "/mit/scripts/sec-tools/store/versions-backup";

# try to grab a lock on the version directory
trylock($dump) || die "Can't acquire lock; lockfile already exists at <$dump.lock>.  Another parallel-find may be running.  If you are SURE there is not, remove the lock file and retry.";

sub unlock_and_die ($) {
    my $msg = shift;
    unlock($dump);
    die $msg;
}

# if the versions directory exists, move it to versions-backup
# (removing the backup directory if necessary).  Then make a new copy.
if (-e $dump){
    if (-e $dumpbackup){
        system("rm -rf $dumpbackup") && unlock_and_die "Can't remove old backup directory $dumpbackup";
    }
    system("mv", $dump, $dumpbackup) && unlock_and_die "Unable to back up current directory $dump";
}
system("mkdir", $dump) && unlock_and_die "mkdir failed to create $dump";

use Proc::Queue size => 40, debug => 0, trace => 0;
use POSIX ":sys_wait_h"; # imports WNOHANG

# this loop creates new childs, but Proc::Queue makes it wait every
# time the limit (50) is reached until enough childs exit

# Note that we miss things where one volume is inside another if we
# use -xdev.  May miss libraries stuff.

sub updatable ($) {
    my $filename = shift;
    for my $l (`fs la "$filename"`) {
        return 1 if ($l =~ /^  system:scripts-security-upd rlidwk/);
    }
    return 0;
}

sub old_version ($) {
    my $dirname = shift;
    open my $h, "$dirname/.scripts-version";
    return (<$h>)[-1];
}

sub version ($) {
    my $dirname = shift;
    $uid = stat($dirname)->uid;
    open my $h, "sudo -u#$uid git describe --tags 2>/dev/null |";
    chomp($val = <$h>);
    return $val;
}

sub find ($$) {
    my $user = shift;
    my $homedir = shift;

    open my $files, "find $homedir/web_scripts -xdev -name .scripts-version -o -name .scripts 2>/dev/null |";
    open my $out, ">$dump/$user";
    while (my $f = <$files>) {
        chomp $f;
        my $new_style;
        $new_style = ($f =~ s!/\.scripts$!!);
        if (! $new_style) {
            $f =~ s!/\.scripts-version$!!;
        }
        if (! updatable($f)) {
            print STDERR "not updatable: $f";
            next;
        }
        $v = $new_style ? version($f) : old_version($f);
        print $out "$f:$v";
    }
    return 0;
}

while (<FILE>) {
    my ($user, $homedir) = /^([^ ]*) (.*)$/;
    my $f=fork;
    if(defined ($f) and $f==0) {
        if ($homedir !~ m|^/afs/athena| && $homedir !~ m|^/afs/sipb| && $homedir !~ m|^/afs/zone|) {
            print "ignoring foreign-cell $user $homedir\n";
            exit(0);
        }
        print "$user\n";
        $ret = find($user, $homedir);
        sleep rand 1;
        exit($ret);
    }
    1 while waitpid(-1, WNOHANG)>0; # avoids memory leaks in Proc::Queue
}

unlock($dump);
1;
