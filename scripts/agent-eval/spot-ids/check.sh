#!/bin/sh
. "$TASKS/checks.sh"
ids | sort >wanted.txt
sort answer.txt | grep -v "^$" >got.txt
diff wanted.txt got.txt
