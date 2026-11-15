#!/bin/sh
printf 'section=battery\ntitle=Battery\n\ntext=mac\ntitle=This Mac\nicon=macbook\ndetail=84%%\nvalue=0.84\n\n'
printf 'text=device-1\ntitle=AirPods Pro, left\ndetail=72%%\nicon=airpodpro.left\nvalue=0.72\n\n'
printf 'text=device-2\ntitle=AirPods Pro, right\ndetail=68%%\nicon=airpodpro.right\nvalue=0.68\n\n'
printf 'text=device-3\ntitle=Magic Keyboard\ndetail=15%%\nicon=keyboard\nvalue=0.15\ntone=bad\n\n'
printf 'section=cpu\ntitle=CPU\n\ntext=cpu-all\ntitle=All cores\nicon=cpu\ndetail=23%%\nmax=100\n'
for v in 12 18 15 22 31 27 19 24 35 28 21 17 26 33 29 23; do printf 'value=%s\n' "$v"; done
printf '\ntext=cpu-1\ntitle=Safari\ndetail=18.4%%\n\ntext=cpu-2\ntitle=Music\ndetail=6.2%%\n\ntext=cpu-3\ntitle=WindowServer\ndetail=4.9%%\n\n'
printf 'section=memory\ntitle=Memory\n\ntext=memory-used\ntitle=Used\nicon=memorychip\ndetail=61%%\nvalue=0.61\n\n'
printf 'text=swap\ntitle=Swap\ndetail=512 MB\n\n'
printf 'text=memory-1\ntitle=Safari\ndetail=1.2 GB\n\ntext=memory-2\ntitle=Mail\ndetail=486 MB\n\ntext=memory-3\ntitle=Music\ndetail=312 MB\n'
