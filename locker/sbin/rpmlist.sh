#!/bin/sh

copyTo='/mit/scripts/cron_scripts/rpm-sync/'
packages=`mktemp --tmpdir rpmlist.XXXXXX`
rpm -qa --queryformat '%{NAME}.%{ARCH}\n' | sort | uniq > $packages

host=`hostname`
extension='.rpmlist'
file="$copyTo/$host$extension"
mv $packages $file
