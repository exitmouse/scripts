#!/usr/bin/perl

system("/mit/scripts/sec-tools/get-passwd.sh");
system("/mit/scripts/sec-tools/parallel-find.pl");
sleep 5;

while(1) {
    my $count = `ps -ef | grep find | grep $ENV{USER} | grep -v ps | grep -v grep | wc -l | tr -d '\n'`;
    if ($count eq '0') {
	last;
    }
    else {
	print "Current have $count find processes running.  Please wait.\n";
	sleep 1;
    }
}

print "Done finding files\n";
system("cat /mit/scripts/sec-tools/store/versions/* >| /mit/scripts/sec-tools/store/scripts-versions");
print "Done\n";
#print `cat /mit/scripts/sec-tools/store/versions/`;
