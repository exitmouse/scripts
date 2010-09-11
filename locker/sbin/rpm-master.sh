#!/bin/sh

echo "Entering correct directory..."
mkdir -p /mit/scripts/cron_scripts/rpm-sync/
cd /mit/scripts/cron_scripts/rpm-sync/

echo "Cleaning up environment..."
rm -rf *.rpmlist *.diff rpmlist.master missing.rpms

servers=`finger @scripts-director.mit.edu | grep "\->" | grep EDU | awk '{print $2}' | cut -d: -f1 | sort | uniq`

for server in $servers; do
    echo "Connecting to $server..."
    ssh $server /mit/scripts/locker/sbin/rpmlist.sh > /dev/null
done

echo "Creating master package list..."
cat *.rpmlist | sort | uniq > rpmlist.master

echo "Comparing scripts servers to overall rpm list..."
touch missing.rpms
for server in *.rpmlist; do
    diff -U3 $server rpmlist.master > $server.diff
    serverPretty=`basename $server .rpmlist`
    echo "Server $serverPretty is missing:" >> missing.rpms
    grep "^+[^+]" $server.diff | cut -b 1 --complement >> missing.rpms
    echo >> missing.rpms
done

if [ `grep -c -v "missing" missing.rpms` -gt 0 ]; then
    echo "Sending email..."
    cat missing.rpms | mail -s "scripts.mit.edu servers are out of sync" root@scripts.mit.edu
else
    echo "No email needs to be sent! scripts.mit.edu is up to date."
fi
