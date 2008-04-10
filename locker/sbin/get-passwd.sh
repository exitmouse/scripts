#!/bin/bash

rm -f /mit/scripts/sec-tools/store/passwd
scp -S /mit/scripts/bin/sshmic scripts.mit.edu:/etc/passwd /mit/scripts/sec-tools/store/passwd
/mit/scripts/sec-tools/parse-passwd.pl /mit/scripts/sec-tools/store/passwd /mit/scripts/sec-tools/store/scriptslist
