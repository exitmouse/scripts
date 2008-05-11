#!/usr/athena/bin/perl

use strict;

use warnings;

open LIST, "actual";

open TEMPLATE, "wordpress-email";

my $template = do {local $/; <TEMPLATE>};

sub bits {
    # Given the argument of a locker, return users with rlidwka rights
    my $DIR = shift;
    open PERM, "fs la $DIR | ";
    my @list = (); #to be filled with users or moira lists
    while (my $line = <PERM>){
	if ($line =~ m{(\S+) \s rlidwka}x) {
	    my $temp = $1;
	    $temp =~ s/system://g;	    
	    push @list, $temp;
	}
    }
    return @list;
}

while (my $line = <LIST>) {
    print $line;
    if ($line =~ m{( (.*/ ([^/]+) ) /web_scripts/(\S+) )\s.*'([.0-9]+)'}x) {  
	my $PATH = $1;
	#print $PATH;
	my $DIR = $2;
	my $LOCKER = $3;
	my $URI = "$3.scripts.mit.edu/$4";
	my $VERSION = $5;
	next if $VERSION ne '2.0.2';
	my $lockeremail = $template;
	$lockeremail =~ s/<LOCKER>/$LOCKER/g;
	$lockeremail =~ s/<URI>/$URI/g;
	$lockeremail =~ s/<DIRECTORY>/$PATH/g;
	$lockeremail =~ s/<VERSION>/$VERSION/g;
	$lockeremail = "To: ".join(',',&bits($DIR))."\n\n".$lockeremail; 
	open OUTPUT, ">./email/$LOCKER";
	print OUTPUT $lockeremail; 
    }
}






