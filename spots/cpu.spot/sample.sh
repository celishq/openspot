#!/bin/sh
printf 'graph=cpu\ntitle=23%%\nmax=100\n'; for v in 12 18 15 22 31 27 19 24 35 28 21 17 26 33 29 23; do printf 'value=%s\n' "$v"; done
